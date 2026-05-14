class Ori::MarkdownNode < Ori::Node
  private struct Row
    getter cells : Array(Ori::Screen::Cell)
    getter width : Int32

    def initialize(@cells : Array(Ori::Screen::Cell))
      @width = @cells.size
    end
  end

  @content : String
  @rows : Array(Row)
  @y_offset : Int32
  @on_scroll : Proc(Int32, Nil)?

  def initialize(
    content : String = "",
    y_offset : Int32 = 0,
    @on_scroll : Proc(Int32, Nil)? = nil,
    style : Ori::S = Ori::S.none
  )
    super(style)
    @content = content
    @rows = [] of Row
    @y_offset = y_offset
    parse
  end

  getter content : String
  getter y_offset : Int32

  def content=(text : String) : Nil
    @content = text
    parse
  end

  def total_lines : Int32
    @rows.size
  end

  def content_height : Int32
    {@rows.size, 1}.max
  end

  def content_width : Int32
    @rows.empty? ? 1 : {@rows.map(&.width).max, 1}.max
  end

  def focusable? : Bool
    @style.focusable
  end

  def at_top? : Bool
    @y_offset <= 0
  end

  def at_bottom? : Bool
    @y_offset >= max_y_offset
  end

  def max_y_offset : Int32
    {0, @rows.size - visible_height}.max
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

  def render_screen(screen : Ori::Screen) : Nil
    r = @rect
    return if r.w <= 0 || r.h <= 0
    bg = effective_bg

    visible_height.times do |i|
      idx = @y_offset + i
      ry = r.y + i
      break if ry >= r.y + r.h

      if idx < @rows.size
        row = @rows[idx]
        cx = 0
        row.cells.each do |cell|
          break if cx >= r.w
          if cell.char == '\n'
            next
          end
          screen.put(r.x + cx, ry, cell.char, fg: cell.fg, bg: cell.bg || bg, bold: cell.bold)
          cx += 1
        end
        while cx < r.w
          screen.put(r.x + cx, ry, ' ', bg: bg)
          cx += 1
        end
      else
        r.w.times do |cx|
          screen.put(r.x + cx, ry, ' ', bg: bg)
        end
      end
    end

    draw_scrollbar(screen)
  end

  def render(io : IO) : Nil
  end

  private def draw_scrollbar(screen : Ori::Screen) : Nil
    r = @rect
    total = @rows.size
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
    {r.h, 0}.max
  end

  private def parse : Nil
    @rows = [] of Row
    in_code = false
    code_buf = [] of String

    @content.split('\n').each do |line|
      if line.starts_with?("```")
        if in_code
          in_code = false
          code_buf.each do |cl|
            emit("  #{cl}", fg: "#a6e3a1")
          end
          code_buf.clear
          emit("")
        else
          in_code = true
        end
        next
      end

      if in_code
        code_buf << line
        next
      end

      case
      when line.starts_with?("### ")
        emit_inline(line[4..], fg: "#afafff", bold: true)
      when line.starts_with?("## ")
        emit_inline(line[3..], fg: "#87afff", bold: true)
      when line.starts_with?("# ")
        emit_inline(line[2..], fg: "#5f87ff", bold: true)
      when line.starts_with?("- ")
        emit_cells(prefix_cells("  • ", fg: "#a6e3a1") + render_inline(line[2..]))
      when line.starts_with?("> ")
        emit_cells(prefix_cells("  ", fg: "#6c7086") + render_inline(line[2..]))
      when line =~ /^(\d+)\.\s/
        m = $1
        rest = line[(m.size + 2)..]
        emit("  #{m}. #{rest}", fg: "#fab387")
      when line =~ /^(\*{3,}|-{3,}|_{3,})$/
        w = @rect.w > 0 ? @rect.w : 80
        emit("─" * w, fg: "#45475a")
      when line.strip.empty?
        emit("")
      else
        emit_cells(render_inline(line))
      end
    end

    @y_offset = @y_offset.clamp(0, max_y_offset) if @rect.w > 0
  end

  private def render_inline(text : String) : Array(Ori::Screen::Cell)
    bg = @style.bg
    cells = [] of Ori::Screen::Cell
    i = 0
    while i < text.size
      if i + 1 < text.size && text[i] == '*' && text[i + 1] == '*'
        j = text.index("**", i + 2)
        if j
          text[i + 2...j].each_char { |ch| cells << Ori::Screen::Cell.new(ch, fg: nil, bg: bg, bold: true) }
          i = j + 2
        else
          cells << Ori::Screen::Cell.new(text[i], fg: nil, bg: bg)
          i += 1
        end
      elsif text[i] == '*' && i + 1 < text.size && text[i + 1] != '*'
        j = text.index('*', i + 1)
        if j
          text[i + 1...j].each_char { |ch| cells << Ori::Screen::Cell.new(ch, fg: nil, bg: bg, dim: true) }
          i = j + 1
        else
          cells << Ori::Screen::Cell.new(text[i], fg: nil, bg: bg)
          i += 1
        end
      elsif text[i] == '`'
        j = text.index('`', i + 1)
        if j
          text[i + 1...j].each_char { |ch| cells << Ori::Screen::Cell.new(ch, fg: "#ff8700", bg: bg) }
          i = j + 1
        else
          cells << Ori::Screen::Cell.new(text[i], fg: nil, bg: bg)
          i += 1
        end
      else
        cells << Ori::Screen::Cell.new(text[i], fg: nil, bg: bg)
        i += 1
      end
    end
    cells
  end

  private def emit(text : String, fg : String? = nil, bold : Bool = false) : Nil
    bg = @style.bg
    cells = [] of Ori::Screen::Cell
    text.each_char do |ch|
      cells << Ori::Screen::Cell.new(ch, fg: fg, bg: bg, bold: bold)
    end
    @rows << Row.new(cells)
  end

  private def emit_inline(text : String, fg : String? = nil, bold : Bool = false) : Nil
    bg = @style.bg
    cells = [] of Ori::Screen::Cell
    text.each_char do |ch|
      cells << Ori::Screen::Cell.new(ch, fg: fg, bg: bg, bold: bold)
    end
    @rows << Row.new(cells)
  end

  private def emit_cells(cells : Array(Ori::Screen::Cell)) : Nil
    @rows << Row.new(cells)
  end

  private def prefix_cells(text : String, fg : String? = nil) : Array(Ori::Screen::Cell)
    bg = @style.bg
    cells = [] of Ori::Screen::Cell
    text.each_char { |ch| cells << Ori::Screen::Cell.new(ch, fg: fg, bg: bg) }
    cells
  end
end
