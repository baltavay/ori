class Ori::Renderer
  getter screen : Ori::Screen
  @running : Bool = false
  @get_tree : Proc({Ori::Box, Ori::Box?})?

  def initialize(@output : IO = STDOUT)
    w, h = Ori::Term.window_size
    @screen = Ori::Screen.new(w, h)
    @get_tree = nil
  end

  def start : Nil
    @output << Ori::Term.enter_alt << Ori::Term.hide_cursor << Ori::Term.clear_screen
    @output.flush
  end

  def start_loop(interval : Time::Span = 16.milliseconds, &get_tree : Proc({Ori::Box, Ori::Box?})) : Nil
    @get_tree = get_tree
    @running = true
    spawn do
      while @running
        begin
          tree = @get_tree.not_nil!.call
          render(tree[0], tree[1])
        rescue ex : Exception
        end
        sleep interval
      end
    end
  end

  def render(root : Ori::Box, dialog : Ori::Box? = nil) : Nil
    w, h = Ori::Term.window_size
    @screen.resize(w, h)
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
    @screen.flush(@output)
    target = dialog || root
    if pos = find_cursor(target)
      @output << Ori::Term.cursor_at(pos[0], pos[1])
    else
      @output << Ori::Term.hide_cursor
    end
    @output.flush
  rescue IO::Error
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
    when Ori::AreaNode
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
