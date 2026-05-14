module Ori::CalendarHelper
  MONTH_NAMES = {
    1  => "January", 2  => "February", 3  => "March",
    4  => "April",   5  => "May",      6  => "June",
    7  => "July",    8  => "August",    9  => "September",
    10 => "October", 11 => "November", 12 => "December",
  }
  DAY_NAMES_SUN = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
  DAY_NAMES_MON = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

  def days_in_month(y : Int32, m : Int32) : Int32
    ny = m == 12 ? y + 1 : y
    nm = m == 12 ? 1 : m + 1
    (Time.utc(ny, nm, 1) - Time.utc(y, m, 1)).days.to_i
  end

  def prev_month_dim(y : Int32, m : Int32) : Int32
    pm = m == 1 ? 12 : m - 1
    py = m == 1 ? y - 1 : y
    days_in_month(py, pm)
  end

  def start_wday(y : Int32, m : Int32, monday_first : Bool) : Int32
    w = Time.utc(y, m, 1).day_of_week.value % 7
    monday_first ? (w + 6) % 7 : w
  end

  def prev_month(y : Int32, m : Int32) : {Int32, Int32}
    m == 1 ? {y - 1, 12} : {y, m - 1}
  end

  def next_month(y : Int32, m : Int32) : {Int32, Int32}
    m == 12 ? {y + 1, 1} : {y, m + 1}
  end

  def cal_col(y : Int32, m : Int32, day : Int32, monday_first : Bool) : Int32
    (start_wday(y, m, monday_first) + day - 1) % 7
  end

  def draw_title(screen : Ori::Screen, x : Int32, y : Int32, w : Int32, month : Int32, year : Int32, fg : String?, bg : String?) : Nil
    title = "#{MONTH_NAMES[month]} #{year}"
    pad = (w - title.size) // 2
    cx = x
    pad.times { screen.put(cx, y, ' ', fg: fg, bg: bg); cx += 1 }
    title.each_char { |ch| screen.put(cx, y, ch, fg: fg, bg: bg, bold: true); cx += 1 }
    while cx < x + w; screen.put(cx, y, ' ', fg: fg, bg: bg); cx += 1; end
  end

  def draw_day_names(screen : Ori::Screen, x : Int32, y : Int32, monday_first : Bool, fg : String?, bg : String?) : Nil
    names = monday_first ? DAY_NAMES_MON : DAY_NAMES_SUN
    cx = x
    7.times do |col|
      n = names[col]
      screen.put(cx, y, n[0], fg: fg, bg: bg, bold: true); cx += 1
      screen.put(cx, y, n[1], fg: fg, bg: bg, bold: true); cx += 1
      screen.put(cx, y, ' ', fg: fg, bg: bg); cx += 1
    end
  end

  def draw_grid(screen : Ori::Screen, x : Int32, y : Int32, w : Int32, h : Int32,
                cal_year : Int32, cal_month : Int32, cal_day : Int32,
                monday_first : Bool, dfg : String?, bg : String?,
                sfg : String?, sbg : String?, tfg : String?, tbg : String?, omfg : String?) : Nil
    now = Time.utc
    sw = start_wday(cal_year, cal_month, monday_first)
    cdim = days_in_month(cal_year, cal_month)
    pdim = prev_month_dim(cal_year, cal_month)
    offset = sw
    day = 1

    6.times do |wi|
      ry = y + wi
      break if ry >= y + h
      cx = x
      7.times do |col|
        break if cx + 3 > x + w
        if offset > 0
          pd = pdim - offset + 1
          dt = pd.to_s.rjust(2)
          screen.put(cx, ry, dt[0], fg: omfg, bg: bg)
          screen.put(cx + 1, ry, dt[1], fg: omfg, bg: bg)
          screen.put(cx + 2, ry, ' ', fg: omfg, bg: bg)
          offset -= 1
        elsif day <= cdim
          is_today = now.year == cal_year && now.month == cal_month && now.day == day
          is_sel = day == cal_day
          if is_today && is_sel; c_fg, c_bg = sbg, tbg
          elsif is_sel; c_fg, c_bg = sfg, sbg
          elsif is_today; c_fg, c_bg = tfg, tbg
          else; c_fg, c_bg = dfg, bg
          end
          dt = day.to_s.rjust(2)
          screen.put(cx, ry, dt[0], fg: c_fg, bg: c_bg, bold: is_sel)
          screen.put(cx + 1, ry, dt[1], fg: c_fg, bg: c_bg, bold: is_sel)
          screen.put(cx + 2, ry, ' ', fg: c_fg, bg: c_bg)
          day += 1
        else
          nd = day - cdim
          dt = nd.to_s.rjust(2)
          screen.put(cx, ry, dt[0], fg: omfg, bg: bg)
          screen.put(cx + 1, ry, dt[1], fg: omfg, bg: bg)
          screen.put(cx + 2, ry, ' ', fg: omfg, bg: bg)
          day += 1
        end
        cx += 3
      end
    end
  end
end
