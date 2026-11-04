class Ori::Radio < Ori::Node
  @label : String
  @selected : Bool
  @on_change : Proc(Bool, Nil)?
  property group_focused : Bool = false

  def initialize(
    @label : String = "",
    @selected : Bool = false,
    @on_change : Proc(Bool, Nil)? = nil,
    style : Ori::S = Ori::S.none
  )
    super(style)
  end

  getter label : String
  getter selected : Bool
  def selected=(v : Bool)
    @selected = v
  end

  def content_height : Int32
    1
  end

  def content_width : Int32
    @label.size + 4
  end

  def focusable? : Bool
    @style.focusable
  end

  def on_key(key : Ori::Key) : Bool
    if key.code.enter? || key.code.space?
      @selected = !@selected
      @on_change.try(&.call(@selected))
      true
    else
      false
    end
  end

  def on_mouse(mouse : Ori::Mouse) : Bool
    if mouse.press? && mouse.in?(@rect)
      @selected = !@selected
      @on_change.try(&.call(@selected))
      true
    else
      false
    end
  end

  def render_screen(screen : Ori::Screen) : Nil
    r = @rect
    return if r.w <= 0
    fg = @style.fg
    bg = effective_bg

    dot = @selected ? "●" : "○"
    label = "#{dot} #{@label}".ljust(r.w)[0, r.w]
    screen.write(r.x, r.y, label, fg: fg, bg: bg, bold: @group_focused)
  end

  def render(io : IO) : Nil
    r = @rect
    return if r.w <= 0
    fg = @style.fg
    bg = effective_bg

    dot = @selected ? "●" : "○"
    label = "#{dot} #{@label}".ljust(r.w)[0, r.w]
    res = Ori::Color.apply(fg, label)
    res = Ori::Color.apply_bg(bg, res)
    res = "\e[1m#{res}" if @group_focused
    io << Ori::Term.move(r.x, r.y) << res
  end
end

class Ori::RadioGroup < Ori::Node
  @buttons : Array(Ori::Radio)
  @selected : Int32
  @on_change : Proc(Int32, Nil)?

  def initialize(
    labels : Array(String) = [] of String,
    selected : Int32 = 0,
    @on_change : Proc(Int32, Nil)? = nil,
    style : Ori::S = Ori::S.none
  )
    super(style)
    @selected = selected
    @buttons = labels.map_with_index do |label, i|
      Ori::Radio.new(label: label, selected: i == selected, style: Ori::S.new(focusable: true))
    end
  end

  getter buttons : Array(Ori::Radio)
  getter selected : Int32

  def content_height : Int32
    @buttons.size
  end

  def content_width : Int32
    (@buttons.map(&.content_width).max || 10)
  end

  def focusable? : Bool
    @style.focusable
  end

  def selected=(idx : Int32)
    idx = idx.clamp(0, @buttons.size - 1)
    @buttons.each_with_index { |b, i| b.selected = i == idx }
    @selected = idx
  end

  def on_key(key : Ori::Key) : Bool
    case key.code
    when .up?
      if @selected > 0; self.selected = @selected - 1; @on_change.try(&.call(@selected)) end
      true
    when .down?
      if @selected < @buttons.size - 1; self.selected = @selected + 1; @on_change.try(&.call(@selected)) end
      true
    when .enter?, .space?
      @on_change.try(&.call(@selected))
      true
    else
      false
    end
  end

  def render_screen(screen : Ori::Screen) : Nil
    r = @rect
    return if r.w <= 0 || r.h <= 0
    r.h.times do |i|
      break if i >= @buttons.size
      ry = r.y + i
      btn = @buttons[i]
      btn.group_focused = @focused && i == @selected
      btn.rect = Ori::Rect.new(r.x, ry, r.w, 1)
      btn.render_screen(screen)
    end
  end

  def render(io : IO) : Nil
    r = @rect
    return if r.w <= 0 || r.h <= 0
    r.h.times do |i|
      break if i >= @buttons.size
      ry = r.y + i
      btn = @buttons[i]
      btn.group_focused = @focused && i == @selected
      btn.rect = Ori::Rect.new(r.x, ry, r.w, 1)
      btn.render(io)
    end
  end
end
