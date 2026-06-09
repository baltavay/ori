class Ori::Radio < Ori::Node
  @label : String
  @selected : Bool
  @on_change : Proc(Bool, Nil)?

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
    sel_fg = "#1e1e2e"
    sel_bg = "#cba6f7"

    dot = @selected ? "●" : "○"
    label = "#{dot} #{@label}".ljust(r.w)[0, r.w]
    lfg = @focused ? sel_fg : fg
    lbg = @focused ? sel_bg : bg
    screen.write(r.x, r.y, label, fg: lfg, bg: lbg, bold: @focused)
  end

  def render(io : IO) : Nil
    r = @rect
    return if r.w <= 0
    fg = @style.fg
    bg = effective_bg
    sel_fg = "#1e1e2e"
    sel_bg = "#cba6f7"

    dot = @selected ? "●" : "○"
    label = "#{dot} #{@label}".ljust(r.w)[0, r.w]
    lfg = @focused ? sel_fg : fg
    lbg = @focused ? sel_bg : bg
    res = Ori::Color.apply(lfg, label)
    res = Ori::Color.apply_bg(lbg, res)
    res = "\e[1m#{res}" if @focused
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
    false
  end

  def selected=(idx : Int32)
    idx = idx.clamp(0, @buttons.size - 1)
    @buttons.each_with_index { |b, i| b.selected = i == idx }
    @selected = idx
  end

  def render_screen(screen : Ori::Screen) : Nil
    r = @rect
    return if r.w <= 0 || r.h <= 0
    r.h.times do |i|
      break if i >= @buttons.size
      ry = r.y + i
      btn = @buttons[i]
      btn.rect = Ori::Rect.new(r.x, ry, r.w, 1)
      btn.render_screen(screen)
    end
  end

  def render(io : IO) : Nil
  end
end
