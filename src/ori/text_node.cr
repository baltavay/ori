class Ori::TextNode < Ori::Node
  getter content : String
  getter cursor_col : Int32?

  def content=(c : String)
    @content = c
  end

  def initialize(@content : String, cursor_or_style : Int32? | Ori::S = nil, style : Ori::S? = nil)
    case cursor_or_style
    when Ori::S
      @cursor_col = nil
      super(cursor_or_style)
    else
      @cursor_col = cursor_or_style
      super(style || Ori::S.none)
    end
  end

  def cursor_position : {Int32, Int32}?
    return nil unless cc = @cursor_col
    col = 0
    first_line = lines[0]? || ""
    first_line.each_char do |ch|
      break if col >= cc
      w = Ori::Term.char_width(ch)
      col += w if w > 0
    end
    {@rect.x + col, @rect.y}
  end

  def content_height : Int32
    lines.size
  end

  def content_width : Int32
    lines.map { |l| Ori::Term.display_width(l) }.max
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
        w = Ori::Term.char_width(ch)
        next if w == 0
        if cx + w > inner.x + inner.w
          break
        end
        screen.put(cx, inner.y + i, ch, fg: @style.fg, bg: effective_bg, bold: @style.bold, dim: @style.dim)
        (1...w).each do |offset|
          screen.put(cx + offset, inner.y + i, '\0', fg: @style.fg, bg: effective_bg, bold: @style.bold, dim: @style.dim)
        end
        cx += w
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
      pad = {width - Ori::Term.display_width(text), 0}.max
      left = pad // 2
      (" " * left) + text + (" " * (pad - left))
    when :right
      dw = Ori::Term.display_width(text)
      pad = {width - dw, 0}.max
      (" " * pad) + text
    else
      dw = Ori::Term.display_width(text)
      pad = {width - dw, 0}.max
      text + (" " * pad)
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

end
