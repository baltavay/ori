require "../src/ori"

# A day passing over a tree, drawn on a sub-cell canvas.
#
# The sky is a per-pixel gradient: every row mixes a zenith and a horizon colour,
# and both are keyframed by the time of day — night, dawn, noon, dusk, night.
# Over it the sun (or the moon) is a soft halo around a softly edged disc, stars
# fade in where the sky is dark, and the ground carries a shadow that stretches
# away from the light and shortens as the light climbs.
#
# Nothing here flips a cell from one colour to another: the sky, the halo, the
# shadow and the stars are continuous fields, so a step of time only nudges
# colours. The tree never moves, so its geometry is rasterized once per size into
# a pixel list and only its lighting is recomputed each frame.
#
#     q / ctrl+c: quit        TREE_PERIOD=<seconds>: length of one day
private PX = 2 # canvas pixels per cell

# Seconds for one full day/night cycle.
private PERIOD = (ENV["TREE_PERIOD"]? || "75").to_f

# Frame budget in milliseconds; the input read sleeps whatever is left of it.
private FRAME_MS = 1000.0 / 60.0

private SUN_CORE  = 0xfff6d0_u32
private SUN_GLOW  = 0xffa94f_u32
private MOON_CORE = 0xeaf0ff_u32
private MOON_GLOW = 0x93a6ff_u32
private STAR      = 0xdbe4ff_u32
private GROUND_HI = 0x40502f_u32
private GROUND_LO = 0x121a10_u32
private SHADOW    = 0x080b06_u32
private LEAF_DARK = 0x1d3524_u32
private LEAF_LIT  = 0x8ccc6c_u32
private BARK_DARK = 0x22180f_u32
private BARK_LIT  = 0x7a5433_u32

# Zenith and horizon colours keyed by the time of day, 0 = midnight.
private record SkyKey, at : Float64, zenith : UInt32, horizon : UInt32

private SKY = [
  SkyKey.new(0.00, 0x050812, 0x0d1428),
  SkyKey.new(0.10, 0x0a1130, 0x2a1c44),
  SkyKey.new(0.20, 0x1d2c60, 0xb0607a),
  SkyKey.new(0.28, 0x2f5ea8, 0xe8a46a),
  SkyKey.new(0.38, 0x3f7fd0, 0xbfdcf2),
  SkyKey.new(0.50, 0x3a6fc0, 0xa8cde8),
  SkyKey.new(0.60, 0x2c4a94, 0xf0a262),
  SkyKey.new(0.68, 0x32215a, 0xc9576a),
  SkyKey.new(0.78, 0x101436, 0x2a1d40),
  SkyKey.new(0.90, 0x070c1c, 0x111a33),
]

private def lerp(a : Float64, b : Float64, t : Float64) : Float64
  a + (b - a) * t
end

private def mix(under : UInt32, fill : UInt32, t : Float64) : UInt32
  return under if t <= 0.0
  return fill if t >= 1.0
  (lerp(((under >> 16) & 0xff).to_f, ((fill >> 16) & 0xff).to_f, t).round.to_u32 << 16) |
    (lerp(((under >> 8) & 0xff).to_f, ((fill >> 8) & 0xff).to_f, t).round.to_u32 << 8) |
    lerp((under & 0xff).to_f, (fill & 0xff).to_f, t).round.to_u32
end

# Rounds to six bits per channel. Neighbouring cells of a gradient then share a
# colour, so a frame that only nudges the sky still lands on the same values and
# `Screen#flush` has nothing to send for most of the screen.
private def quantize(col : UInt32) : UInt32
  ((col >> 16) & 0xfc) << 16 | ((col >> 8) & 0xfc) << 8 | (col & 0xfc)
end

private def smoothstep(edge0 : Float64, edge1 : Float64, x : Float64) : Float64
  t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0)
  t * t * (3.0 - 2.0 * t)
end

# Zenith and horizon colours for a time of day, interpolated between keys.
private def sky_at(phase : Float64) : {UInt32, UInt32}
  n = SKY.size
  idx = n - 1
  n.times do |i|
    idx = i if SKY[i].at <= phase
  end
  a = SKY[idx]
  b = SKY[(idx + 1) % n]
  span = b.at - a.at
  span += 1.0 if span <= 0.0
  u = ((phase - a.at) / span).clamp(0.0, 1.0)
  {mix(a.zenith, b.zenith, u), mix(a.horizon, b.horizon, u)}
end

# One tree pixel: where it is, how much of it is covered, which side of the crown
# it sits on (-1 shade side .. +1 lit side) and whether it is leaf or bark.
private record TreeDot, idx : Int32, alpha : Float64, side : Float64, leaf : Bool

