class Ori::AreaNode < Ori::Node
  BORDER_OFF   = "#4A3F6B"
  BORDER_ON    = "#A78BFA"

  @lines : Array(String)
  @cursor_row : Int32
  @cursor_col : Int32
  @scroll_row : Int32
  @scroll_col : Int32
  @on_change : Proc(String, Int32, Int32, Nil)?
  @on_cursor : Proc(Int32, Int32, Nil)?
  @char_limit : Int32
  @show_line_numbers : Bool
  @highlights : Array(Tuple(Int32, Int32, Int32))

  def initialize(
    value : String = "",
    @on_change : Proc(String, Int32, Int32, Nil)? = nil,
    @on_cursor : Proc(Int32, Int32, Nil)? = nil,
    cursor_row : Int32 = 0,
    cursor_col : Int32? = nil,
    @char_limit : Int32 = 0,
    @show_line_numbers : Bool = false,
    highlights : Array(Tuple(Int32, Int32, Int32)) = [] of Tuple(Int32, Int32, Int32),
    style : Ori::S = Ori::S.none
  )
    super(style)
    @lines = value.empty? ? [""] : value.split('\n')
    @cursor_row = {cursor_row, @lines.size - 1}.min
    @cursor_col = cursor_col || @lines[@cursor_row]?.try(&.size) || 0
    @scroll_row = 0
    @scroll_col = 0
    @highlights = highlights
  end

  def value : String
    @lines.join('\n')
  end

  def value=(text : String)
    @lines = text.empty? ? [""] : text.split('\n')
    @cursor_row = {@cursor_row, @lines.size - 1}.min
    @cursor_col = {@cursor_col, current_line.size}.min
  end

  def content_height : Int32
    {@lines.size, @style.height || @lines.size}.max
  end

  def content_width : Int32
    @lines.map(&.size).max + prefix_offset
  end

  def focusable? : Bool
    true
  end

  def cursor_position : {Int32, Int32}?
    return nil unless @focused
    adjust_scroll
    cx = {@cursor_col - @scroll_col, text_width - 1}.min
    cy = {@cursor_row - @scroll_row, @rect.h - 1}.min
    {@rect.x + prefix_offset + line_number_width + cx, @rect.y + cy}
  end

  def render_screen(screen : Ori::Screen) : Nil
    po = prefix_offset
    ln_w = line_number_width
    total_po = po + ln_w
    return if @rect.w <= total_po || @rect.h <= 0
    adjust_scroll
    tw = text_width

    @rect.h.times do |i|
      row = @scroll_row + i
      line = @lines[row]?
      text = if line
               from = @scroll_col
               to = @scroll_col + tw
               if from >= line.size
                 " " * tw
               else
                 visible = line[from...{to, line.size}.min].to_s
                 visible.ljust(tw)
               end
             else
               " " * tw
             end
      if po > 0
        border_color = @focused ? BORDER_ON : BORDER_OFF
        bchar = Ori.border_chars(@style.border)[:prefix]
        screen.put(@rect.x, @rect.y + i, bchar, fg: border_color)
      end
      if ln_w > 0
        if row < @lines.size
          num = (row + 1).to_s.rjust(ln_w - 1) + " "
          num.each_char_with_index do |ch, ci|
            screen.put(@rect.x + po + ci, @rect.y + i, ch, fg: "#6c7086", bg: effective_bg)
          end
        else
          ln_w.times do |ci|
            screen.put(@rect.x + po + ci, @rect.y + i, ' ', bg: effective_bg)
          end
        end
      end
      text.each_char_with_index do |ch, ci|
        abs_col = @scroll_col + ci
        hl = highlighted?(row, abs_col)
        if hl
          screen.put(@rect.x + total_po + ci, @rect.y + i, ch, fg: effective_bg || "#1e1e2e", bg: @style.fg || "#cdd6f4")
        else
          screen.put(@rect.x + total_po + ci, @rect.y + i, ch, fg: @style.fg, bg: effective_bg)
        end
      end
    end
  end

  def render(io : IO) : Nil
    po = prefix_offset
    return if @rect.w <= po || @rect.h <= 0
    adjust_scroll
    tw = text_width

    @rect.h.times do |i|
      row = @scroll_row + i
      line = @lines[row]?
      text = if line
               from = @scroll_col
               to = @scroll_col + tw
               if from >= line.size
                 " " * tw
               else
                 visible = line[from...{to, line.size}.min].to_s
                 visible.ljust(tw)
               end
             else
               " " * tw
             end
      text = Ori::Color.apply(@style.fg, text) if @style.fg
      if po > 0
        border_color = @focused ? BORDER_ON : BORDER_OFF
        bchar = Ori.border_chars(@style.border)[:prefix].to_s
        io << Ori::Term.move(@rect.x, @rect.y + i) << Ori::Color.apply(border_color, bchar)
      end
      io << Ori::Term.move(@rect.x + po, @rect.y + i) << text
    end
  end

  private def prefix_offset : Int32
    @style.border? && @style.border != :none ? 1 : 0
  end

  def line_count : Int32
    @lines.size
  end

  def cursor_row : Int32
    @cursor_row
  end

  def cursor_col : Int32
    @cursor_col
  end

  def line(row : Int32) : String
    @lines[row]? || ""
  end

  @fire_change_on_complete : Bool = false

  def on_key(key : Ori::Key) : Bool
    @fire_change_on_complete = false
    result = handle_key_internal(key)
    if result
      fire_cursor
      fire_change unless @fire_change_on_complete
    end
    result
  end

  private def handle_key_internal(key : Ori::Key) : Bool
    case
    when key.ctrl && key.text == "a"
      @cursor_col = 0; true
    when key.ctrl && key.text == "e"
      @cursor_col = current_line.size; true
    when key.ctrl && key.text == "k"
      kill_to_end; true
    when key.ctrl && key.text == "u"
      kill_to_start; true
    when key.alt && (key.code.left? || key.text == "b")
      word_left; true
    when key.alt && (key.code.right? || key.text == "f")
      word_right; true
    when key.alt && key.code.backspace?
      delete_word_backward; true
    when key.alt && key.text == "d"
      delete_word_forward; true
    when key.code.pg_up?
      page_up; true
    when key.code.pg_down?
      page_down; true
    when key.code.backspace?
      handle_backspace; true
    when key.code.delete?
      handle_delete; true
    when key.code.enter?
      handle_enter; true
    when key.code.up?
      @cursor_row -= 1 if @cursor_row > 0
      clamp_col
      true
    when key.code.down?
      @cursor_row += 1 if @cursor_row < @lines.size - 1
      clamp_col
      true
    when key.code.left?
      if @cursor_col > 0
        @cursor_col -= 1
      elsif @cursor_row > 0
        @cursor_row -= 1
        @cursor_col = @lines[@cursor_row].size
      end
      true
    when key.code.right?
      if @cursor_col < current_line.size
        @cursor_col += 1
      elsif @cursor_row < @lines.size - 1
        @cursor_row += 1
        @cursor_col = 0
      end
      true
    when key.code.home?
      @cursor_col = 0; true
    when key.code.end?
      @cursor_col = current_line.size; true
    when key.printable?
      if @char_limit > 0 && value.size >= @char_limit
        return false
      end
      line = current_line
      @lines[@cursor_row] = line[0...@cursor_col] + key.text + line[@cursor_col..]
      @cursor_col += 1
      fire_change
      true
    else
      false
    end
  end

  def word_left : Nil
    if @cursor_col > 0
      line = current_line
      col = @cursor_col
      while col > 0 && line[col - 1]?.try(&.ascii_whitespace?)
        col -= 1
      end
      while col > 0 && !line[col - 1]?.try(&.ascii_whitespace?)
        col -= 1
      end
      @cursor_col = col
    elsif @cursor_row > 0
      @cursor_row -= 1
      @cursor_col = @lines[@cursor_row].size
    end
  end

  def word_right : Nil
    line = current_line
    if @cursor_col < line.size
      col = @cursor_col
      while col < line.size && !line[col]?.try(&.ascii_whitespace?)
        col += 1
      end
      while col < line.size && line[col]?.try(&.ascii_whitespace?)
        col += 1
      end
      @cursor_col = col
    elsif @cursor_row < @lines.size - 1
      @cursor_row += 1
      @cursor_col = 0
    end
  end

  def delete_word_backward : Nil
    line = current_line
    if @cursor_col > 0
      col = @cursor_col
      while col > 0 && line[col - 1]?.try(&.ascii_whitespace?)
        col -= 1
      end
      while col > 0 && !line[col - 1]?.try(&.ascii_whitespace?)
        col -= 1
      end
      @lines[@cursor_row] = line[0...col] + line[@cursor_col..]
      @cursor_col = col
      fire_change
    elsif @cursor_row > 0
      prev = @lines[@cursor_row - 1]
      curr = current_line
      @cursor_col = prev.size
      @lines[@cursor_row - 1] = prev + curr
      @lines.delete_at(@cursor_row)
      @cursor_row -= 1
      fire_change
    end
  end

  def delete_word_forward : Nil
    line = current_line
    if @cursor_col < line.size
      col = @cursor_col
      while col < line.size && !line[col]?.try(&.ascii_whitespace?)
        col += 1
      end
      while col < line.size && line[col]?.try(&.ascii_whitespace?)
        col += 1
      end
      @lines[@cursor_row] = line[0...@cursor_col] + line[col..]
      fire_change
    elsif @cursor_row < @lines.size - 1
      @lines[@cursor_row] = line + @lines[@cursor_row + 1]
      @lines.delete_at(@cursor_row + 1)
      fire_change
    end
  end

  def kill_to_end : Nil
    line = current_line
    if @cursor_col < line.size
      @lines[@cursor_row] = line[0...@cursor_col]
      fire_change
    end
  end

  def kill_to_start : Nil
    line = current_line
    if @cursor_col > 0
      @lines[@cursor_row] = line[@cursor_col..]
      @cursor_col = 0
      fire_change
    end
  end

  def page_up : Nil
    @cursor_row = {@cursor_row - {@rect.h, 1}.max, 0}.max
    clamp_col
  end

  def page_down : Nil
    @cursor_row = {@cursor_row + {@rect.h, 1}.max, @lines.size - 1}.min
    clamp_col
  end

  private def handle_backspace : Nil
    if @cursor_col > 0
      line = current_line
      @lines[@cursor_row] = line[0...@cursor_col - 1] + line[@cursor_col..]
      @cursor_col -= 1
      fire_change
    elsif @cursor_row > 0
      prev = @lines[@cursor_row - 1]
      curr = current_line
      @cursor_col = prev.size
      @lines[@cursor_row - 1] = prev + curr
      @lines.delete_at(@cursor_row)
      @cursor_row -= 1
      fire_change
    end
  end

  private def handle_delete : Nil
    line = current_line
    if @cursor_col < line.size
      @lines[@cursor_row] = line[0...@cursor_col] + line[@cursor_col + 1..]
      fire_change
    elsif @cursor_row < @lines.size - 1
      @lines[@cursor_row] = line + @lines[@cursor_row + 1]
      @lines.delete_at(@cursor_row + 1)
      fire_change
    end
  end

  private def handle_enter : Nil
    line = current_line
    @lines[@cursor_row] = line[0...@cursor_col]
    @lines.insert(@cursor_row + 1, line[@cursor_col..])
    @cursor_row += 1
    @cursor_col = 0
    fire_change
  end

  private def current_line : String
    @lines[@cursor_row]? || ""
  end

  private def text_width : Int32
    {@rect.w - prefix_offset - line_number_width, 1}.max
  end

  private def line_number_width : Int32
    return 0 unless @show_line_numbers
    {@lines.size.to_s.size + 1, 4}.max
  end

  private def highlighted?(row : Int32, col : Int32) : Bool
    @highlights.any? do |hl|
      hl_row, hl_start, hl_end = hl
      row == hl_row && col >= hl_start && col <= hl_end
    end
  end

  private def clamp_col
    @cursor_col = {@cursor_col, current_line.size}.min
  end

  private def adjust_scroll
    if @cursor_row < @scroll_row
      @scroll_row = @cursor_row
    elsif @cursor_row >= @scroll_row + @rect.h
      @scroll_row = @cursor_row - @rect.h + 1
    end
    tw = text_width
    if @cursor_col < @scroll_col
      @scroll_col = @cursor_col
    elsif @cursor_col >= @scroll_col + tw
      @scroll_col = @cursor_col - tw + 1
    end
  end

  private def fire_change
    @fire_change_on_complete = true
    @on_change.try(&.call(value, @cursor_row, @cursor_col))
  end

  private def fire_cursor
    @on_cursor.try(&.call(@cursor_row, @cursor_col))
  end
end
