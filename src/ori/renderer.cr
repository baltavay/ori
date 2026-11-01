class Ori::Renderer
  getter screen : Ori::Screen
  getter fps : Int32 = 0
  @running : Bool = false
  @stopped : Bool = true
  @get_tree : Proc({Ori::Box, Ori::Box?, Bool})?
  @cursor_visible : Bool = false
  @last_cursor : {Int32, Int32}?
  @frame_count : Int32 = 0
  @fps_timer : Time::Instant = Time.instant

  getter graphics : Ori::Graphics

  # Images placed by the last frame that actually went to the terminal.
  @last_images = [] of Ori::Screen::Placement
  @image_ids = {} of String => UInt32
  @next_image_id : UInt32 = 1

  def initialize(@output : IO = STDOUT)
    w, h = Ori::Term.window_size
    @screen = Ori::Screen.new(w, h)
    @get_tree = nil
    @graphics = Ori::Graphics.new(@output)
  end

  # Ask the terminal what it can draw. Called by `Ori::App#start` once the tty is in
  # raw mode — a probe reads the terminal's answer from stdin, and the input parser
  # must not be running yet.
  def configure_graphics(probe : Bool = true) : Nil
    @graphics.configure(Ori::Term.cell_size, probe ? STDIN : nil)
  end

  def start : Nil
    @output << Ori::Term.enter_alt << Ori::Term.hide_cursor << Ori::Term.clear_screen
    @output.flush
  end

  def start_loop(interval : Time::Span = 16.milliseconds, &get_tree : Proc({Ori::Box, Ori::Box?, Bool})) : Nil
    @get_tree = get_tree
    @running = true
    @stopped = false
    @fps_timer = Time.instant
    spawn do
      begin
        while @running
          frame_start = Time.instant
          begin
            tree = @get_tree.not_nil!.call
            render(tree[0], tree[1]) if tree[2]
            @frame_count += 1
          rescue ex : Exception
          end
          now = Time.instant
          if now - @fps_timer >= 1.seconds
            @fps = @frame_count
            @frame_count = 0
            @fps_timer = now
          end
          elapsed = Time.instant - frame_start
          sleep_remaining = interval - elapsed
          if sleep_remaining > 1.millisecond
            sleep sleep_remaining
          else
            Fiber.yield
          end
        end
      ensure
        @stopped = true
      end
    end
  end

  # Stops the loop and waits until its fiber has left it, so no frame is written
  # after this returns. `close` needs that: a frame written after the exit
  # sequence of the alternate screen lands on the shell.
  def stop : Nil
    @running = false
    deadline = Time.instant + 200.milliseconds
    while !@stopped && Time.instant < deadline
      sleep 1.millisecond
    end
  end

  # True once the loop's fiber has left the loop. `stop` waits for this.
  def stopped? : Bool
    @stopped
  end

  def render(root : Ori::Box, dialog : Ori::Box? = nil) : Nil
    w, h = Ori::Term.window_size
    resized = @screen.resize?(w, h)
    if resized
      @output << Ori::Term.hide_cursor
      @cursor_visible = false
      @last_cursor = nil
    end
    @screen.clear
    begin
      if d = dialog
        root.render_screen(@screen)
        d.render_screen(@screen)
      else
        root.render_screen(@screen)
      end
      render_overlays(@screen, root)
    rescue ex : Exception
      @screen.clear
      @screen.write(0, 0, "render error: #{ex.message}", fg: "#f38ba8")
    end
    target = dialog || root
    flush_and_cursor(target)
    sync_images
  rescue IO::Error
  end

  def render_node(node : Ori::Node) : Nil
    w, h = Ori::Term.window_size
    resized = @screen.resize?(w, h)
    if resized
      @output << Ori::Term.hide_cursor
      @cursor_visible = false
      @last_cursor = nil
    end
    r = node.rect
    @screen.clear_rect(r.x, r.y, r.w, r.h)
    node.render_screen(@screen)
    flush_and_cursor(node)
  rescue IO::Error
  end

  private def flush_and_cursor(cursor_root : Ori::Node) : Nil
    @screen.flush(@output)
    if pos = find_cursor(cursor_root)
      unless @cursor_visible
        @output << Ori::Term.show_cursor
        @cursor_visible = true
      end
      @output << Ori::Term.cursor_at(pos[0], pos[1])
      @last_cursor = pos
    elsif @cursor_visible
      @output << Ori::Term.hide_cursor
      @cursor_visible = false
      @last_cursor = nil
    end
    @output.flush
  end

  # Place the frame's images after its text. Nothing is sent when the placements did
  # not change, which is every frame that only redraws a status line.
  private def sync_images : Nil
    return unless @graphics.configured?
    wanted = @screen.images
    drawn = [] of Ori::Screen::Placement
    previous = @last_images
    # Sixel payloads that were not ready last frame are missing from `previous`, so
    # the comparison retries them; kitty draws everything it is handed.
    return if wanted == previous

    if !previous.empty?
      if @graphics.backend.kitty?
        @graphics.clear
      else
        # Sixel cannot be deleted; the cells under the old images are painted over
        # with what the frame just put there.
        seen = Set(Tuple(Int32, Int32, Int32, Int32)).new
        previous.each do |placement|
          key = {placement.x, placement.y, placement.cols, placement.rows}
          next if seen.includes?(key)
          seen << key
          @screen.repaint_rect(@output, placement.x, placement.y, placement.cols, placement.rows)
        end
      end
    end

    wanted.each do |placement|
      cols, rows = @graphics.cell_box(placement.width, placement.height, placement.cols, placement.rows)
      x = placement.x + (placement.cols - cols) // 2
      y = placement.y + (placement.rows - rows) // 2
      @output << Ori::Term.move(x, y)
      id = (@image_ids[placement.path] ||= (@next_image_id += 1))
      drawn << placement if @graphics.draw(placement.path, cols, rows, id)
    end
    @last_images = drawn
    @output.flush
  end

  def close : Nil
    stop
    # `sync_end` guards against a frame interrupted between its begin and end
    # sequences, which would leave a terminal in synchronized updates and make it
    # stop redrawing. A terminal not in that mode ignores it.
    @output << Ori::Term.sync_end << Ori::Term.reset_attrs << Ori::Term.cursor_default << Ori::Term.show_cursor << Ori::Term.exit_alt
    @output.flush
  rescue IO::Error
  end

  private def render_overlays(screen, node : Ori::Node) : Nil
    node.render_overlay(screen)
    if node.is_a?(Ori::Box)
      node.children.each { |c| render_overlays(screen, c) }
    end
  end

  private def find_cursor(node : Ori::Node) : {Int32, Int32}?
    case node
    when Ori::InputNode
      node.cursor_position
    when Ori::TextArea
      node.cursor_position
    when Ori::TextNode
      node.cursor_position
    when Ori::Box
      node.children.each do |child|
        result = find_cursor(child)
        return result if result
      end
      nil
    else
      nil
    end
  end
end