# Rasterizes the tree once. `limb`, `blossom` and `grow` paint coverage into
# plain arrays; the result is a list of the pixels the tree actually covers, so
# a frame only has to walk that list instead of re-running the geometry.
private class TreeMask
  getter dots = [] of TreeDot
  getter w : Int32
  getter h : Int32
  @alpha : Array(Float64)
  @side : Array(Float64)
  @leaf : Array(UInt8)
  @used : Array(Int32)

  def initialize(@w : Int32, @h : Int32, @base_x : Float64, @span : Float64)
    @alpha = Array(Float64).new(@w * @h, 0.0)
    @side = Array(Float64).new(@w * @h, 0.0)
    @leaf = Array(UInt8).new(@w * @h, 0_u8)
    @used = [] of Int32
  end

  # Records a covered pixel; a pixel keeps the strongest coverage and is a leaf
  # if any foliage touched it.
  def paint(px : Int32, py : Int32, alpha : Float64, leaf : Bool, tint : Float64) : Nil
    return if px < 0 || px >= @w || py < 0 || py >= @h || alpha <= 0.0
    i = py * @w + px
    side = ((px + 0.5 - @base_x) / @span).clamp(-1.0, 1.0) + tint
    if @alpha[i] <= 0.0
      @used << i
      @alpha[i] = alpha
      @side[i] = side
      @leaf[i] = leaf ? 1_u8 : 0_u8
    elsif alpha >= @alpha[i]
      # Ties go to whatever was painted later: a clump of foliage covers the
      # branch it grows on instead of showing it through the leaves.
      @alpha[i] = alpha
      @side[i] = side
      @leaf[i] = leaf ? 1_u8 : 0_u8
    end
  end

  def finish : Nil
    @used.each do |i|
      @dots << TreeDot.new(i, @alpha[i], @side[i], @leaf[i] == 1_u8)
    end
    @alpha.clear
    @side.clear
    @leaf.clear
    @used.clear
  end

  # A tapered limb: the trunk and every branch.
  def limb(x0 : Float64, y0 : Float64, x1 : Float64, y1 : Float64,
           r0 : Float64, r1 : Float64, leaf : Bool) : Nil
    dx = x1 - x0
    dy = y1 - y0
    len2 = dx * dx + dy * dy
    len2 = 1.0 if len2 < 1e-6
    rmax = Math.max(r0, r1) + 1.0
    minx = (Math.min(x0, x1) - rmax).floor.to_i.clamp(0, @w - 1)
    maxx = (Math.max(x0, x1) + rmax).ceil.to_i.clamp(0, @w - 1)
    miny = (Math.min(y0, y1) - rmax).floor.to_i.clamp(0, @h - 1)
    maxy = (Math.max(y0, y1) + rmax).ceil.to_i.clamp(0, @h - 1)
    (miny..maxy).each do |py|
      cy = py + 0.5
      (minx..maxx).each do |px|
        cx = px + 0.5
        u = (((cx - x0) * dx + (cy - y0) * dy) / len2).clamp(0.0, 1.0)
        ex = cx - (x0 + dx * u)
        ey = cy - (y0 + dy * u)
        d = Math.sqrt(ex * ex + ey * ey)
        r = r0 + (r1 - r0) * u
        paint(px, py, (r + 0.5 - d).clamp(0.0, 1.0), leaf, 0.0)
      end
    end
  end

  # A clump of foliage: an ellipse whose rim fades over about a pixel.
  def blossom(cx : Float64, cy : Float64, rx : Float64, ry : Float64, tint : Float64) : Nil
    minx = (cx - rx - 1.0).floor.to_i.clamp(0, @w - 1)
    maxx = (cx + rx + 1.0).ceil.to_i.clamp(0, @w - 1)
    miny = (cy - ry - 1.0).floor.to_i.clamp(0, @h - 1)
    maxy = (cy + ry + 1.0).ceil.to_i.clamp(0, @h - 1)
    (miny..maxy).each do |py|
      dy = (py + 0.5 - cy) / ry
      (minx..maxx).each do |px|
        dx = (px + 0.5 - cx) / rx
        q = Math.sqrt(dx * dx + dy * dy)
        paint(px, py, ((1.0 - q) * ry).clamp(0.0, 1.0), true, tint)
      end
    end
  end

  def grow(x : Float64, y : Float64, angle : Float64, len : Float64,
           radius : Float64, depth : Int32, rng : Random) : Nil
    # Pixel rows are twice as tall as they are wide, so a direction that should
    # look like `angle` needs twice the horizontal step.
    x1 = x + Math.sin(angle) * len * 2.0
    y1 = y - Math.cos(angle) * len
    limb(x, y, x1, y1, radius, radius * 0.7, false)

    if depth <= 0
      blossom(x1, y1, 6.0 + rng.rand * 3.5, 3.5 + rng.rand * 2.0, rng.rand * 0.25 - 0.1)
      return
    end

    spread = 0.34 + rng.rand * 0.24
    grow(x1, y1, angle - spread, len * 0.76, radius * 0.70, depth - 1, rng)
    grow(x1, y1, angle + spread, len * 0.76, radius * 0.70, depth - 1, rng)
    if depth >= 2
      grow(x1, y1, angle + (rng.rand - 0.5) * 0.16, len * 0.7, radius * 0.6, depth - 1, rng)
    end
    blossom(x1, y1, 9.0 + rng.rand * 5.0, 5.5 + rng.rand * 3.0, rng.rand * 0.2 - 0.08)
    # A couple of loose clumps break the crown's outline into leaves.
    2.times do
      blossom(x1 + (rng.rand - 0.5) * len * 1.6, y1 + (rng.rand - 0.5) * len * 0.9,
        5.0 + rng.rand * 4.0, 3.0 + rng.rand * 2.5, rng.rand * 0.3 - 0.12)
    end
  end
