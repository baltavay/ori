class Ori::ProgressBar < Ori::Node
  @value : Float64
  @max : Float64

  def initialize(value = 0.0, @max = 100.0, style : Ori::S = Ori::S.none)
    super(style)
    @value = value.clamp(0.0, @max)
  end

  def value : Float64
    @value
  end

  def value=(v : Float64)
    @value = v.clamp(0.0, @max)
  end

  def max : Float64
    @max
  end

  def max=(m : Float64)
    @max = {m, 1.0}.max
    @value = @value.clamp(0.0, @max)
  end

  def content_height : Int32
    1
  end

  def content_width : Int32
    @style.width || 10
  end

  private def fill_ratio : Float64
    @max > 0 ? (@value / @max).clamp(0.0, 1.0) : 0.0
  end

  def render_screen(screen : Ori::Screen) : Nil
    return if @rect.w <= 0
    w = @rect.w
    fill_f = fill_ratio * w
    case @style.bar_style
    when :gradient then render_gradient_screen(screen, fill_f, w)
    when :blocks   then render_blocks_screen(screen, fill_f, w)
    else                render_solid_screen(screen, fill_f, w)
    end
  end

  private def render_solid_screen(screen : Ori::Screen, fill_f : Float64, w : Int32) : Nil
    full = fill_f.to_i.clamp(0, w)
    frac = ((fill_f - full) * 8).to_i.clamp(0, 7)
    w.times do |i|
      if i < full
        screen.put(@rect.x + i, @rect.y, '█', fg: @style.fg, bg: effective_bg)
      elsif i == full && frac > 0 && full < w
        screen.put(@rect.x + i, @rect.y, '▌', fg: @style.fg, bg: effective_bg)
      else
        screen.put(@rect.x + i, @rect.y, ' ', bg: effective_bg)
      end
    end
  end

  private def render_blocks_screen(screen : Ori::Screen, fill_f : Float64, w : Int32) : Nil
    full = fill_f.to_i.clamp(0, w)
    frac = ((fill_f - full) * 8).to_i.clamp(0, 7)
    w.times do |i|
      if i < full
        screen.put(@rect.x + i, @rect.y, '█', fg: @style.fg, bg: effective_bg)
      elsif i == full && frac > 0 && full < w
        screen.put(@rect.x + i, @rect.y, '▌', fg: @style.fg, bg: effective_bg)
      else
        screen.put(@rect.x + i, @rect.y, '░', fg: @style.fg, bg: effective_bg)
      end
    end
  end

  private def render_gradient_screen(screen : Ori::Screen, fill_f : Float64, w : Int32) : Nil
    total_steps = w * 2
    fill_steps = (fill_f * 2).to_i.clamp(0, total_steps)
    sr, sg, sb = fg_rgb
    er, eg, eb = gradient_end_rgb
    br, bg_c, bb = bg_rgb
    w.times do |i|
      left_step = i * 2
      right_step = left_step + 1
      left_filled = left_step < fill_steps
      right_filled = right_step < fill_steps
      if left_filled && right_filled
        tl = color_at(left_step, total_steps, sr, sg, sb, er, eg, eb)
        tr = color_at(right_step, total_steps, sr, sg, sb, er, eg, eb)
        screen.put(@rect.x + i, @rect.y, '▌', fg: rgb_hex(tl), bg: rgb_hex(tr))
      elsif left_filled
        tl = color_at(left_step, total_steps, sr, sg, sb, er, eg, eb)
        screen.put(@rect.x + i, @rect.y, '▌', fg: rgb_hex(tl), bg: rgb_hex({br, bg_c, bb}))
      else
        screen.put(@rect.x + i, @rect.y, ' ', bg: rgb_hex({br, bg_c, bb}))
      end
    end
  end

  def render(io : IO) : Nil
    return if @rect.w <= 0
    w = @rect.w
    fill_f = fill_ratio * w
    bar = build_bar(fill_f, w)
    unless @style.bar_style == :gradient
      bar = Ori::Color.apply(@style.fg, bar) if @style.fg
    end
    bar = Ori::Color.apply_bg(effective_bg, bar) if effective_bg
    io << Ori::Term.move(@rect.x, @rect.y) << bar
  end

  private def build_bar(fill_f : Float64, w : Int32) : String
    case @style.bar_style
    when :blocks   then build_blocks(fill_f, w)
    when :gradient then build_gradient(fill_f, w)
    else                build_solid(fill_f, w)
    end
  end

  private def build_solid(fill_f : Float64, w : Int32) : String
    full = fill_f.to_i.clamp(0, w)
    frac = ((fill_f - full) * 8).to_i.clamp(0, 7)
    tail = (full < w && frac > 0) ? "▌" : ""
    rest = w - full - (tail.empty? ? 0 : 1)
    "█" * full + tail + " " * {rest, 0}.max
  end

  private def build_blocks(fill_f : Float64, w : Int32) : String
    full = fill_f.to_i.clamp(0, w)
    frac = ((fill_f - full) * 8).to_i.clamp(0, 7)
    tail = (full < w && frac > 0) ? "▌" : ""
    rest = w - full - (tail.empty? ? 0 : 1)
    "█" * full + tail + "░" * {rest, 0}.max
  end

  private def build_gradient(fill_f : Float64, w : Int32) : String
    total_steps = w * 2
    fill_steps = (fill_f * 2).to_i.clamp(0, total_steps)
    sr, sg, sb = fg_rgb
    er, eg, eb = gradient_end_rgb
    br, bg_c, bb = bg_rgb
    buf = IO::Memory.new
    w.times do |i|
      left_step = i * 2
      right_step = left_step + 1
      left_filled = left_step < fill_steps
      right_filled = right_step < fill_steps
      if left_filled && right_filled
        tl = color_at(left_step, total_steps, sr, sg, sb, er, eg, eb)
        tr = color_at(right_step, total_steps, sr, sg, sb, er, eg, eb)
        buf << "\e[38;2;#{tl[0]};#{tl[1]};#{tl[2]};48;2;#{tr[0]};#{tr[1]};#{tr[2]}m▌"
      elsif left_filled
        tl = color_at(left_step, total_steps, sr, sg, sb, er, eg, eb)
        buf << "\e[38;2;#{tl[0]};#{tl[1]};#{tl[2]};48;2;#{br};#{bg_c};#{bb}m▌"
      else
        buf << "\e[38;2;#{br};#{bg_c};#{bb};48;2;#{br};#{bg_c};#{bb}m▌"
      end
    end
    buf << "\e[0m"
    buf.to_s
  end

  private def rgb_hex(rgb : {Int32, Int32, Int32}) : String
    "#%02x%02x%02x" % {rgb[0], rgb[1], rgb[2]}
  end

  private def color_at(step : Int32, total : Int32, sr : Int32, sg : Int32, sb : Int32, er : Int32, eg : Int32, eb : Int32) : {Int32, Int32, Int32}
    t = total > 1 ? step.to_f / (total - 1) : 0.0
    {(sr + (er - sr) * t).to_i, (sg + (eg - sg) * t).to_i, (sb + (eb - sb) * t).to_i}
  end

  private def fg_rgb : {Int32, Int32, Int32}
    if fg = @style.fg
      Ori::Color.hex_rgb(fg)
    else
      {255, 255, 255}
    end
  end

  private def gradient_end_rgb : {Int32, Int32, Int32}
    if to = @style.gradient_to
      Ori::Color.hex_rgb(to)
    else
      {20, 20, 30}
    end
  end

  private def bg_rgb : {Int32, Int32, Int32}
    if bg = effective_bg
      Ori::Color.hex_rgb(bg)
    else
      {30, 30, 46}
    end
  end

end
