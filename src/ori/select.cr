class Ori::Select < Ori::Node
  ARROW = "▾"

  @options : Array(String)
  @selected : Int32
  @highlighted : Int32
  @open : Bool
  @scroll_offset : Int32
  @on_change : Proc(Int32, Nil)?
  @on_toggle : Proc(Bool, Nil)?
  @on_highlight : Proc(Int32, Nil)?
  @max_visible : Int32
  @highlight_fg : String?
  @highlight_bg : String?

  def initialize(
    @options : Array(String) = [] of String,
    selected : Int32 = 0,
    highlighted : Int32 = -1,
    @open : Bool = false,
    @on_change : Proc(Int32, Nil)? = nil,
    @on_toggle : Proc(Bool, Nil)? = nil,
    @on_highlight : Proc(Int32, Nil)? = nil,
    @max_visible : Int32 = 8,
    @highlight_fg : String? = nil,
    @highlight_bg : String? = nil,
    style : Ori::S = Ori::S.none
  )
    super(style)
    @selected = selected
    @highlighted = highlighted < 0 ? selected : highlighted
    @scroll_offset = 0
  end

  getter options : Array(String)
  getter selected : Int32
  getter highlighted : Int32
  getter open : Bool

  def selected=(idx : Int32) : Nil
    @selected = idx.clamp(0, {@options.size - 1, 0}.max)
  end

  def selected_value : String?
    @options[@selected]?
  end

  def content_height : Int32
    1
  end

  def content_width : Int32
    return 5 if @options.empty?
    max_opt = @options.map(&.size).max? || 0
    max_opt + ARROW.size + 1 + 2 # option + space + arrow + brackets
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

  def on_mouse(mouse : Ori::Mouse) : Bool
    if @open
      handle_open_mouse(mouse)
    else
      if mouse.press? && mouse.in?(@rect)
        unless @options.empty?
          @open = true
          @highlighted = @selected
          @scroll_offset = 0
          adjust_scroll
          @on_toggle.try(&.call(true))
          @on_highlight.try(&.call(@highlighted))
        end
        true
      else
        false
      end
    end
  end

  private def handle_open_mouse(mouse : Ori::Mouse) : Bool
    r = @rect
    sh = screen_height
    dw = dropdown_width
    inner_w = dw - 2
    num_vis = {@options.size, @max_visible}.min

    dy = r.y + 1
    if dy + num_vis + 2 > sh
      dy = r.y - num_vis - 2
    end
    dy = {dy, 0}.max

    case mouse.action
    when Ori::Mouse::Action::Press
      if mouse.y == dy || mouse.y == dy + num_vis + 1
        @open = false
        @on_toggle.try(&.call(false))
        true
      elsif mouse.y > dy && mouse.y <= dy + num_vis
        row = mouse.y - dy - 1 + @scroll_offset
        if row >= 0 && row < @options.size
          @highlighted = row
          @selected = @highlighted
          @open = false
          @on_change.try(&.call(@selected))
          @on_toggle.try(&.call(false))
        end
        true
      else
        @open = false
        @on_toggle.try(&.call(false))
        true
      end
    when Ori::Mouse::Action::Wheel
      if mouse.button.wheel_up? && @highlighted > 0
        @highlighted -= 1
        adjust_scroll
        @on_highlight.try(&.call(@highlighted))
      elsif mouse.button.wheel_down? && @highlighted < @options.size - 1
        @highlighted += 1
        adjust_scroll
        @on_highlight.try(&.call(@highlighted))
      end
      true
    else
      true
    end
  end

  private def screen_height : Int32
    _, h = Ori::Term.window_size
    h
  end

  private def handle_open_key(key : Ori::Key) : Bool
    case
    when key.code.up? || key.text == "k"
      if @highlighted > 0
        @highlighted -= 1
        adjust_scroll
        @on_highlight.try(&.call(@highlighted))
      end
      true
    when key.code.down? || key.text == "j"
      if @highlighted < @options.size - 1
        @highlighted += 1
        adjust_scroll
        @on_highlight.try(&.call(@highlighted))
      end
      true
    when key.code.enter?
      @selected = @highlighted
      @open = false
      @on_change.try(&.call(@selected))
      @on_toggle.try(&.call(false))
      true
    when key.code.escape?
      @open = false
      @on_toggle.try(&.call(false))
      true
    else
      true
    end
  end

  private def handle_closed_key(key : Ori::Key) : Bool
    case
    when key.code.enter? || key.code.space?
      unless @options.empty?
        @open = true
        @highlighted = @selected
        @scroll_offset = 0
        adjust_scroll
        @on_toggle.try(&.call(true))
        @on_highlight.try(&.call(@highlighted))
      end
      true
    when key.code.up?
      if @selected > 0
        @selected -= 1
        @on_change.try(&.call(@selected))
      end
      true
    when key.code.down?
      if @selected < @options.size - 1
        @selected += 1
        @on_change.try(&.call(@selected))
      end
      true
    else
      false
    end
  end

  def render(io : IO) : Nil
    r = @rect
    return if r.w <= 0

    fg = @focused ? (@style.border_fg || @style.fg) : @style.fg
    bg = effective_bg
    text = trigger_text.ljust(r.w)
    io << Ori::Term.move(r.x, r.y) << Ori::Color.paint(text, fg, bg, @focused)

    render_dropdown_io(io) if @open
  end

  def render_screen(screen : Ori::Screen) : Nil
    render_trigger_screen(screen)
  end

  def render_overlay(screen : Ori::Screen) : Nil
    render_dropdown_screen(screen) if @open
  end

  private def trigger_text : String
    opt = @options[@selected]? || ""
    if @focused && !@open
      "[#{opt} #{ARROW}]"
    else
      "#{opt} #{ARROW}"
    end
  end

  private def render_trigger_screen(screen)
    r = @rect
    return if r.w <= 0

    fg = @focused ? (@style.border_fg || @style.fg) : @style.fg
    bg = effective_bg
    text = trigger_text.ljust(r.w)
    cx = r.x
    text.each_char do |ch|
      screen.put(cx, r.y, ch, fg: fg, bg: bg, bold: @focused)
      cx += 1
    end
  end

  private def dropdown_width : Int32
    max_opt = @options.map(&.size).max? || 0
    inner = max_opt + 4
    total = inner + 2
    {total, @rect.w}.max
  end

  private def render_dropdown_screen(screen)
    return if @options.empty?

    r = @rect
    sh = screen.h
    dw = dropdown_width
    inner_w = dw - 2
    num_vis = {@options.size, @max_visible}.min

    dy = r.y + 1
    if dy + num_vis + 2 > sh
      dy = r.y - num_vis - 2
    end
    dy = {dy, 0}.max

    dx = {r.x, screen.w - dw}.min
    dx = {dx, 0}.max

    bg = @style.bg || "#1e1e2e"
    bfg = @style.border_fg || @style.fg || "#6c7086"
    fg = @style.fg
    hl_fg = @highlight_fg || bg
    hl_bg = @highlight_bg || (@style.fg || "#cdd6f4")

    screen.put(dx, dy, '┌', fg: bfg, bg: bg)
    inner_w.times { |i| screen.put(dx + 1 + i, dy, '─', fg: bfg, bg: bg) }
    screen.put(dx + inner_w + 1, dy, '┐', fg: bfg, bg: bg)

    adjust_scroll_for(num_vis)
    row_i = 0
    @scroll_offset.upto(@scroll_offset + num_vis - 1) do |i|
      break if i >= @options.size
      opt = @options[i]
      is_hl = i == @highlighted
      oy = dy + 1 + row_i

      c_fg = is_hl ? hl_fg : fg
      c_bg = is_hl ? hl_bg : bg

      screen.put(dx, oy, '│', fg: bfg, bg: bg)
      screen.put(dx + 1, oy, ' ', fg: fg, bg: c_bg)
      padded = opt.ljust(inner_w - 2)
      padded.each_char_with_index do |ch, ci|
        screen.put(dx + 2 + ci, oy, ch, fg: c_fg, bg: c_bg, bold: is_hl)
      end
      screen.put(dx + inner_w, oy, ' ', fg: fg, bg: c_bg)
      screen.put(dx + inner_w + 1, oy, '│', fg: bfg, bg: bg)
      row_i += 1
    end

    while row_i < num_vis
      oy = dy + 1 + row_i
      screen.put(dx, oy, '│', fg: bfg, bg: bg)
      inner_w.times { |ci| screen.put(dx + 1 + ci, oy, ' ', bg: bg) }
      screen.put(dx + inner_w + 1, oy, '│', fg: bfg, bg: bg)
      row_i += 1
    end

    by = dy + num_vis + 1
    screen.put(dx, by, '└', fg: bfg, bg: bg)
    inner_w.times { |i| screen.put(dx + 1 + i, by, '─', fg: bfg, bg: bg) }
    screen.put(dx + inner_w + 1, by, '┘', fg: bfg, bg: bg)
  end

  private def render_dropdown_io(io)
    return if @options.empty?

    r = @rect
    dw = dropdown_width
    inner_w = dw - 2
    num_vis = {@options.size, @max_visible}.min

    _, term_h = Ori::Term.window_size
    dy = r.y + 1
    if dy + num_vis + 2 > term_h
      dy = r.y - num_vis - 2
    end
    dy = {dy, 0}.max
    dx = r.x

    bg = @style.bg || "#1e1e2e"
    bfg = @style.border_fg || @style.fg || "#6c7086"
    fg = @style.fg
    hl_fg = @highlight_fg || bg
    hl_bg = @highlight_bg || (@style.fg || "#cdd6f4")

    io << Ori::Term.move(dx, dy) << Ori::Color.paint("┌#{"─" * inner_w}┐", bfg, bg)

    adjust_scroll_for(num_vis)
    row_i = 0
    @scroll_offset.upto(@scroll_offset + num_vis - 1) do |i|
      break if i >= @options.size
      opt = @options[i]
      is_hl = i == @highlighted
      oy = dy + 1 + row_i

      c_fg = is_hl ? hl_fg : fg
      c_bg = is_hl ? hl_bg : bg

      io << Ori::Term.move(dx, oy) << Ori::Color.paint("│", bfg, is_hl ? hl_bg : bg)
      io << Ori::Color.paint(opt.ljust(inner_w), c_fg, c_bg, is_hl)
      io << Ori::Color.paint("│", bfg, is_hl ? hl_bg : bg)
      row_i += 1
    end

    while row_i < num_vis
      oy = dy + 1 + row_i
      io << Ori::Term.move(dx, oy) << Ori::Color.paint("│#{" " * inner_w}│", bfg, bg)
      row_i += 1
    end

    by = dy + num_vis + 1
    io << Ori::Term.move(dx, by) << Ori::Color.paint("└#{"─" * inner_w}┘", bfg, bg)
  end

  private def adjust_scroll : Nil
    num_vis = {@options.size, @max_visible}.min
    if @highlighted < @scroll_offset
      @scroll_offset = @highlighted
    elsif @highlighted >= @scroll_offset + num_vis
      @scroll_offset = @highlighted - num_vis + 1
    end
    @scroll_offset = {@scroll_offset, 0}.max
  end

  private def adjust_scroll_for(num_vis : Int32) : Nil
    if @highlighted < @scroll_offset
      @scroll_offset = @highlighted
    elsif @highlighted >= @scroll_offset + num_vis
      @scroll_offset = @highlighted - num_vis + 1
    end
    @scroll_offset = {@scroll_offset, 0}.max
  end

end
