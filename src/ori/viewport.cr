class Ori::Viewport < Ori::Node
  @content : String
  @lines : Array(String)
  @y_offset : Int32
  @x_offset : Int32
  @soft_wrap : Bool
  @on_scroll : Proc(Int32, Nil)?

  def initialize(
    content : String = "",
    @soft_wrap : Bool = true,
    y_offset : Int32 = 0,
    @on_scroll : Proc(Int32, Nil)? = nil,
    style : Ori::S = Ori::S.none
  )
    super(style)
    @content = content
    @lines = [] of String
    @y_offset = y_offset
    @x_offset = 0
    rebuild_lines
  end

  getter content : String
  getter y_offset : Int32

  def content=(s : String) : Nil
    @content = s
    rebuild_lines
  end

  def total_lines : Int32
    @lines.size
  end

  def at_top? : Bool
    @y_offset <= 0
  end

  def at_bottom? : Bool
    @y_offset >= max_y_offset
  end

  def max_y_offset : Int32
    vh = visible_height
    vh > 0 ? {0, @lines.size - vh}.max : @lines.size - 1
  end

  def view_up(n : Int32 = 1) : Nil
    @y_offset = {@y_offset - n, 0}.max
    @on_scroll.try(&.call(@y_offset))
  end

  def view_down(n : Int32 = 1) : Nil
    @y_offset = {@y_offset + n, max_y_offset}.min
    @on_scroll.try(&.call(@y_offset))
  end

  def goto_top : Nil
    @y_offset = 0
    @on_scroll.try(&.call(@y_offset))
  end

  def goto_bottom : Nil
    @y_offset = max_y_offset
    @on_scroll.try(&.call(@y_offset))
  end

  def content_height : Int32
    @lines.size
  end

  def content_width : Int32
    @lines.map(&.size).max
  end

  def focusable? : Bool
    @style.focusable
  end

  def on_key(key : Ori::Key) : Bool
    case
    when key.code.up? || key.text == "k"
      view_up; true
    when key.code.down? || key.text == "j"
      view_down; true
    when key.code.pg_up? || key.text == "b"
      view_up(visible_height); true
    when key.code.pg_down? || key.text == "f"
      view_down(visible_height); true
    when key.code.home? || key.text == "g"
      goto_top; true
    when key.code.end? || key.text == "G"
      goto_bottom; true
    when key.code.left?
      @x_offset = {@x_offset - 4, 0}.max; true
    when key.code.right?
      @x_offset += 4; true
    else
      false
    end
  end

  def on_mouse(mouse : Ori::Mouse) : Bool
    case mouse.action
    when Ori::Mouse::Action::Wheel
      if mouse.button.wheel_up?
        view_up(3)
      elsif mouse.button.wheel_down?
        view_down(3)
      end
      true
    else
      false
    end
  end

  def render(io : IO) : Nil
  end

  def render_screen(screen : Ori::Screen) : Nil
    r = @rect
    return if r.w <= 0 || r.h <= 0
    fg = @style.fg
    bg = effective_bg

    visible_height.times do |i|
      idx = @y_offset + i
      ry = r.y + i
      break if ry >= r.y + r.h

      line = @lines[idx]?
      cx = r.x

      if line
        line.each_char do |ch|
          break if cx >= r.x + r.w
          screen.put(cx, ry, ch, fg: fg, bg: bg)
          cx += 1
        end
      end

      while cx < r.x + r.w
        screen.put(cx, ry, ' ', fg: fg, bg: bg)
        cx += 1
      end
    end

    draw_scrollbar(screen)
  end

  private def draw_scrollbar(screen : Ori::Screen) : Nil
    r = @rect
    total = @lines.size
    vh = visible_height
    return if total <= vh || r.w <= 0

    sb_x = r.x + r.w - 1
    thumb_h = {({vh * vh // total, 1}.max), vh}.min
    thumb_pos = vh > thumb_h ? (@y_offset * (vh - thumb_h) // {total - vh, 1}.max) : 0

    vh.times do |i|
      if i >= thumb_pos && i < thumb_pos + thumb_h
        screen.put(sb_x, r.y + i, '▐', fg: "#6c7086", bg: effective_bg)
      else
        screen.put(sb_x, r.y + i, '░', fg: "#3c3c3c", bg: effective_bg, dim: true)
      end
    end
  end

  private def visible_height : Int32
    r = @rect
    bs = @style.border_size
    {r.h - @style.vpadding - bs * 2, 0}.max
  end

  private def rebuild_lines : Nil
    if @soft_wrap
      w = @rect.w > 0 ? {@rect.w - @style.hpadding - @style.border_size * 2, 1}.max : 80
      @lines = [] of String
      @content.split('\n').each do |line|
        if line.size > w
          wrap_line(line, w).each { |wl| @lines << wl }
        else
          @lines << line
        end
      end
    else
      @lines = @content.split('\n')
    end
    @y_offset = @y_offset.clamp(0, max_y_offset)
  end

  private def wrap_line(line : String, width : Int32) : Array(String)
    result = [] of String
    current = ""
    line.each_char do |ch|
      if current.size >= width
        result << current
        current = ch.to_s
      else
        current += ch
      end
    end
    result << current unless current.empty?
    result.empty? ? [""] of String : result
  end
end
