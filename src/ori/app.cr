require "signal"

abstract class Ori::App
  include Ori::DSL

  @root : Ori::Box?
  @dialog : Ori::Box?
  @focus : Ori::FocusManager?
  @renderer : Ori::Renderer?
  @saved_term : LibC::Termios?
  @parser : Ori::InputParser = Ori::InputParser.new
  @running : Bool = false
  @mouse_enabled : Bool = true
  @fps : Int32 = 60

  abstract def render : Ori::Box

  def self.run : Nil
    new.start
  end

  def start : Nil
    unless STDIN.tty?
      STDERR.puts "ori: requires an interactive terminal"; exit 1
    end
    @saved_term = Ori::Term.enter_raw
    @renderer = Ori::Renderer.new
    @renderer.not_nil!.start
    if @mouse_enabled
      STDOUT << Ori::Term.enable_mouse
      STDOUT.flush
    end
    @running = true
    rebuild
    @renderer.not_nil!.start_loop(fps_to_interval(@fps)) { {@root.not_nil!, @dialog} }
    on_start
    Signal::WINCH.trap { rebuild }
    event_loop
  rescue ex : Exception
    STDERR.puts "\nori: unexpected error: #{ex.message}" if ex.message
  ensure
    @running = false
    cleanup
  end

  private def cleanup : Nil
    if @mouse_enabled
      STDOUT << Ori::Term.disable_mouse
      STDOUT.flush
    end
    @renderer.try(&.close)
    if st = @saved_term
      Ori::Term.restore(st)
    end
    STDOUT << Ori::Term.show_cursor
    STDOUT.flush
  end

  def on_start : Nil
  end

  def rebuild : Nil
    @root = render
    return unless root = @root
    w, h = Ori::Term.window_size
    root.rect = Ori::Rect.new(0, 0, w, h)
    root.layout
    if d = @dialog
      dw = {d.content_width + d.style.hpadding, w - 4}.min
      dh = {d.content_height + d.style.vpadding, h - 4}.min
      d.rect = Ori::Rect.new((w - dw) // 2, (h - dh) // 2, dw, dh)
      d.layout
    end
    @focus ||= Ori::FocusManager.new
    @focus.not_nil!.update(root)
  rescue ex : Exception
    STDERR.puts "ori: render error: #{ex.message}" if ex.message
  end

  def start_tick(interval : Time::Span = 16.milliseconds, &block : -> Nil) : Nil
    spawn do
      while @running
        block.call
        sleep interval
      end
    end
  end

  def show_dialog(&block : -> Ori::Box) : Nil
    @dialog = block.call
    d = @dialog.not_nil!
    w, h = Ori::Term.window_size
    dw = {d.content_width + d.style.hpadding, w - 4}.min
    dh = {d.content_height + d.style.vpadding, h - 4}.min
    d.rect = Ori::Rect.new((w - dw) // 2, (h - dh) // 2, dw, dh)
    d.layout
    rebuild
  end

  def close_dialog : Nil
    @dialog = nil
    rebuild
  end

  private def event_loop : Nil
    STDIN.read_timeout = 50.milliseconds
    while @running
      begin
        byte = STDIN.read_byte
        break unless byte
        result = @parser.parse_full(byte)
        if result
          if k = result.key
            handle_key(k)
          elsif m = result.mouse
            handle_mouse(m)
          end
        elsif @parser.in_escape_state?
          drain_escape
        end
      rescue IO::TimeoutError
      rescue ex : Exception
        STDERR.puts "ori: input error: #{ex.message}" if ex.message
      end
    end
  end

  private def drain_escape : Nil
    STDIN.read_timeout = 50.milliseconds
    loop do
      begin
        b = STDIN.read_byte
        break unless b
        result = @parser.parse_full(b)
        if result
          STDIN.read_timeout = nil
          if k = result.key
            handle_key(k)
          elsif m = result.mouse
            handle_mouse(m)
          end
          return
        end
      rescue IO::TimeoutError
        break
      end
    end
    STDIN.read_timeout = nil
    key = @parser.flush_escape
    handle_key(key) if key
  end

  def handle_key(key : Ori::Key) : Bool
    if key.ctrl && key.text == "c"
      @running = false
    elsif fm = @focus
      fm.handle_key(key)
      rebuild unless any_overlay_open?
    end
    false
  end

  def handle_mouse(mouse : Ori::Mouse) : Bool
    handled = dispatch_mouse(mouse)
    handled = on_mouse(mouse) unless handled
    rebuild unless any_overlay_open?
    handled
  end

  def on_mouse(mouse : Ori::Mouse) : Bool
    false
  end

  private def dispatch_mouse(mouse : Ori::Mouse) : Bool
    target = @dialog || @root
    return false unless target
    find_and_dispatch(target, mouse)
  end

  private def find_and_dispatch(node : Ori::Node, mouse : Ori::Mouse) : Bool
    if node.is_a?(Ori::Box)
      if node.responds_to?(:open) && node.open
        if mouse.in?(node.rect)
          return node.on_mouse(mouse)
        end
      end
      node.children.reverse_each do |child|
        if find_and_dispatch(child, mouse)
          return true
        end
      end
      false
    else
      if mouse.in?(node.rect)
        node.on_mouse(mouse)
      else
        false
      end
    end
  end

  private def any_overlay_open? : Bool
    return false unless root = @root
    check_overlay(root)
  end

  private def check_overlay(node : Ori::Node) : Bool
    if node.responds_to?(:open) && node.open
      return true
    end
    if node.is_a?(Ori::Box) && node.scrollable? && node.focused
      return true
    end
    if node.is_a?(Ori::Box)
      node.children.any? { |c| check_overlay(c) }
    else
      false
    end
  end

  private def fps_to_interval(fps : Int32) : Time::Span
    {1000.milliseconds / {fps, 1}.max, 1.millisecond}.max
  end
end
