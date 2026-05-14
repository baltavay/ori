class Ori::TextNode < Ori::Node
  getter content : String

  def content=(c : String)
    @content = c
  end

  def initialize(@content : String, style : Ori::S = Ori::S.none)
    super(style)
  end

  def content_height : Int32
    lines.size
  end

  def content_width : Int32
    lines.map(&.size).max
  end

  def render_screen(screen : Ori::Screen) : Nil
    inner = @rect
    lines.each_with_index do |line, i|
      break if i >= inner.h
      display = align_line(line, inner.w)
      cx = inner.x
      display.each_char do |ch|
        break if cx >= inner.x + inner.w
        if ch == '\e'
          next
        end
        screen.put(cx, inner.y + i, ch, fg: @style.fg, bg: effective_bg, bold: @style.bold, dim: @style.dim)
        cx += 1
      end
    end
  end

  def render(io : IO) : Nil
    inner = @rect
    lines.each_with_index do |line, i|
      break if i >= inner.h
      display = align_line(line, inner.w)
      display = apply_styles(display)
      io << Ori::Term.move(inner.x, inner.y + i) << display
    end
  end

  private def lines : Array(String)
    @content.split('\n')
  end

  private def align_line(text : String, width : Int32) : String
    case @style.align
    when :center
      pad = {width - plain_size(text), 0}.max
      left = pad // 2
      (" " * left) + text + (" " * (pad - left))
    when :right
      text.rjust(width)
    else
      text.ljust(width)
    end
  end

  private def apply_styles(text : String) : String
    t = text
    t = Ori::Color.apply(@style.fg, t) if @style.fg
    t = "\e[1m#{t}\e[0m" if @style.bold
    t = "\e[2m#{t}\e[0m" if @style.dim
    t = "\e[4m#{t}\e[0m" if @style.underline
    t = "\e[9m#{t}\e[0m" if @style.strikethrough
    t = Ori::Color.apply_bg(effective_bg, t) if effective_bg
    t
  end

  private def plain_size(text : String) : Int32
    text.gsub(/\e\[[^m]*m/, "").size
  end
end
