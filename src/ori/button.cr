class Ori::Button < Ori::Node
  @label : String
  @on_press : Proc(Nil)?
  @variant : Symbol

  def initialize(
    @label : String = "Button",
    @variant : Symbol = :default,
    @on_press : Proc(Nil)? = nil,
    style : Ori::S = Ori::S.none
  )
    super(style)
  end

  getter label : String

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
      @on_press.try(&.call)
      true
    else
      false
    end
  end

  def on_mouse(mouse : Ori::Mouse) : Bool
    if mouse.press? && mouse.in?(@rect)
      @on_press.try(&.call)
      true
    else
      false
    end
  end

  def render_screen(screen : Ori::Screen) : Nil
    r = @rect
    return if r.w <= 0

    bg = effective_bg
    colors = variant_colors
    fg = @focused ? colors[:active_fg] : colors[:fg]
    btn_bg = @focused ? colors[:active_bg] : colors[:bg]

    label = " #{@label} ".center(r.w)[0, r.w]
    screen.write(r.x, r.y, label, fg: fg, bg: btn_bg, bold: @focused)
  end

  def render(io : IO) : Nil
    r = @rect
    return if r.w <= 0

    colors = variant_colors
    fg = @focused ? colors[:active_fg] : colors[:fg]
    btn_bg = @focused ? colors[:active_bg] : colors[:bg]

    label = " #{@label} ".center(r.w)[0, r.w]
    res = Ori::Color.apply(fg, label)
    res = Ori::Color.apply_bg(btn_bg, res)
    res = "\e[1m#{res}" if @focused
    io << Ori::Term.move(r.x, r.y) << res
  end

  private def variant_colors
    case @variant
    when :primary
      {fg: "#cdd6f4", bg: "#89b4fa", active_fg: "#1e1e2e", active_bg: "#b4d0fb"}
    when :success
      {fg: "#cdd6f4", bg: "#a6e3a1", active_fg: "#1e1e2e", active_bg: "#b8ebc3"}
    when :danger
      {fg: "#cdd6f4", bg: "#f38ba8", active_fg: "#1e1e2e", active_bg: "#f5a9be"}
    else
      {fg: "#cdd6f4", bg: "#45475a", active_fg: "#1e1e2e", active_bg: "#cba6f7"}
    end
  end
end
