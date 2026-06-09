class Ori::Renderer
  getter screen : Ori::Screen
  getter fps : Int32 = 0
  @running : Bool = false
  @get_tree : Proc({Ori::Box, Ori::Box?, Bool})?
  @cursor_visible : Bool = false
  @last_cursor : {Int32, Int32}?
  @frame_count : Int32 = 0
  @fps_timer : Time::Instant = Time.instant

  def initialize(@output : IO = STDOUT)
    w, h = Ori::Term.window_size
    @screen = Ori::Screen.new(w, h)
    @get_tree = nil
  end

  def start : Nil
    @output << Ori::Term.enter_alt << Ori::Term.hide_cursor << Ori::Term.clear_screen
    @output.flush
  end

  def start_loop(interval : Time::Span = 16.milliseconds, &get_tree : Proc({Ori::Box, Ori::Box?, Bool})) : Nil
    @get_tree = get_tree
    @running = true
    @fps_timer = Time.instant
    spawn do
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
    end
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

  def close : Nil
    @running = false
    @output << Ori::Term.cursor_default << Ori::Term.show_cursor << Ori::Term.exit_alt
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