end

private def build_tree(w : Int32, h : Int32, base_x : Float64, ground : Float64) : TreeMask
  mask = TreeMask.new(w, h, base_x, w * 0.16)
  rng = Random.new(7)
  trunk_top = ground - ground * 0.38
  mid = trunk_top + (ground - trunk_top) * 0.5
  mask.limb(base_x, ground + 2.0, base_x + 1.6, mid, 4.4, 3.0, false)
  mask.limb(base_x + 1.6, mid, base_x + 2.4, trunk_top, 3.0, 2.0, false)
  # One leader straight up and two side pairs: the crown gets height as well as
  # width, which a single fan of branches does not.
  mask.grow(base_x + 2.4, trunk_top, 0.02, ground * 0.15, 2.0, 2, rng)
  {-0.72, -0.34, 0.36, 0.74}.each do |angle|
    mask.grow(base_x + 2.4, trunk_top + ground * 0.05, angle, ground * 0.13, 1.8, 2, rng)
  end
  mask.finish
  mask
end

unless STDIN.tty?
  STDERR.puts "sunrise: requires an interactive terminal"; exit 1
end

saved = Ori::Term.enter_raw
STDOUT << Ori::Term.enter_alt << Ori::Term.hide_cursor << Ori::Term.clear_screen
STDOUT.flush

canvas = Ori::Canvas.new(PX, PX)
screen = Ori::Screen.new

# Deterministic star field, in fractions of the sky.
stars = begin
  rng = Random.new(20240501)
  Array({Float64, Float64, Float64}).new(110) do
    {rng.rand, rng.rand * 0.92, 0.25 + rng.rand * 0.75}
  end
end

buf = [] of UInt32
buf_w = 0
buf_h = 0
tree : TreeMask? = nil
tree_w = 0
tree_h = 0

started = Time.instant
running = true
Signal::INT.trap { running = false }
Signal::TERM.trap { running = false }
STDIN.read_timeout = 16.milliseconds

