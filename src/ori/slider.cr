class Ori::Slider < Ori::Node
  @min : Float64
  @max : Float64
  @value : Float64
  @step : Float64
  @on_change : Proc(Float64, Nil)?

  def initialize(
    @min : Float64 = 0.0,
    @max : Float64 = 100.0,
    value : Float64 = 0.0,
    @step : Float64 = 1.0,
    @on_change : Proc(Float64, Nil)? = nil,
    style : Ori::S = Ori::S.none
  )
    super(style)
    @value = value.clamp(@min, @max)
  end

  getter min : Float64
  getter max : Float64
  getter value : Float64
  getter step : Float64

  def value=(v : Float64)
    @value = v.clamp(@min, @max)
  end

  def content_height : Int32
    1
  end

  def content_width : Int32
    15
  end

  def focusable? : Bool
    @style.focusable
  end

  def on_key(key : Ori::Key) : Bool
    case
    when key.code.right? || key.text == "l"
      @value = {@value + @step, @max}.min
      @on_change.try(&.call(@value))
      true
    when key.code.left? || key.text == "h"
      @value = {@value - @step, @min}.max
      @on_change.try(&.call(@value))
      true
    when key.code.home? || key.text == "g"
      @value = @min
      @on_change.try(&.call(@value))
      true
    when key.code.end? || key.text == "G"
      @value = @max
      @on_change.try(&.call(@value))
      true
    else
      false
    end
  end

  def render_screen(screen : Ori::Screen) : Nil
    r = @rect
    return if r.w <= 0

    fg = @style.fg || "#cdd6f4"
    bg = effective_bg
    track_bg = "#45475a"
    fill_fg = @focused ? "#cba6f7" : "#89b4fa"

    track_w = r.w - 4
    return if track_w <= 0

    pct = @max > @min ? ((@value - @min) / (@max - @min)).clamp(0.0, 1.0) : 0.0
    fill = (pct * track_w).round.to_i

    screen.put(r.x, r.y, '[', fg: fg, bg: bg)
    track_w.times do |i|
      if i < fill
        is_handle = i == fill - 1
        ch = is_handle ? (r.w > 10 ? '█' : '|') : '─'
        screen.put(r.x + 1 + i, r.y, ch, fg: fill_fg, bg: track_bg)
      else
        is_handle = i == fill
        ch = is_handle ? (r.w > 10 ? '█' : '|') : '─'
        screen.put(r.x + 1 + i, r.y, ch, fg: is_handle ? fill_fg : fg, bg: track_bg)
      end
    end
    screen.put(r.x + 1 + track_w, r.y, ']', fg: fg, bg: bg)
  end

  def render(io : IO) : Nil
    r = @rect
    return if r.w <= 0

    fg = @style.fg
    fill_fg = @focused ? "#cba6f7" : "#89b4fa"

    track_w = r.w - 4
    return if track_w <= 0

    pct = @max > @min ? ((@value - @min) / (@max - @min)).clamp(0.0, 1.0) : 0.0
    fill = (pct * track_w).round.to_i

    bar = String.build do |s|
      s << '['
      track_w.times do |i|
        ch = i == fill ? '█' : (i < fill ? '─' : '─')
        s << ch
      end
      s << ']'
    end
    bar = Ori::Color.apply(fg, bar) if fg
    io << Ori::Term.move(r.x, r.y) << bar
  end
end
