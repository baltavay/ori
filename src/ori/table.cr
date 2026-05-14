class Ori::Table < Ori::Node
  @headers : Array(String)
  @rows : Array(Array(String))
  @selected_row : Int32
  @scroll_offset : Int32
  @on_change : Proc(Int32, Nil)?
  @on_select : Proc(Int32, Nil)?
  @header_fg : String?
  @selected_fg : String?
  @selected_bg : String?

  def initialize(
    @headers : Array(String) = [] of String,
    @rows : Array(Array(String)) = [] of Array(String),
    selected_row : Int32 = 0,
    @on_change : Proc(Int32, Nil)? = nil,
    @on_select : Proc(Int32, Nil)? = nil,
    @header_fg : String? = nil,
    @selected_fg : String? = nil,
    @selected_bg : String? = nil,
    style : Ori::S = Ori::S.none
  )
    super(style)
    @selected_row = selected_row
    @scroll_offset = 0
  end

  getter headers : Array(String)
  getter rows : Array(Array(String))
  getter selected_row : Int32

  def selected_row=(row : Int32) : Nil
    @selected_row = {row, {@rows.size - 1, 0}.max}.min
  end

  def rows=(@rows : Array(Array(String))) : Nil
    @selected_row = {@selected_row, {@rows.size - 1, 0}.max}.min
  end

  def headers=(@headers : Array(String)) : Nil
  end

  def selected_row_data : Array(String)?
    @rows[@selected_row]?
  end

  def row_count : Int32
    @rows.size
  end

  def move_up : Nil
    @selected_row -= 1 if @selected_row > 0
  end

  def move_down : Nil
    @selected_row += 1 if @selected_row < @rows.size - 1
  end

  def move_top : Nil
    @selected_row = 0
  end

  def move_bottom : Nil
    @selected_row = {@rows.size - 1, 0}.max
  end

  def content_height : Int32
    h = 0
    h += 1 if has_border?
    h += 1 unless @headers.empty?
    h += 1 if has_border? && !@headers.empty?
    h += @rows.size
    h += 1 if has_border?
    h == 0 ? 1 : h
  end

  def content_width : Int32
    n = num_cols
    return 1 if n == 0
    w = natural_widths.sum
    if has_border?
      w += n + 1
    elsif n > 1
      w += n - 1
    end
    w
  end

  def focusable? : Bool
    @style.focusable
  end

  def on_key(key : Ori::Key) : Bool
    old = @selected_row
    handled = case
      when key.code.up? || key.text == "k"
        move_up; true
      when key.code.down? || key.text == "j"
        move_down; true
      when key.code.home? || key.text == "g"
        move_top; true
      when key.code.end? || key.text == "G"
        move_bottom; true
      when key.code.enter?
        @on_select.try(&.call(@selected_row))
        true
      else
        false
      end
    @on_change.try(&.call(@selected_row)) if handled && @selected_row != old
    handled
  end

  def render(io : IO) : Nil
    r = @rect
    return if r.w <= 0 || r.h <= 0
    n = num_cols
    return if n == 0
    widths = col_widths(r.w)
    hb = has_border?
    hh = !@headers.empty?
    bfg = @style.border_fg || @style.fg
    hfg = @header_fg || @style.fg
    ebg = effective_bg
    fg = @style.fg
    ry = 0

    if hb
      io << Ori::Term.move(r.x, r.y) << ansi_hline(widths, :top, bfg, ebg)
      ry += 1
    end

    if hh
      io << Ori::Term.move(r.x, r.y + ry) << ansi_row(widths, @headers, hfg, ebg, true, bfg)
      ry += 1
      if hb
        io << Ori::Term.move(r.x, r.y + ry) << ansi_hline(widths, :sep, bfg, ebg)
        ry += 1
      end
    end

    adjust_scroll(ry, r.h)
    vs = @scroll_offset
    ve = {@scroll_offset + vis_count(ry, r.h), @rows.size}.min

    vs.upto(ve - 1) do |ri|
      row = @rows[ri]? || [] of String
      sel = ri == @selected_row && @focused
      io << Ori::Term.move(r.x, r.y + ry) << ansi_row(widths, row, sel ? @selected_fg : fg, sel ? @selected_bg : ebg, sel, bfg)
      ry += 1
    end

    while hb && ry < r.h - 1
      io << Ori::Term.move(r.x, r.y + ry) << ansi_row(widths, [] of String, fg, ebg, false, bfg)
      ry += 1
    end

    if hb && r.h > 0
      io << Ori::Term.move(r.x, r.y + r.h - 1) << ansi_hline(widths, :bottom, bfg, ebg)
    end
  end

  def render_screen(screen : Ori::Screen) : Nil
    r = @rect
    return if r.w <= 0 || r.h <= 0
    n = num_cols
    return if n == 0
    widths = col_widths(r.w)
    hb = has_border?
    hh = !@headers.empty?
    bfg = @style.border_fg || @style.fg
    hfg = @header_fg || @style.fg
    ebg = effective_bg
    fg = @style.fg
    ry = 0

    if hb
      draw_hline(screen, r.x, r.y + ry, widths, :top, bfg, ebg)
      ry += 1
    end

    if hh
      draw_cells(screen, r.x, r.y + ry, widths, @headers, hfg, ebg, true, bfg)
      ry += 1
      if hb
        draw_hline(screen, r.x, r.y + ry, widths, :sep, bfg, ebg)
        ry += 1
      end
    end

    adjust_scroll(ry, r.h)
    vs = @scroll_offset
    ve = {@scroll_offset + vis_count(ry, r.h), @rows.size}.min

    vs.upto(ve - 1) do |ri|
      row = @rows[ri]? || [] of String
      sel = ri == @selected_row && @focused
      draw_cells(screen, r.x, r.y + ry, widths, row, sel ? @selected_fg : fg, sel ? @selected_bg : ebg, sel, bfg)
      ry += 1
    end

    while hb && ry < r.h - 1
      draw_cells(screen, r.x, r.y + ry, widths, [] of String, fg, ebg, false, bfg)
      ry += 1
    end

    if hb && r.h > 0
      draw_hline(screen, r.x, r.y + r.h - 1, widths, :bottom, bfg, ebg)
    end
  end

  private def has_border? : Bool
    @style.border != :none
  end

  private def num_cols : Int32
    {@headers.size, (@rows.map(&.size).max? || 0)}.max
  end

  private def natural_widths : Array(Int32)
    n = num_cols
    return [] of Int32 if n == 0
    w = Array(Int32).new(n, 0)
    @headers.each_with_index { |h, i| w[i] = {w[i], h.size}.max }
    @rows.each { |row| row.each_with_index { |c, i| w[i] = {w[i], c.size}.max if i < n } }
    w
  end

  private def col_widths(rect_w : Int32) : Array(Int32)
    w = natural_widths
    return w if w.empty? || rect_w <= 0
    n = w.size
    oh = has_border? ? n + 1 : {n - 1, 0}.max
    avail = {rect_w - oh, 0}.max
    total = w.sum
    if avail > total
      (avail - total).times { |i| w[i % n] += 1 }
    elsif avail < total && avail > 0
      diff = total - avail
      while diff > 0
        idx = w.each_with_index.max_by { |v, _| v }[1]
        break if w[idx] <= 0
        w[idx] -= 1
        diff -= 1
      end
    end
    w
  end

  private def bc
    case @style.border
    when :double
      {tl: '╔', tr: '╗', bl: '╚', br: '╝', h: '═', v: '║', lj: '╠', rj: '╣', tj: '╦', bj: '╩', x: '╬'}
    when :rounded
      {tl: '╭', tr: '╮', bl: '╰', br: '╯', h: '─', v: '│', lj: '├', rj: '┤', tj: '┬', bj: '┴', x: '┼'}
    else
      {tl: '┌', tr: '┐', bl: '└', br: '┘', h: '─', v: '│', lj: '├', rj: '┤', tj: '┬', bj: '┴', x: '┼'}
    end
  end

  private def draw_hline(screen, x, y, widths, type, fg, bg)
    c = bc
    l, m, r = hl_parts(c, type)
    cx = x
    screen.put(cx, y, l, fg: fg, bg: bg); cx += 1
    widths.each_with_index do |w, i|
      w.times { |j| screen.put(cx + j, y, c[:h], fg: fg, bg: bg) }
      cx += w
      if i < widths.size - 1
        screen.put(cx, y, m, fg: fg, bg: bg); cx += 1
      end
    end
    screen.put(cx, y, r, fg: fg, bg: bg)
  end

  private def draw_cells(screen, x, y, widths, cells, fg, bg, bold, bfg)
    c = bc
    cx = x
    if has_border?
      screen.put(cx, y, c[:v], fg: bfg, bg: bg); cx += 1
    end
    widths.each_with_index do |w, i|
      (cells[i]? || "").ljust(w).each_char do |ch|
        screen.put(cx, y, ch, fg: fg, bg: bg, bold: bold); cx += 1
      end
      if has_border? && i < widths.size - 1
        screen.put(cx, y, c[:v], fg: bfg, bg: bg); cx += 1
      end
    end
    if has_border?
      screen.put(cx, y, c[:v], fg: bfg, bg: bg)
    end
  end

  private def ansi_hline(widths, type, fg, bg) : String
    c = bc
    l, m, r = hl_parts(c, type)
    parts = [l.to_s]
    widths.each_with_index do |w, i|
      parts << (c[:h].to_s * w)
      parts << m.to_s if i < widths.size - 1
    end
    parts << r.to_s
    Ori::Color.paint(parts.join, fg, bg)
  end

  private def ansi_row(widths, cells, fg, bg, bold, bfg) : String
    c = bc
    parts = [] of String
    parts << Ori::Color.paint(c[:v].to_s, bfg, bg) if has_border?
    widths.each_with_index do |w, i|
      parts << Ori::Color.paint((cells[i]? || "").ljust(w), fg, bg, bold)
      if has_border? && i < widths.size - 1
        parts << Ori::Color.paint(c[:v].to_s, bfg, bg)
      end
    end
    parts << Ori::Color.paint(c[:v].to_s, bfg, bg) if has_border?
    parts.join
  end

  private def hl_parts(c, type)
    case type
    when :top    then {c[:tl], c[:tj], c[:tr]}
    when :sep    then {c[:lj], c[:x], c[:rj]}
    when :bottom then {c[:bl], c[:bj], c[:br]}
    else              {c[:lj], c[:x], c[:rj]}
    end
  end

  private def vis_count(header_rows : Int32, rect_h : Int32) : Int32
    {rect_h - header_rows - (has_border? ? 1 : 0), 0}.max
  end

  private def adjust_scroll(header_rows : Int32, rect_h : Int32) : Nil
    vc = vis_count(header_rows, rect_h)
    if @selected_row < @scroll_offset
      @scroll_offset = @selected_row
    elsif @selected_row >= @scroll_offset + vc
      @scroll_offset = @selected_row - vc + 1
    end
    @scroll_offset = {@scroll_offset, 0}.max
  end
end
