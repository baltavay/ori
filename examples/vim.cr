require "../src/ori"

class VimEditorApp < Ori::App
  @mode : Symbol = :normal
  @text : String
  @cursor_row : Int32 = 0
  @cursor_col : Int32 = 0
  @pending : String = ""
  @status : String = ""
  @yank : String = ""
  @yank_is_lines : Bool = false
  @visual_start_row : Int32 = 0
  @visual_start_col : Int32 = 0
  @command_buf : String = ""
  @history : Array(String) = [] of String
  @history_idx : Int32 = 0
  @search_query : String = ""
  @search_direction : Symbol = :forward
  @last_search : String = ""
  @last_search_dir : Symbol = :forward
  @search_matches : Array({Int32, Int32}) = [] of {Int32, Int32}
  @search_idx : Int32 = -1
  @count_buf : String = ""
  @macro_recording : Bool = false
  @macro_buf : Array(Ori::Key) = [] of Ori::Key
  @last_motion : Proc(Nil)? = nil

  def initialize
    @text = "Welcome to the Ori Vim Editor!\n\nMotions:\n  h/j/k/l   - move left/down/up/right\n  w/W/b/B/e/E - word motions (big=WORD)\n  0/^/$     - line start/first-nonblank/end\n  gg/G      - file start/end\n  f{char}/F{char}/t{char}/T{char} - find char\n  ;/,       - repeat/reverse find\n  {|}       - paragraph motions\n  %         - matching bracket\n  Ctrl+d/u  - half page down/up\n  Ctrl+f/b  - page down/up\n\nOperators + motions:\n  d{motion}  - delete (dd=line, dw=word, d$, dgg, dG, df{char})\n  c{motion}  - change (cc=line, cw=word, c$, ciw, ci\"  ci( ...)\n  y{motion}  - yank  (yy=line, yw=word, y$)\n  >{/}      - indent/outdent paragraph\n  .         - repeat last change\n\nText objects (with d/c/y):\n  iw/aw     - inner/a word\n  i\"/a\"     - inner/a quotes\n  i(/a(/i)/a) - inner/a parens\n  i{/a{/i}/a} - inner/a braces\n\nOther:\n  x/X       - delete char forward/back\n  r{char}   - replace char\n  ~         - toggle case\n  J         - join lines\n  >>/<<     - indent/outdent line\n  u/Ctrl+r  - undo/redo\n  p/P       - paste after/before\n  i/I/a/A/o/O - enter insert mode\n  v/V       - visual char/line mode\n  :         - command mode\n  /?        - search forward/backward\n  n/N       - next/prev match\n  *         - search word under cursor\n\n-- NORMAL --"
    @history = [@text]
  end

  def render : Ori::Box
    box height: "100%", direction: :vertical do
      area(
        value: @text,
        flex: 1,
        focusable: true,
        border: false,
        cursor_row: @cursor_row,
        cursor_col: @cursor_col,
        on_change: ->(v : String, row : Int32, col : Int32) {
          @text = v
          @cursor_row = row
          @cursor_col = {col, 0}.max
          nil
        },
        on_cursor: ->(row : Int32, col : Int32) {
          @cursor_row = row
          @cursor_col = {col, 0}.max
          nil
        },
        show_line_numbers: true,
        highlights: visual_highlights,
      )

      box padding: {0, 1}, height: 1, direction: :horizontal do
        if @mode == :command
          text ":#{@command_buf}", fg: "#89b4fa"
          text "█", fg: "#6c7086"
        elsif @mode == :search
          prefix = @search_direction == :forward ? "/" : "?"
          text "#{prefix}#{@search_query}", fg: "#f9e2af"
          text "█", fg: "#6c7086"
        else
          mode_fg = case @mode
                    when :insert               then "#a6e3a1"
                    when :visual, :visual_line then "#f38ba8"
                    else                            "#f9e2af"
                    end
          mode_label = @mode == :visual_line ? "VISUAL LINE" : @mode.to_s.upcase
          text "-- #{mode_label} --", fg: mode_fg, bold: true
          if !@pending.empty?
            text " #{@pending}", fg: "#f38ba8"
          end
          if !@count_buf.empty?
            text " #{@count_buf}", fg: "#89b4fa"
          end
          clean = @status.sub(/^-- \w+ --\s*/, "")
          text "  #{clean}", fg: "#6c7086" unless clean.empty?
          if @search_idx >= 0 && !@last_search.empty?
            text "  [#{@search_idx + 1}/#{@search_matches.size}]", fg: "#6c7086"
          end
        end
      end
    end
  end

  private def visual_highlights : Array(Tuple(Int32, Int32, Int32))
    return [] of Tuple(Int32, Int32, Int32) unless @mode == :visual || @mode == :visual_line
    l = lines
    sr, sc = vis_sel_start
    er, ec = vis_sel_end
    if sr > er || (sr == er && sc > ec)
      sr, sc, er, ec = er, ec, sr, sc
    end
    result = [] of Tuple(Int32, Int32, Int32)
    (sr..er).each do |row|
      line = l[row]? || ""
      cs = row == sr ? sc : 0
      ce = row == er ? ec : {line.size - 1, 0}.max
      next if cs > ce && line.empty?
      result << {row, cs, {ce, cs}.max}
    end
    result
  end

  private def vis_sel_start : {Int32, Int32}
    {@visual_start_row, @visual_start_col}
  end

  private def vis_sel_end : {Int32, Int32}
    {@cursor_row, @cursor_col}
  end

  def on_key(key : Ori::Key) : Bool
    handled = case @mode
    when :insert      then handle_insert(key)
    when :normal      then handle_normal(key)
    when :visual      then handle_visual(key)
    when :visual_line then handle_visual_line(key)
    when :command     then handle_command(key)
    when :search      then handle_search(key)
    else false
    end
    rebuild
    handled
  end

  # ── History ──

  private def save_history
    @history = @history[0..@history_idx]
    @history << @text.dup
    @history_idx = @history.size - 1
    if @history.size > 200
      @history = @history[(@history.size - 200)..]
      @history_idx = @history.size - 1
    end
  end

  private def undo
    if @history_idx > 0
      @history_idx -= 1
      @text = @history[@history_idx]
      @status = "#{@history_idx + 1} changes ago"
    else
      @status = "already at oldest"
    end
  end

  private def redo
    if @history_idx < @history.size - 1
      @history_idx += 1
      @text = @history[@history_idx]
      @status = "redone"
    else
      @status = "already at newest"
    end
  end

  # ── Helpers ──

  private def lines : Array(String)
    @text.split('\n')
  end

  private def set_lines(ls : Array(String))
    @text = ls.join('\n')
  end

  private def clamp_row
    l = lines
    @cursor_row = {@cursor_row, l.size - 1}.min
    @cursor_row = {@cursor_row, 0}.max
  end

  private def clamp_col
    l = lines
    line = l[@cursor_row]? || ""
    max_col = @mode == :insert ? line.size : {line.size - 1, 0}.max
    @cursor_col = {@cursor_col, max_col}.min
    @cursor_col = {@cursor_col, 0}.max
  end

  private def count : Int32
    n = @count_buf.to_i?
    @count_buf = ""
    n && n > 0 ? n : 1
  end

  private def first_nonblank(line : String) : Int32
    idx = line.chars.index { |c| !c.ascii_whitespace? }
    idx || 0
  end

  # ── Normal mode ──

  private def handle_normal(key : Ori::Key) : Bool
    ch = key.text
    return false if ch.empty? && !key.ctrl

    if key.ctrl
      case ch
      when "r" then redo; return true
      when "d" then repeat(count) { move_down(lines); move_down(lines); move_down(lines); move_down(lines); move_down(lines); move_down(lines); move_down(lines) }; return true
      when "u" then repeat(count) { move_up(lines); move_up(lines); move_up(lines); move_up(lines); move_up(lines); move_up(lines); move_up(lines) }; return true
      when "f" then repeat(count) { page_down }; return true
      when "b" then repeat(count) { page_up }; return true
      else          return false
      end
    end

    if ch >= "0" && ch <= "9"
      if @count_buf.empty? && ch == "0"
        @cursor_col = 0; @status = ""; return true
      end
      @count_buf += ch; return true
    end

    n = count

    if !@pending.empty?
      handle_pending(ch, n)
      return true
    end

    l = lines
    case ch
    when "h" then repeat(n) { move_left(l) }
    when "j" then repeat(n) { move_down(l) }
    when "k" then repeat(n) { move_up(l) }
    when "l" then repeat(n) { move_right(l) }
    when "w" then repeat(n) { word_forward(l) }
    when "W" then repeat(n) { bigword_forward(l) }
    when "b" then repeat(n) { word_backward(l) }
    when "B" then repeat(n) { bigword_backward(l) }
    when "e" then repeat(n) { word_end(l) }
    when "E" then repeat(n) { bigword_end(l) }
    when "0" then @cursor_col = 0
    when "^" then @cursor_col = first_nonblank(l[@cursor_row]? || "")
    when "$" then @cursor_col = {(l[@cursor_row]? || "").size - 1, 0}.max
    when "G" then @cursor_row = l.size - 1; @cursor_col = first_nonblank(l[@cursor_row]? || ""); clamp_col
    when "g" then @pending = "g"
    when "{" then paragraph_backward(l)
    when "}" then paragraph_forward(l)
    when "%" then match_bracket(l)
    when "f" then @pending = "f"
    when "F" then @pending = "F"
    when "t" then @pending = "t"
    when "T" then @pending = "T"
    when ";" then repeat_char_find_forward(l)
    when "," then repeat_char_find_reverse(l)
    when "x" then repeat(n) { delete_char_forward }
    when "X" then repeat(n) { delete_char_backward }
    when "r" then @pending = "r"
    when "~" then repeat(n) { toggle_case }
    when "J" then join_lines
    when ">" then @pending = ">"
    when "<" then @pending = "<"
    when "d" then @pending = "d"
    when "c" then @pending = "c"
    when "y" then @pending = "y"
    when "p" then repeat(n) { paste_after }
    when "P" then repeat(n) { paste_before }
    when "u" then repeat(n) { undo }
    when "." then repeat_last_change
    when "i" then enter_insert; @status = "-- INSERT --"
    when "I" then @cursor_col = first_nonblank(l[@cursor_row]? || ""); enter_insert; @status = "-- INSERT --"
    when "a" then @cursor_col += 1 if (l[@cursor_row]? || "").size > 0; enter_insert; @status = "-- INSERT --"
    when "A" then @cursor_col = (l[@cursor_row]? || "").size; enter_insert; @status = "-- INSERT --"
    when "o" then open_line_below; enter_insert; @status = "-- INSERT --"
    when "O" then open_line_above; enter_insert; @status = "-- INSERT --"
    when "v" then enter_visual
    when "V" then enter_visual_line
    when ":" then enter_command; @status = ""
    when "/" then enter_search(:forward); @status = ""
    when "?" then enter_search(:backward); @status = ""
    when "n" then repeat(n) { search_next }
    when "N" then repeat(n) { search_prev }
    when "*" then search_word_under_cursor
    else          return false
    end
    true
  end

  @last_find_char : Char? = nil
  @last_find_dir : Symbol = :forward
  @last_find_till : Bool = false

  private def handle_pending(ch : String, n : Int32)
    pending = @pending
    @pending = ""
    l = lines
    case pending
    when "g"
      case ch
      when "g" then @cursor_row = 0; @cursor_col = first_nonblank(lines[0]? || "")
      end
    when "f" then char_find_forward(l, ch[0]?); @last_find_char = ch[0]?; @last_find_dir = :forward; @last_find_till = false
    when "F" then char_find_reverse(l, ch[0]?); @last_find_char = ch[0]?; @last_find_dir = :backward; @last_find_till = false
    when "t" then char_find_till_forward(l, ch[0]?); @last_find_char = ch[0]?; @last_find_dir = :forward; @last_find_till = true
    when "T" then char_find_till_reverse(l, ch[0]?); @last_find_char = ch[0]?; @last_find_dir = :backward; @last_find_till = true
    when "r" then replace_char(ch[0]? || ' ')
    when ">"
      case ch
      when ">" then indent_lines(@cursor_row, @cursor_row)
      when "}" then indent_paragraph(lines)
      end
    when "<"
      case ch
      when "<" then outdent_lines(@cursor_row, @cursor_row)
      when "}" then outdent_paragraph(lines)
      end
    when "d"
      case ch
      when "d"      then delete_lines(@cursor_row, {@cursor_row + n - 1, lines.size - 1}.min)
      when "w", "W" then repeat(n) { delete_word_forward }
      when "b", "B" then repeat(n) { delete_word_backward }
      when "$"      then delete_to_eol
      when "0"      then delete_to_bol
      when "g"      then delete_lines(0, {@cursor_row, lines.size - 1}.min)
      when "G"      then delete_lines(@cursor_row, lines.size - 1)
      when "f"      then @pending = "df"
      when "t"      then @pending = "dt"
      when "j"      then delete_lines(@cursor_row, {@cursor_row + n, lines.size - 1}.min)
      when "k"      then delete_lines({@cursor_row - n, 0}.max, @cursor_row)
      when "{"      then delete_paragraph(lines)
      else
        if ch.size == 1 && (ch[0].ascii_uppercase? || ch[0].ascii_lowercase?)
          @pending = "d"
          handle_text_object_delete(ch, n)
        end
      end
    when "y"
      case ch
      when "y"      then yank_lines(@cursor_row, {@cursor_row + n - 1, lines.size - 1}.min)
      when "w", "W" then yank_word_forward(n)
      when "$"      then yank_to_eol
      when "g"      then @status = "yanked to top"
      when "G"      then @status = "yanked to bottom"
      else
        if ch.size == 1
          @pending = "y"
          handle_text_object_yank(ch, n)
        end
      end
    when "c"
      case ch
      when "c"      then change_line
      when "w", "W" then repeat(n) { change_word_forward }
      when "$"      then change_to_eol
      else
        if ch.size == 1
          @pending = "c"
          handle_text_object_change(ch, n)
        end
      end
    when "df" then delete_to_char(ch[0]?); @last_find_char = ch[0]?; @last_find_dir = :forward; @last_find_till = false
    when "dt" then delete_till_char(ch[0]?); @last_find_char = ch[0]?; @last_find_dir = :forward; @last_find_till = true
    end
  end

  private def repeat(n : Int32, &)
    n.times { yield }
  end

  # ── Motions ──

  private def move_left(l : Array(String))
    @cursor_col -= 1 if @cursor_col > 0; @status = ""
  end

  private def move_down(l : Array(String))
    @cursor_row += 1 if @cursor_row < l.size - 1; clamp_col; @status = ""
  end

  private def move_up(l : Array(String))
    @cursor_row -= 1 if @cursor_row > 0; clamp_col; @status = ""
  end

  private def move_right(l : Array(String))
    line = l[@cursor_row]? || ""; @cursor_col += 1 if @cursor_col < {line.size - 1, 0}.max; @status = ""
  end

  private def word_forward(l : Array(String))
    line = l[@cursor_row]? || ""
    col = @cursor_col
    while col < line.size && !line[col]?.try(&.ascii_whitespace?)
      col += 1
    end
    while col < line.size && line[col]?.try(&.ascii_whitespace?)
      col += 1
    end
    if col >= line.size && @cursor_row < l.size - 1
      @cursor_row += 1; @cursor_col = 0
    else
      @cursor_col = col
    end
  end

  private def bigword_forward(l : Array(String))
    line = l[@cursor_row]? || ""
    col = @cursor_col
    while col < line.size && line[col] != ' '
      col += 1
    end
    while col < line.size && line[col] == ' '
      col += 1
    end
    if col >= line.size && @cursor_row < l.size - 1
      @cursor_row += 1; @cursor_col = 0
    else
      @cursor_col = col
    end
  end

  private def word_backward(l : Array(String))
    line = l[@cursor_row]? || ""
    col = @cursor_col
    while col > 0 && line[col - 1]?.try(&.ascii_whitespace?)
      col -= 1
    end
    while col > 0 && !line[col - 1]?.try(&.ascii_whitespace?)
      col -= 1
    end
    if col == 0 && @cursor_col == 0 && @cursor_row > 0
      @cursor_row -= 1; line = l[@cursor_row]? || ""
      col = line.size
      while col > 0 && line[col - 1]?.try(&.ascii_whitespace?)
        col -= 1
      end
      while col > 0 && !line[col - 1]?.try(&.ascii_whitespace?)
        col -= 1
      end
    end
    @cursor_col = col
  end

  private def bigword_backward(l : Array(String))
    line = l[@cursor_row]? || ""
    col = @cursor_col
    while col > 0 && line[col - 1] == ' '
      col -= 1
    end
    while col > 0 && line[col - 1] != ' '
      col -= 1
    end
    if col == 0 && @cursor_col == 0 && @cursor_row > 0
      @cursor_row -= 1; line = l[@cursor_row]? || ""
      col = line.size
      while col > 0 && line[col - 1] == ' '
        col -= 1
      end
      while col > 0 && line[col - 1] != ' '
        col -= 1
      end
    end
    @cursor_col = col
  end

  private def word_end(l : Array(String))
    line = l[@cursor_row]? || ""
    col = @cursor_col + 1
    while col < line.size && line[col]?.try(&.ascii_whitespace?)
      col += 1
    end
    while col < line.size && !line[col]?.try(&.ascii_whitespace?)
      col += 1
    end
    @cursor_col = {col - 1, @cursor_col}.max
  end

  private def bigword_end(l : Array(String))
    line = l[@cursor_row]? || ""
    col = @cursor_col + 1
    while col < line.size && line[col] == ' '
      col += 1
    end
    while col < line.size && line[col] != ' '
      col += 1
    end
    @cursor_col = {col - 1, @cursor_col}.max
  end

  private def char_find_forward(l : Array(String), ch : Char?)
    return unless ch
    line = l[@cursor_row]? || ""
    idx = line.index(ch, @cursor_col + 1)
    @cursor_col = idx if idx
  end

  private def char_find_reverse(l : Array(String), ch : Char?)
    return unless ch
    line = l[@cursor_row]? || ""
    idx = @cursor_col > 0 ? line.rindex(ch, @cursor_col - 1) : nil
    @cursor_col = idx if idx
  end

  private def char_find_till_forward(l : Array(String), ch : Char?)
    char_find_forward(l, ch)
    @cursor_col -= 1 if @cursor_col > 0
  end

  private def char_find_till_reverse(l : Array(String), ch : Char?)
    char_find_reverse(l, ch)
    @cursor_col += 1
  end

  private def repeat_char_find_forward(l : Array(String))
    return unless c = @last_find_char
    if @last_find_till
      @last_find_dir == :forward ? char_find_till_forward(l, c) : char_find_till_reverse(l, c)
    else
      @last_find_dir == :forward ? char_find_forward(l, c) : char_find_reverse(l, c)
    end
  end

  private def repeat_char_find_reverse(l : Array(String))
    return unless c = @last_find_char
    if @last_find_till
      @last_find_dir == :forward ? char_find_till_reverse(l, c) : char_find_till_forward(l, c)
    else
      @last_find_dir == :forward ? char_find_reverse(l, c) : char_find_forward(l, c)
    end
  end

  private def paragraph_forward(l : Array(String))
    row = @cursor_row
    while row < l.size - 1 && (l[row]? || "").strip.empty?
      row += 1
    end
    while row < l.size - 1 && !(l[row]? || "").strip.empty?
      row += 1
    end
    @cursor_row = row; clamp_col
  end

  private def paragraph_backward(l : Array(String))
    row = @cursor_row
    while row > 0 && (l[row]? || "").strip.empty?
      row -= 1
    end
    while row > 0 && !(l[row]? || "").strip.empty?
      row -= 1
    end
    @cursor_row = row; clamp_col
  end

  private def match_bracket(l : Array(String))
    line = l[@cursor_row]? || ""
    ch = line[@cursor_col]?
    return unless ch
    pairs = {'(' => {')', 1}, ')' => {'(', -1}, '[' => {']', 1}, ']' => {'[', -1}, '{' => {'}', 1}, '}' => {'{', -1}}
    pair = pairs[ch]?
    return unless pair
    target, dir = pair
    depth = 1
    r, c = @cursor_row, @cursor_col
    loop do
      c += dir
      if c < 0
        r -= 1; return if r < 0; line = l[r]? || ""; c = line.size - 1
      elsif c >= (l[r]? || "").size
        r += 1; return if r >= l.size; c = 0
      end
      lc = (l[r]? || "")[c]?
      if lc == ch
        depth += 1
      elsif lc == target
        depth -= 1
        if depth == 0
          @cursor_row = r; @cursor_col = c; return
        end
      end
    end
  end

  private def page_down
    l = lines
    @cursor_row = {@cursor_row + 12, l.size - 1}.min
    clamp_col
  end

  private def page_up
    @cursor_row = {@cursor_row - 12, 0}.max
    clamp_col
  end

  # ── Delete/Change/Yank operations ──

  private def delete_char_forward
    save_history
    l = lines; line = l[@cursor_row]? || ""
    return if @cursor_col >= line.size
    @yank = line[@cursor_col].to_s; @yank_is_lines = false
    l[@cursor_row] = line[0...@cursor_col] + line[@cursor_col + 1..]
    set_lines(l); clamp_col
  end

  private def delete_char_backward
    return if @cursor_col == 0
    save_history
    l = lines; line = l[@cursor_row]? || ""
    @cursor_col -= 1
    @yank = line[@cursor_col].to_s; @yank_is_lines = false
    l[@cursor_row] = line[0...@cursor_col] + line[@cursor_col + 1..]
    set_lines(l); clamp_col
  end

  private def delete_word_forward
    save_history
    l = lines; line = l[@cursor_row]? || ""
    return if line.empty?
    col = @cursor_col
    while col < line.size && !line[col]?.try(&.ascii_whitespace?)
      col += 1
    end
    while col < line.size && line[col]?.try(&.ascii_whitespace?)
      col += 1
    end
    @yank = line[@cursor_col...col]; @yank_is_lines = false
    l[@cursor_row] = line[0...@cursor_col] + line[col..]
    set_lines(l); clamp_col
  end

  private def delete_word_backward
    save_history
    l = lines; line = l[@cursor_row]? || ""
    return if @cursor_col == 0
    col = @cursor_col
    while col > 0 && line[col - 1]?.try(&.ascii_whitespace?)
      col -= 1
    end
    while col > 0 && !line[col - 1]?.try(&.ascii_whitespace?)
      col -= 1
    end
    @yank = line[col...@cursor_col]; @yank_is_lines = false
    l[@cursor_row] = line[0...col] + line[@cursor_col..]
    @cursor_col = col
    set_lines(l); clamp_col
  end

  private def delete_to_eol
    save_history
    l = lines; line = l[@cursor_row]? || ""
    @yank = line[@cursor_col..]; @yank_is_lines = false
    l[@cursor_row] = line[0...@cursor_col]
    set_lines(l); clamp_col
  end

  private def delete_to_bol
    save_history
    l = lines; line = l[@cursor_row]? || ""
    @yank = line[0...@cursor_col]; @yank_is_lines = false
    l[@cursor_row] = line[@cursor_col..]
    @cursor_col = 0
    set_lines(l)
  end

  private def delete_to_char(ch : Char?)
    return unless ch
    save_history
    l = lines; line = l[@cursor_row]? || ""
    idx = line.index(ch, @cursor_col + 1)
    return unless idx
    @yank = line[@cursor_col..idx]; @yank_is_lines = false
    l[@cursor_row] = line[0...@cursor_col] + line[idx + 1..]
    set_lines(l); clamp_col
  end

  private def delete_till_char(ch : Char?)
    return unless ch
    save_history
    l = lines; line = l[@cursor_row]? || ""
    idx = line.index(ch, @cursor_col + 1)
    return unless idx
    @yank = line[@cursor_col...idx]; @yank_is_lines = false
    l[@cursor_row] = line[0...@cursor_col] + line[idx..]
    set_lines(l); clamp_col
  end

  private def delete_lines(from : Int32, to : Int32)
    save_history
    l = lines; from = {from, 0}.max; to = {to, l.size - 1}.min
    yanked = l[from..to].join('\n')
    (to - from + 1).times { l.delete_at(from) if from < l.size }
    l << "" if l.empty?
    set_lines(l)
    @yank = yanked; @yank_is_lines = true
    @cursor_row = {from, l.size - 1}.min; @cursor_col = 0; clamp_col
    @status = "#{to - from + 1} line(s) deleted"
  end

  private def delete_paragraph(l : Array(String))
    sr = @cursor_row
    while sr > 0 && !(l[sr - 1]? || "").strip.empty?
      sr -= 1
    end
    er = @cursor_row
    while er < l.size - 1 && !(l[er + 1]? || "").strip.empty?
      er += 1
    end
    delete_lines(sr, er)
  end

  private def change_word_forward
    save_history
    l = lines; line = l[@cursor_row]? || ""
    col = @cursor_col
    while col < line.size && !line[col]?.try(&.ascii_whitespace?)
      col += 1
    end
    while col < line.size && line[col]?.try(&.ascii_whitespace?)
      col += 1
    end
    l[@cursor_row] = line[0...@cursor_col] + line[col..]
    set_lines(l); enter_insert; @status = "-- INSERT --"
  end

  private def change_line
    save_history
    l = lines; l[@cursor_row] = ""; set_lines(l)
    @cursor_col = 0; enter_insert; @status = "-- INSERT --"
  end

  private def change_to_eol
    save_history
    l = lines; line = l[@cursor_row]? || ""
    l[@cursor_row] = line[0...@cursor_col]
    set_lines(l); enter_insert; @status = "-- INSERT --"
  end

  private def yank_lines(from : Int32, to : Int32)
    l = lines; to = {to, l.size - 1}.min
    @yank = l[from..to].join('\n'); @yank_is_lines = true
    @status = "#{to - from + 1} line(s) yanked"
  end

  private def yank_word_forward(n : Int32)
    l = lines; line = l[@cursor_row]? || ""
    col = @cursor_col
    n.times do
      while col < line.size && !line[col]?.try(&.ascii_whitespace?)
        col += 1
      end
      while col < line.size && line[col]?.try(&.ascii_whitespace?)
        col += 1
      end
    end
    @yank = line[@cursor_col...col]; @yank_is_lines = false
    @status = "word yanked"
  end

  private def yank_to_eol
    l = lines; line = l[@cursor_row]? || ""
    @yank = line[@cursor_col..]; @yank_is_lines = false
    @status = "yanked to end"
  end

  # ── Text objects ──

  private def handle_text_object_delete(ch : String, n : Int32)
    handle_text_object(ch, n) do |start_col, end_col|
      save_history
      l = lines; line = l[@cursor_row]? || ""
      @yank = line[start_col..end_col]? || ""; @yank_is_lines = false
      l[@cursor_row] = (line[0...start_col]? || "") + (line[(end_col + 1)..]? || "")
      set_lines(l); @cursor_col = {start_col, 0}.max; clamp_col
    end
  end

  private def handle_text_object_yank(ch : String, n : Int32)
    handle_text_object(ch, n) do |start_col, end_col|
      l = lines; line = l[@cursor_row]? || ""
      @yank = line[start_col..end_col]? || ""; @yank_is_lines = false
      @status = "text object yanked"
    end
  end

  private def handle_text_object_change(ch : String, n : Int32)
    handle_text_object(ch, n) do |start_col, end_col|
      save_history
      l = lines; line = l[@cursor_row]? || ""
      l[@cursor_row] = (line[0...start_col]? || "") + (line[(end_col + 1)..]? || "")
      set_lines(l); @cursor_col = start_col; enter_insert; @status = "-- INSERT --"
    end
  end

  private def handle_text_object(ch : String, n : Int32, &)
    inner = ch.starts_with?("i")
    obj = inner ? ch[1..] : (ch.starts_with?("a") ? ch[1..] : ch)
    l = lines; line = l[@cursor_row]? || ""
    case obj
    when "w"
      s, e = text_object_word(line, inner)
      yield s, e
    when "\""
      if range = text_object_delimiters(line, '"', inner)
        yield range[0], range[1]
      end
    when "'", "`"
      if range = text_object_delimiters(line, ch[0], inner)
        yield range[0], range[1]
      end
    when "(", ")"
      if range = text_object_brackets(line, '(', ')', inner)
        yield range[0], range[1]
      end
    when "[", "]"
      if range = text_object_brackets(line, '[', ']', inner)
        yield range[0], range[1]
      end
    when "{", "}"
      if range = text_object_brackets(line, '{', '}', inner)
        yield range[0], range[1]
      end
    end
    @pending = ""
  end

  private def text_object_word(line : String, inner : Bool) : {Int32, Int32}
    s = @cursor_col
    while s > 0 && !line[s - 1]?.try(&.ascii_whitespace?)
      s -= 1
    end
    e = @cursor_col
    while e < line.size - 1 && !line[e + 1]?.try(&.ascii_whitespace?)
      e += 1
    end
    if !inner
      while e < line.size - 1 && line[e + 1]?.try(&.ascii_whitespace?)
        e += 1
      end
    end
    {s, e}
  end

  private def text_object_delimiters(line : String, delim : Char, inner : Bool) : {Int32, Int32}?
    left = line.rindex(delim, @cursor_col)
    return unless left
    right = line.index(delim, @cursor_col + 1) || line.rindex(delim)
    return unless right && right > left
    inner ? {left + 1, right - 1} : {left, right}
  end

  private def text_object_brackets(line : String, open : Char, close : Char, inner : Bool) : {Int32, Int32}?
    depth = 0; open_idx = nil; close_idx = nil
    line.each_char_with_index do |c, i|
      if c == open
        depth += 1
        open_idx = i if open_idx.nil? || (i <= @cursor_col && i > (open_idx || 0))
      elsif c == close
        if depth > 0
          depth -= 1
          close_idx = i if open_idx && close_idx.nil?
        end
      end
    end
    return unless open_idx && close_idx && close_idx > open_idx
    inner ? {open_idx + 1, close_idx - 1} : {open_idx, close_idx}
  end

  # ── Other operations ──

  private def replace_char(ch : Char)
    save_history
    l = lines; line = l[@cursor_row]? || ""
    return if @cursor_col >= line.size
    l[@cursor_row] = line[0...@cursor_col] + ch + line[@cursor_col + 1..]
    set_lines(l)
  end

  private def toggle_case
    save_history
    l = lines; line = l[@cursor_row]? || ""
    return if @cursor_col >= line.size
    c = line[@cursor_col]
    nc = c.uppercase? ? c.downcase : c.upcase
    l[@cursor_row] = line[0...@cursor_col] + nc + line[@cursor_col + 1..]
    set_lines(l)
    @cursor_col += 1 if @cursor_col < line.size - 1
  end

  private def join_lines
    save_history
    l = lines
    return if @cursor_row >= l.size - 1
    l[@cursor_row] = (l[@cursor_row]? || "").rstrip + " " + (l[@cursor_row + 1]? || "").lstrip
    l.delete_at(@cursor_row + 1)
    set_lines(l); clamp_col
  end

  private def indent_lines(from : Int32, to : Int32)
    save_history
    l = lines; (from..to).each do |i|
      next if i >= l.size
      l[i] = "  " + l[i]
    end
    set_lines(l)
  end

  private def outdent_lines(from : Int32, to : Int32)
    save_history
    l = lines; (from..to).each do |i|
      next if i >= l.size
      line = l[i]
      l[i] = line.starts_with?("  ") ? line[2..] : (line.starts_with?("\t") ? line[1..] : line)
    end
    set_lines(l); clamp_col
  end

  private def indent_paragraph(l : Array(String))
    sr = @cursor_row
    while sr > 0 && !(l[sr - 1]? || "").strip.empty?
      sr -= 1
    end
    er = @cursor_row
    while er < l.size - 1 && !(l[er + 1]? || "").strip.empty?
      er += 1
    end
    indent_lines(sr, er)
  end

  private def outdent_paragraph(l : Array(String))
    sr = @cursor_row
    while sr > 0 && !(l[sr - 1]? || "").strip.empty?
      sr -= 1
    end
    er = @cursor_row
    while er < l.size - 1 && !(l[er + 1]? || "").strip.empty?
      er += 1
    end
    outdent_lines(sr, er)
  end

  private def paste_after
    return if @yank.empty?
    save_history
    l = lines
    if @yank_is_lines
      @yank.split('\n').each_with_index { |yl, i| l.insert(@cursor_row + 1 + i, yl) }
      @cursor_row += 1; @cursor_col = 0
    else
      line = l[@cursor_row]? || ""
      pos = {@cursor_col + 1, line.size}.min
      l[@cursor_row] = line[0...pos] + @yank + line[pos..]
      @cursor_col = pos + @yank.size - 1
    end
    set_lines(l); clamp_col
  end

  private def paste_before
    return if @yank.empty?
    save_history
    l = lines
    if @yank_is_lines
      @yank.split('\n').reverse_each { |yl| l.insert(@cursor_row, yl) }
      @cursor_col = 0
    else
      line = l[@cursor_row]? || ""
      l[@cursor_row] = line[0...@cursor_col] + @yank + line[@cursor_col..]
      @cursor_col = @cursor_col + @yank.size - 1
    end
    set_lines(l); clamp_col
  end

  private def open_line_below
    save_history; l = lines; l.insert(@cursor_row + 1, "")
    set_lines(l); @cursor_row += 1; @cursor_col = 0
  end

  private def open_line_above
    save_history; l = lines; l.insert(@cursor_row, "")
    set_lines(l); @cursor_col = 0
  end

  @last_change : Proc(Nil)? = nil

  private def repeat_last_change
    @last_change.try(&.call)
  end

  # ── Insert mode ──

  private def enter_insert
    @mode = :insert
  end

  private def handle_insert(key : Ori::Key) : Bool
    if key.code.escape?
      @mode = :normal
      @cursor_col -= 1 if @cursor_col > 0
      clamp_col; @status = ""; save_history
      return true
    end
    if fm = @focus
      fm.handle_key(key)
    end
    true
  end

  # ── Visual mode ──

  private def enter_visual
    @mode = :visual
    @visual_start_row = @cursor_row
    @visual_start_col = @cursor_col
    @status = "-- VISUAL --"
  end

  private def enter_visual_line
    @mode = :visual_line
    @visual_start_row = @cursor_row
    @visual_start_col = 0
    @cursor_col = {(lines[@cursor_row]? || "").size - 1, 0}.max
    @status = "-- VISUAL LINE --"
  end

  private def handle_visual(key : Ori::Key) : Bool
    if key.code.escape?
      @mode = :normal; @status = ""; return true
    end
    ch = key.text; return false if ch.empty?
    l = lines
    case ch
    when "h"      then move_left(l)
    when "j"      then move_down(l)
    when "k"      then move_up(l)
    when "l"      then move_right(l)
    when "w"      then word_forward(l)
    when "b"      then word_backward(l)
    when "e"      then word_end(l)
    when "0"      then @cursor_col = 0
    when "$"      then @cursor_col = {(l[@cursor_row]? || "").size - 1, 0}.max
    when "G"      then @cursor_row = l.size - 1; clamp_col
    when "g"      then @cursor_row = 0; @cursor_col = 0
    when "{"      then paragraph_backward(l)
    when "}"      then paragraph_forward(l)
    when "d", "x" then visual_delete; @mode = :normal; @status = "visual deleted"
    when "y"      then visual_yank; @mode = :normal
    when "c"      then visual_delete; enter_insert; @status = "-- INSERT --"
    when "o"      then @visual_start_row, @cursor_row = @cursor_row, @visual_start_row; @visual_start_col, @cursor_col = @cursor_col, @visual_start_col
    when "J"      then visual_join; @mode = :normal
    else               return false
    end
    true
  end

  private def handle_visual_line(key : Ori::Key) : Bool
    if key.code.escape?
      @mode = :normal; @status = ""; return true
    end
    ch = key.text; return false if ch.empty?
    l = lines
    case ch
    when "j" then move_down(l)
    when "k" then move_up(l)
    when "G" then @cursor_row = l.size - 1
    when "g" then @cursor_row = 0
    when "d", "x"
      sr, er = {@visual_start_row, @cursor_row}.minmax
      delete_lines(sr, er); @mode = :normal; @status = "visual line deleted"
    when "y"
      sr, er = {@visual_start_row, @cursor_row}.minmax
      yank_lines(sr, er); @mode = :normal
    when "c"
      sr, er = {@visual_start_row, @cursor_row}.minmax
      delete_lines(sr, er); enter_insert; @status = "-- INSERT --"
    when "o" then @visual_start_row, @cursor_row = @cursor_row, @visual_start_row
    else          return false
    end
    if @mode == :visual_line
      @cursor_col = {(l[@cursor_row]? || "").size - 1, 0}.max
      @visual_start_col = 0
    end
    true
  end

  private def visual_selection : String
    l = lines
    sr, sc = {@visual_start_row, @visual_start_col}
    er, ec = {@cursor_row, @cursor_col}
    if sr > er || (sr == er && sc > ec)
      sr, sc, er, ec = er, ec, sr, sc
    end
    if sr == er
      return (l[sr]? || "")[sc..ec].to_s
    end
    buf = (l[sr]? || "")[sc..].to_s + "\n"
    (sr + 1...er).each { |i| buf += (l[i]? || "") + "\n" }
    buf + (l[er]? || "")[0..ec].to_s
  end

  private def visual_delete
    save_history
    l = lines
    sr, sc = {@visual_start_row, @visual_start_col}
    er, ec = {@cursor_row, @cursor_col}
    if sr > er || (sr == er && sc > ec)
      sr, sc, er, ec = er, ec, sr, sc
    end
    @yank = visual_selection; @yank_is_lines = (sr != er)
    if sr == er
      line = l[sr]? || ""
      l[sr] = line[0...sc] + line[(ec + 1)..]
    else
      first = (l[sr]? || "")[0...sc]
      last = (l[er]? || "")[(ec + 1)..]
      l[sr] = first + last
      (er - sr).times { l.delete_at(sr + 1) if l.size > sr + 1 }
    end
    l << "" if l.empty?
    set_lines(l); @cursor_row = sr; @cursor_col = sc; clamp_col
  end

  private def visual_yank
    @yank = visual_selection
    @yank_is_lines = (vis_sel_start[0] != vis_sel_end[0])
    @status = "visual yanked"
  end

  private def visual_join
    sr, er = {@visual_start_row, @cursor_row}.minmax
    save_history
    l = lines
    (er - sr).times do
      break if sr + 1 >= l.size
      l[sr] = (l[sr]? || "").rstrip + " " + (l[sr + 1]? || "").lstrip
      l.delete_at(sr + 1)
    end
    set_lines(l); @cursor_row = sr; clamp_col
    @status = "visual joined"
  end

  # ── Command mode ──

  private def enter_command
    @mode = :command; @command_buf = ""
  end

  private def handle_command(key : Ori::Key) : Bool
    if key.code.escape?
      @mode = :normal; @status = ""; return true
    end
    if key.code.enter?
      execute_command(@command_buf); @mode = :normal; return true
    end
    if key.code.backspace?
      if @command_buf.empty?
        @mode = :normal; @status = ""
      else
        @command_buf = @command_buf[0...-1]
      end
      return true
    end
    if key.printable?
      @command_buf += key.text; return true
    end
    false
  end

  private def execute_command(cmd : String)
    case cmd.strip
    when "q"       then @running = false
    when "q!"      then @running = false
    when "w"       then @status = "saved (no file backend)"
    when "wq", "x" then @status = "saved"; @running = false
    else
      if cmd.starts_with?("%s/")
        execute_substitute(cmd[3..])
      else
        @status = "not an editor command: #{cmd}"
      end
    end
  end

  private def execute_substitute(args : String)
    parts = args.split('/')
    if parts.size < 2
      @status = "usage: %s/old/new/g"; return
    end
    old = parts[0]; new_p = parts.size > 1 ? parts[1] : ""
    global = parts.size > 2 && parts[2].includes?("g")
    save_history
    @text = global ? @text.gsub(old, new_p) : @text.sub(old, new_p)
    @status = "substituted"
  end

  # ── Search mode ──

  private def enter_search(dir : Symbol)
    @mode = :search; @search_query = ""; @search_direction = dir
  end

  private def handle_search(key : Ori::Key) : Bool
    if key.code.escape?
      @mode = :normal; @status = ""; return true
    end
    if key.code.enter?
      if @search_query.empty?
        @mode = :normal; @status = ""; return true
      end
      @last_search = @search_query; @last_search_dir = @search_direction
      find_matches
      if @search_matches.empty?
        @status = "pattern not found"; @search_idx = -1
      else
        @search_idx = 0; jump_to_match(0); @status = ""
      end
      @mode = :normal; return true
    end
    if key.code.backspace?
      if @search_query.empty?
        @mode = :normal; @status = ""
      else
        @search_query = @search_query[0...-1]
      end
      return true
    end
    if key.printable?
      @search_query += key.text; return true
    end
    false
  end

  private def find_matches
    @search_matches = [] of {Int32, Int32}
    l = lines
    l.each_with_index do |line, row|
      pos = @last_search_dir == :forward ? line.index(@last_search) : line.rindex(@last_search)
      while pos
        @search_matches << {row, pos}
        pos = @last_search_dir == :forward ? line.index(@last_search, pos + 1) : (pos > 0 ? line.rindex(@last_search, pos - 1) : nil)
        break if @search_matches.size > 1000
      end
    end
  end

  private def search_next
    if @last_search.empty?
      @status = "no previous search"; return
    end
    find_matches
    if @search_matches.empty?
      @status = "pattern not found"; @search_idx = -1; return
    end
    best = @search_matches.index { |m| m[0] > @cursor_row || (m[0] == @cursor_row && m[1] > @cursor_col) }
    best ||= 0
    @search_idx = best; jump_to_match(best); @status = ""
  end

  private def search_prev
    if @last_search.empty?
      @status = "no previous search"; return
    end
    find_matches
    if @search_matches.empty?
      @status = "pattern not found"; @search_idx = -1; return
    end
    best = -1
    @search_matches.each_with_index do |m, i|
      best = i if m[0] < @cursor_row || (m[0] == @cursor_row && m[1] < @cursor_col)
    end
    best = @search_matches.size - 1 if best < 0
    @search_idx = best; jump_to_match(best); @status = ""
  end

  private def search_word_under_cursor
    l = lines; line = l[@cursor_row]? || ""
    col = @cursor_col
    s = col
    while s > 0 && !line[s - 1]?.try(&.ascii_whitespace?)
      s -= 1
    end
    e = col
    while e < line.size && !line[e]?.try(&.ascii_whitespace?)
      e += 1
    end
    word = line[s...e]
    return if word.empty?
    @last_search = word; @last_search_dir = :forward
    find_matches
    if @search_matches.empty?
      @status = "pattern not found"; @search_idx = -1
    else
      idx = @search_matches.index { |m| m[0] > @cursor_row || (m[0] == @cursor_row && m[1] > @cursor_col) }
      idx ||= 0
      @search_idx = idx; jump_to_match(idx); @status = ""
    end
  end

  private def jump_to_match(idx : Int32)
    return if idx < 0 || idx >= @search_matches.size
    row, col = @search_matches[idx]
    @cursor_row = row; @cursor_col = col; clamp_col
  end
end

VimEditorApp.run