while running
  now = Time.instant
  elapsed = (now - started).total_seconds
  frame_start = now

  w, h = Ori::Term.window_size
  screen.resize(w, h)
  canvas.resize(w, h)
  px_w = canvas.px_w
  px_h = canvas.px_h
  if px_w != buf_w || px_h != buf_h
    buf = Array(UInt32).new(px_w * px_h, 0x050812_u32)
    buf_w = px_w
    buf_h = px_h
  end

  phase = (elapsed / PERIOD) % 1.0
  day = phase < 0.5
  k = day ? phase * 2.0 : (phase - 0.5) * 2.0
  elev = Math.sin(Math::PI * k)
  zenith, horizon = sky_at(phase)

  ground = (px_h * 0.66).clamp(2.0, (px_h - 1).to_f)
  base_x = px_w * 0.40
  if tree.nil? || tree_w != px_w || tree_h != px_h
    tree = build_tree(px_w, px_h, base_x, ground)
    tree_w = px_w
    tree_h = px_h
  end

  body_x = (-0.10 + 1.20 * k) * px_w
  body_y = ground - elev * ground * 0.80
  body_core = day ? SUN_CORE : MOON_CORE
  body_glow = day ? SUN_GLOW : MOON_GLOW
  body_r = day ? px_h * 0.09 : px_h * 0.07
  night = day ? 0.0 : smoothstep(0.05, 0.45, k) * (1.0 - smoothstep(0.72, 0.99, k))

  light_dir = body_x < base_x ? -1.0 : 1.0
  light_amount = day ? elev : 0.35 * elev

  # Shadow: away from the light, longer while the light is low.
  shadow_dir = body_x < base_x ? 1.0 : -1.0
  shadow_len = px_w * (0.10 + 0.46 * (1.0 - elev))
  shadow_cx = base_x + shadow_dir * shadow_len * 0.75
  shadow_cy = ground + (px_h - ground) * 0.42
  shadow_rx = shadow_len * 0.72 + 6.0
  shadow_ry = Math.max(3.0, (px_h - ground) * 0.42)
  shadow_strength = day ? 0.82 * (0.45 + 0.55 * elev) : 0.42 * elev
  glow_span = ground * 0.9

  # --- sky and ground ---------------------------------------------------
  (0...px_h).each do |py|
    y = py + 0.5
    row = py * px_w
    if y < ground
      gt = (y / ground).clamp(0.0, 1.0) ** 0.85
      dys = y - body_y
      dys2 = dys * dys
      (0...px_w).each do |px|
        # Static grain: the same value every frame, so it costs no flips, and it
        # dithers the sky's gradient instead of leaving visible bands.
        gt_px = (gt + (((px * 73 + py * 131) & 7) - 3) * 0.004).clamp(0.0, 1.0)
        col = mix(zenith, horizon, gt_px)
        dxp = (px + 0.5 - body_x) * 0.5
        dd = Math.sqrt(dxp * dxp + dys2)
        if dd < glow_span
          g = 1.0 - dd / glow_span
          col = mix(col, body_glow, g * g * g * (day ? 0.75 : 0.45))
          col = mix(col, body_core, smoothstep(body_r, body_r - 1.6, dd))
        end
        buf[row + px] = col
      end
    else
      gv = ((y - ground) / (px_h - ground).clamp(1.0, 1e9)).clamp(0.0, 1.0) ** 0.8
      qy = (y - shadow_cy) / shadow_ry
      (0...px_w).each do |px|
        grain = (((px * 37 + py * 57) & 7) - 3) * 0.014
        col = mix(GROUND_HI, GROUND_LO, (gv + grain).clamp(0.0, 1.0))
        if shadow_strength > 0.01
          qx = (px + 0.5 - shadow_cx) / shadow_rx
          q = Math.sqrt(qx * qx + qy * qy)
          col = mix(col, SHADOW, (1.0 - smoothstep(0.30, 1.0, q)) * shadow_strength)
        end
        buf[row + px] = col
      end
    end
  end

  # --- stars ------------------------------------------------------------
  if night > 0.02
    stars.each do |(sx, sy, sa)|
      px = (sx * px_w).to_i
      py = (sy * ground).to_i
      next unless 0 <= px < px_w && 0 <= py < px_h
      twinkle = 0.65 + 0.35 * Math.sin(elapsed * 1.7 + sx * 40.0)
      i = py * px_w + px
      buf[i] = mix(buf[i], STAR, (sa * night * twinkle).clamp(0.0, 1.0))
    end
  end

  # --- tree -------------------------------------------------------------
  tree.not_nil!.dots.each do |dot|
    f = 0.5 + 0.5 * dot.side * light_dir
    shade = (light_amount * (0.30 + 0.70 * f) + (1.0 - light_amount) * 0.16).clamp(0.0, 1.0)
    col = dot.leaf ? mix(LEAF_DARK, LEAF_LIT, shade) : mix(BARK_DARK, BARK_LIT, shade)
    i = dot.idx
    buf[i] = dot.alpha >= 1.0 ? col : mix(buf[i], col, dot.alpha)
  end

  # --- hand the frame to the canvas -------------------------------------
  canvas.clear
  (0...px_h).each do |py|
    row = py * px_w
    (0...px_w).each do |px|
      canvas.plot(px, py, quantize(buf[row + px]))
    end
  end
  canvas.blit(screen, 0, 0)

  if h > 0
    hours = phase * 24.0
    stamp = "%02d:%02d" % {hours.to_i % 24, ((hours % 1.0) * 60.0).to_i}
    screen.write(0, h - 1, " #{stamp}   q: quit", fg: "#8a8fa3")
  end

  screen.flush(STDOUT)

  # Sleep only what is left of the frame: waiting a whole 16 ms after a frame
  # that already took 7 ms would cap the loop at ~43 fps.
  spent = (Time.instant - frame_start).total_milliseconds
  budget = (FRAME_MS - spent).clamp(1.0, FRAME_MS)
  STDIN.read_timeout = budget.milliseconds
  begin
    byte = STDIN.read_byte
    running = false if byte == 'q'.ord || byte == 'Q'.ord || byte == 3
  rescue IO::TimeoutError
  end
end

STDOUT << "\e[0m" << Ori::Term.show_cursor << Ori::Term.exit_alt
STDOUT.flush
Ori::Term.restore(saved)
