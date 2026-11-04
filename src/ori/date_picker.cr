class Ori::DatePicker < Ori::Node
  include Ori::CalendarHelper

  ARROW = "▾"

  @year : Int32
  @month : Int32
  @cursor_day : Int32
  @cal_year : Int32
  @cal_month : Int32
  @cal_day : Int32
  @open : Bool
  @monday_first : Bool
  @on_change : Proc(Time, Nil)?
  @on_toggle : Proc(Bool, Nil)?
  @header_fg : String?
  @selected_fg : String?
  @selected_bg : String?
  @today_fg : String?
  @today_bg : String?
  @day_fg : String?
  @other_month_fg : String?

  def initialize(
    year : Int32? = nil,
    month : Int32? = nil,
    day : Int32? = nil,
    @monday_first : Bool = false,
    @open : Bool = false,
    @on_change : Proc(Time, Nil)? = nil,
    @on_toggle : Proc(Bool, Nil)? = nil,
    @header_fg : String? = nil,
    @selected_fg : String? = nil,
    @selected_bg : String? = nil,
    @today_fg : String? = nil,
    @today_bg : String? = nil,
    @day_fg : String? = nil,
    @other_month_fg : String? = nil,
    style : Ori::S = Ori::S.none
  )
    super(style)
    now = Time.local
    @year = year || now.year
    @month = month || now.month
    @cursor_day = day || now.day
    @cal_year = @year
    @cal_month = @month
    @cal_day = @cursor_day
  end

  getter year : Int32
  getter month : Int32
  getter cursor_day : Int32
  getter open : Bool
  getter monday_first : Bool

  def date : Time
    d = @cursor_day.clamp(1, days_in_month(@year, @month))
    Time.utc(@year, @month, d)
  end

  def set_date(y : Int32, m : Int32, d : Int32) : Nil
    @year = y
    @month = m.clamp(1, 12)
    @cursor_day = d.clamp(1, days_in_month(@year, @month))
  end

  def content_height : Int32
    has_border? ? 3 : 1
  end

  def content_width : Int32
    inner = 14
    has_border? ? inner + 2 : inner
  end

  private def has_border? : Bool
    @style.border != :none
  end

  def focusable? : Bool
    @style.focusable
  end

  def blur : Nil
    if @open
      @open = false
      @on_toggle.try(&.call(false))
    end
  end

  def on_key(key : Ori::Key) : Bool
    @open ? handle_open_key(key) : handle_closed_key(key)
  end

  private def handle_closed_key(key : Ori::Key) : Bool
    case
    when key.code.enter? || key.code.space?
      open_cal
      true
    else
      false
    end
  end

  private def handle_open_key(key : Ori::Key) : Bool
    case
    when key.text == "h" || key.code.left?
      cal_move_left; true
    when key.text == "l" || key.code.right?
      cal_move_right; true
    when key.text == "k" || key.code.up?
      cal_move_up; true
    when key.text == "j" || key.code.down?
      cal_move_down; true
    when key.text == "H"
      do_prev_month; cal_clamp; true
    when key.text == "L"
      do_next_month; cal_clamp; true
    when key.text == "K"
      @cal_year -= 1; cal_clamp; true
    when key.text == "J"
      @cal_year += 1; cal_clamp; true
    when key.text == "t"
      now = Time.local
      @cal_year = now.year; @cal_month = now.month; @cal_day = now.day
      true
    when key.code.enter?
      confirm; true
    when key.code.escape?
      cancel; true
    else
      true
    end
  end

  private def open_cal : Nil
    @open = true
    @cal_year = @year; @cal_month = @month; @cal_day = @cursor_day
    @on_toggle.try(&.call(true))
  end

  private def confirm : Nil
    @year = @cal_year; @month = @cal_month
    @cursor_day = @cal_day.clamp(1, days_in_month(@cal_year, @cal_month))
    @open = false
    @on_change.try(&.call(date))
    @on_toggle.try(&.call(false))
  end

  private def cancel : Nil
    @open = false
    @on_toggle.try(&.call(false))
  end

  private def cal_clamp : Nil
    @cal_day = @cal_day.clamp(1, days_in_month(@cal_year, @cal_month))
  end

  private def do_prev_month : Nil
    @cal_year, @cal_month = prev_month(@cal_year, @cal_month)
  end

  private def do_next_month : Nil
    @cal_year, @cal_month = next_month(@cal_year, @cal_month)
  end

  private def cal_move_left : Nil
    @cal_day -= 1
    if @cal_day < 1; do_prev_month; @cal_day = days_in_month(@cal_year, @cal_month); end
  end

  private def cal_move_right : Nil
    @cal_day += 1
    if @cal_day > days_in_month(@cal_year, @cal_month); do_next_month; @cal_day = 1; end
  end

  private def cal_move_up : Nil
    col = cal_col(@cal_year, @cal_month, @cal_day, @monday_first)
    @cal_day -= 7
    if @cal_day < 1; do_prev_month; @cal_day = cal_last_in_col(col); end
  end

  private def cal_move_down : Nil
    col = cal_col(@cal_year, @cal_month, @cal_day, @monday_first)
    @cal_day += 7
    if @cal_day > days_in_month(@cal_year, @cal_month); do_next_month; @cal_day = cal_first_in_col(col); end
  end

  private def cal_last_in_col(col : Int32) : Int32
    sw = start_wday(@cal_year, @cal_month, @monday_first)
    d = col - sw + 1
    while d < 1; d += 7; end
    while d + 7 <= days_in_month(@cal_year, @cal_month); d += 7; end
    d
  end

  private def cal_first_in_col(col : Int32) : Int32
    d = col - start_wday(@cal_year, @cal_month, @monday_first) + 1
    while d < 1; d += 7; end
    d
  end

  def render(io : IO) : Nil
  end

  def render_screen(screen : Ori::Screen) : Nil
    render_trigger(screen)
  end

  def render_overlay(screen : Ori::Screen) : Nil
    render_calendar(screen) if @open
  end

  private def trigger_text : String
    ds = sprintf("%04d-%02d-%02d", @year, @month, @cursor_day)
    @focused && !@open ? "[#{ds} #{ARROW}]" : "#{ds} #{ARROW}"
  end

  private def render_trigger(screen) : Nil
    r = @rect
    return if r.w <= 0
    fg = @focused ? (@style.border_fg || @style.fg) : @style.fg
    bg = effective_bg
    bfg = @style.border_fg || @style.fg || "#6c7086"

    if has_border?
      screen.put(r.x, r.y, '┌', fg: bfg, bg: bg)
      (r.w - 2).times { |i| screen.put(r.x + 1 + i, r.y, '─', fg: bfg, bg: bg) }
      screen.put(r.x + r.w - 1, r.y, '┐', fg: bfg, bg: bg)

      screen.put(r.x, r.y + 1, '│', fg: bfg, bg: bg)
      text = trigger_text.ljust(r.w - 2)
      cx = r.x + 1
      text.each_char do |ch|
        screen.put(cx, r.y + 1, ch, fg: fg, bg: bg, bold: @focused)
        cx += 1
      end
      screen.put(r.x + r.w - 1, r.y + 1, '│', fg: bfg, bg: bg)

      screen.put(r.x, r.y + 2, '└', fg: bfg, bg: bg)
      (r.w - 2).times { |i| screen.put(r.x + 1 + i, r.y + 2, '─', fg: bfg, bg: bg) }
      screen.put(r.x + r.w - 1, r.y + 2, '┘', fg: bfg, bg: bg)
    else
      text = trigger_text.ljust(r.w)
      cx = r.x
      text.each_char do |ch|
        screen.put(cx, r.y, ch, fg: fg, bg: bg, bold: @focused)
        cx += 1
      end
    end
  end

  private def render_calendar(screen) : Nil
    r = @rect
    iw = 21
    ih = 8
    ow = iw + 2
    oh = ih + 2

    dy = r.y + r.h
    dy = r.y - oh if dy + oh > screen.h
    dy = {dy, 0}.max
    dx = {r.x, screen.w - ow}.min
    dx = {dx, 0}.max

    bg = @style.bg || "#1e1e2e"
    bfg = @style.border_fg || @style.fg || "#6c7086"

    screen.put(dx, dy, '┌', fg: bfg, bg: bg)
    iw.times { |i| screen.put(dx + 1 + i, dy, '─', fg: bfg, bg: bg) }
    screen.put(dx + ow - 1, dy, '┐', fg: bfg, bg: bg)

    ih.times do |row|
      ry = dy + 1 + row
      screen.put(dx, ry, '│', fg: bfg, bg: bg)
      iw.times { |i| screen.put(dx + 1 + i, ry, ' ', bg: bg) }
      screen.put(dx + ow - 1, ry, '│', fg: bfg, bg: bg)
    end

    screen.put(dx, dy + oh - 1, '└', fg: bfg, bg: bg)
    iw.times { |i| screen.put(dx + 1 + i, dy + oh - 1, '─', fg: bfg, bg: bg) }
    screen.put(dx + ow - 1, dy + oh - 1, '┘', fg: bfg, bg: bg)

    ox = dx + 1
    oy = dy + 1
    hfg = @header_fg || @style.fg
    sfg = @selected_fg || bg
    sbg = @selected_bg || (@style.fg || "#cdd6f4")
    tfg = @today_fg || bg
    tbg = @today_bg || "#89b4fa"
    dfg = @day_fg || @style.fg
    omfg = @other_month_fg || "#45475a"

    draw_title(screen, ox, oy, iw, @cal_month, @cal_year, hfg, bg)
    draw_day_names(screen, ox, oy + 1, @monday_first, hfg, bg)
    draw_grid(screen, ox, oy + 2, iw, ih - 2, @cal_year, @cal_month, @cal_day, @monday_first, dfg, bg, sfg, sbg, tfg, tbg, omfg)
  end
end
