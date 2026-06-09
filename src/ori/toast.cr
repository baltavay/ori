class Ori::Toast < Ori::Node
  @message : String
  @variant : Symbol

  def initialize(
    @message : String = "",
    @variant : Symbol = :info,
    style : Ori::S = Ori::S.none
  )
    super(style)
  end

  getter message : String
  getter variant : Symbol

  def message=(msg : String)
    @message = msg
  end

  def content_height : Int32
    1
  end

  def content_width : Int32
    @message.size + 4
  end

  def focusable? : Bool
    false
  end

  def render_screen(screen : Ori::Screen) : Nil
    r = @rect
    return if r.w <= 0

    fg, bg = variant_colors
    label = " #{@message} ".center(r.w)[0, r.w]
    screen.write(r.x, r.y, label, fg: fg, bg: bg, bold: true)
  end

  def render(io : IO) : Nil
    r = @rect
    return if r.w <= 0

    fg, bg = variant_colors
    label = " #{@message} ".center(r.w)[0, r.w]
    res = Ori::Color.apply(fg, label)
    res = Ori::Color.apply_bg(bg, res)
    io << Ori::Term.move(r.x, r.y) << res
  end

  private def variant_colors : {String, String}
    case @variant
    when :success then {"#1e1e2e", "#a6e3a1"}
    when :warning then {"#1e1e2e", "#f9e2af"}
    when :error   then {"#cdd6f4", "#f38ba8"}
    else               {"#cdd6f4", "#45475a"}
    end
  end
end
