class Ori::Checkbox < Ori::Node
  @label : String
  @checked : Bool
  @on_change : Proc(Bool, Nil)?

  def initialize(
    @label : String = "",
    @checked : Bool = false,
    @on_change : Proc(Bool, Nil)? = nil,
    style : Ori::S = Ori::S.none
  )
    super(style)
  end

  getter label : String
  getter checked : Bool
  def checked=(v : Bool)
    @checked = v
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
      @checked = !@checked
      @on_change.try(&.call(@checked))
      true
    else
      false
    end
  end

  def on_mouse(mouse : Ori::Mouse) : Bool
    if mouse.press? && mouse.in?(@rect)
      @checked = !@checked
      @on_change.try(&.call(@checked))
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

    box_char = @checked ? "x" : " "
    label = "[#{box_char}] #{@label}".ljust(r.w)[0, r.w]
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

    box_char = @checked ? "x" : " "
    label = "[#{box_char}] #{@label}".ljust(r.w)[0, r.w]
    lfg = @focused ? sel_fg : fg
    lbg = @focused ? sel_bg : bg
    res = Ori::Color.apply(lfg, label)
    res = Ori::Color.apply_bg(lbg, res)
    res = "\e[1m#{res}" if @focused
    io << Ori::Term.move(r.x, r.y) << res
  end
end
