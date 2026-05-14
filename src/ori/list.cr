class Ori::List < Ori::Node
  struct Item
    getter label : String
    getter data : String?

    def initialize(@label : String, @data : String? = nil)
    end
  end

  @items : Array(Item)
  @cursor : Int32
  @scroll_offset : Int32
  @on_select : Proc(Int32, Nil)?
  @on_change : Proc(Int32, Nil)?
  @selected_fg : String?
  @selected_bg : String?
  @selected_prefix : String
  @normal_prefix : String
  @truncate : Int32
  @checkable : Bool
  @checked : Array(Bool)

  def initialize(
    @items : Array(Item) = [] of Item,
    selected : Int32 = 0,
    checked : Array(Bool) = [] of Bool,
    @on_select : Proc(Int32, Nil)? = nil,
    @on_change : Proc(Int32, Nil)? = nil,
    @selected_fg : String? = nil,
    @selected_bg : String? = nil,
    @selected_prefix : String = "▌ ",
    @normal_prefix : String = "  ",
    @truncate : Int32 = 0,
    @checkable : Bool = false,
    style : Ori::S = Ori::S.none
  )
    super(style)
    @cursor = selected.clamp(0, {@items.size - 1, 0}.max)
    @scroll_offset = 0
    @checked = checked.size == @items.size ? checked : Array(Bool).new(@items.size, false)
  end

  getter items : Array(Item)
  getter cursor : Int32
  getter checked : Array(Bool)

  def index : Int32
    @cursor
  end

  def selected : Item?
    @items[@cursor]?
  end

  def items=(items : Array(Item)) : Nil
    @items = items
    @checked = Array(Bool).new(items.size, false)
    @cursor = @cursor.clamp(0, {@items.size - 1, 0}.max)
    @scroll_offset = 0
  end

  def checked=(idx : Int32) : Nil
    return unless idx >= 0 && idx < @checked.size
    @checked[idx] = !@checked[idx]
  end

  def checked?(idx : Int32) : Bool
    @checked[idx]? || false
  end

  def select(idx : Int32) : Nil
    return if @items.empty?
    @cursor = idx.clamp(0, @items.size - 1)
  end

  def content_height : Int32
    {@items.size, 1}.max
  end

  def content_width : Int32
    return 4 if @items.empty?
    max_label = @items.map(&.label.size).max
    prefix_w = {@selected_prefix.size, @normal_prefix.size}.max
    check_w = @checkable ? 2 : 0
    max_label + prefix_w + check_w
  end

  def focusable? : Bool
    @style.focusable
  end

  def on_key(key : Ori::Key) : Bool
    old = @cursor
    handled = case
      when key.code.up? || key.text == "k"
        @cursor -= 1 if @cursor > 0; true
      when key.code.down? || key.text == "j"
        @cursor += 1 if @cursor < @items.size - 1; true
      when key.code.home? || key.text == "g"
        @cursor = 0; true
      when key.code.end? || key.text == "G"
        @cursor = {@items.size - 1, 0}.max; true
      when key.code.pg_up? || key.text == "b"
        @cursor = {@cursor - vis_count, 0}.max; true
      when key.code.pg_down? || key.text == "f"
        @cursor = {@cursor + vis_count, @items.size - 1}.min; true
      when key.code.enter?
        @on_select.try(&.call(@cursor)); true
      else
        false
      end
    adjust_scroll if handled && @cursor != old
    @on_change.try(&.call(@cursor)) if handled && @cursor != old
    handled
  end

  def on_mouse(mouse : Ori::Mouse) : Bool
    return false unless mouse.in?(@rect)
    r = @rect
    case mouse.action
    when Ori::Mouse::Action::Wheel
      if mouse.button.wheel_up?
        @cursor = {@cursor - 3, 0}.max
      elsif mouse.button.wheel_down?
        @cursor = {@cursor + 3, @items.size - 1}.min
      end
      adjust_scroll
      @on_change.try(&.call(@cursor))
      true
    when Ori::Mouse::Action::Press
      row = mouse.y - r.y + @scroll_offset
      if row >= 0 && row < @items.size
        @cursor = row
        adjust_scroll
        @on_change.try(&.call(@cursor))
        if mouse.left? || mouse.middle?
          @on_select.try(&.call(@cursor))
        end
      end
      true
    else
      true
    end
  end

  def render(io : IO) : Nil
    r = @rect
    return if r.w <= 0 || r.h <= 0
    adjust_scroll
    vc = vis_count
    start = @scroll_offset
    stop = {start + vc, @items.size}.min

    start.upto(stop - 1) do |i|
      item = @items[i]?
      next unless item
      sel = i == @cursor && @focused
      row_y = r.y + (i - start)
      prefix = sel ? @selected_prefix : @normal_prefix
      label = item.label
      label = label[0...(@truncate)] + "…" if @truncate > 0 && label.size > @truncate
      fg = sel ? (@selected_fg || @style.fg) : @style.fg
      bg = sel ? (@selected_bg || effective_bg) : effective_bg
      line = prefix
      if @checkable
        line += checked?(i) ? "✓ " : "○ "
      end
      line += label
      line = line.ljust(r.w)
      io << Ori::Term.move(r.x, row_y)
      io << Ori::Color.paint(line, fg, bg, sel)
    end
  end

  def render_screen(screen : Ori::Screen) : Nil
    r = @rect
    return if r.w <= 0 || r.h <= 0
    adjust_scroll
    vc = vis_count
    start = @scroll_offset
    stop = {start + vc, @items.size}.min

    start.upto(stop - 1) do |i|
      item = @items[i]?
      next unless item
      sel = i == @cursor && @focused
      row_y = r.y + (i - start)
      prefix = sel ? @selected_prefix : @normal_prefix
      label = item.label
      label = label[0...(@truncate)] + "…" if @truncate > 0 && label.size > @truncate
      fg = sel ? (@selected_fg || @style.fg) : @style.fg
      bg = sel ? (@selected_bg || effective_bg) : effective_bg

      cx = r.x
      prefix.each_char do |ch|
        screen.put(cx, row_y, ch, fg: fg, bg: bg, bold: sel)
        cx += 1
      end
      if @checkable
        check = checked?(i) ? "✓ " : "○ "
        check.each_char do |ch|
          screen.put(cx, row_y, ch, fg: fg, bg: bg, bold: sel)
          cx += 1
        end
      end
      label.each_char do |ch|
        break if cx >= r.x + r.w
        screen.put(cx, row_y, ch, fg: fg, bg: bg, bold: sel)
        cx += 1
      end
      while cx < r.x + r.w
        screen.put(cx, row_y, ' ', fg: fg, bg: bg)
        cx += 1
      end
    end

    if @items.size > vc
      draw_scrollbar(screen, vc, start)
    end
  end

  private def draw_scrollbar(screen : Ori::Screen, vc : Int32, start : Int32) : Nil
    r = @rect
    return if r.w <= 0 || r.h <= 0
    total = @items.size
    track_h = {vc, r.h}.min
    sb_x = r.x + r.w - 1

    if total <= track_h
      return
    end

    thumb_h = {({track_h * track_h // total, 1}.max), track_h}.min
    thumb_pos = track_h > thumb_h ? (start * (track_h - thumb_h) // {total - track_h, 1}.max) : 0

    (0...track_h).each do |i|
      if i >= thumb_pos && i < thumb_pos + thumb_h
        screen.put(sb_x, r.y + i, '▐', fg: "#6c7086", bg: effective_bg)
      else
        screen.put(sb_x, r.y + i, '░', fg: "#3c3c3c", bg: effective_bg, dim: true)
      end
    end
  end

  private def vis_count : Int32
    r = @rect
    bs = @style.border_size
    {r.h - @style.vpadding - bs * 2, 0}.max
  end

  private def adjust_scroll : Nil
    vc = vis_count
    return if vc <= 0
    if @cursor < @scroll_offset
      @scroll_offset = @cursor
    elsif @cursor >= @scroll_offset + vc
      @scroll_offset = @cursor - vc + 1
    end
    max_off = {@items.size - vc, 0}.max
    @scroll_offset = @scroll_offset.clamp(0, max_off)
  end

end
