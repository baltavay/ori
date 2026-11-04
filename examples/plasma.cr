require "../src/ori"

# Plasma - an animated image, not an animation of shapes.
#
# The two raster examples this one grows out of each use half of what a cell can
# hold:
#
# * splash: a cell holds *two* independent colours ('▀' paints its upper half in
#   the foreground, its lower half in the background), so 24-bit colour breathes
#   and a slowly rotating palette is enough to make a gradient look alive.
# * bounce: a cell holds *four* pixels (the Block Elements plane has a glyph for
#   each of the sixteen quadrant masks), so geometry is twice as fine as text.
#
# Here both are used at once. For every cell the scene is sampled at the four
# quadrant centres, and the glyph + fg/bg pair that reproduces those four samples
# with the least error is picked:
#
#     A A          █        fg = mean(4),  no bg      (flat area: nothing to split)
#     A A   ->     ▀        fg = mean(A,A), bg = mean(B,B)
#     B B
#     A B          ▞        fg = mean(A,D), bg = mean(B,C)   (any of 7 splits)
#     C D
#
# A split is only taken when the two means differ visibly; otherwise neighbouring
# samples would be scattered over random quadrant glyphs and a smooth gradient
# would turn into noise. Because each colour is the *mean* of its half, a moving
# edge fades through blended colours instead of flickering between glyphs - the
# coverage blending that makes the motion read as smooth on a character grid.
#
# The scene: a plasma field (four travelling sine waves through a cycling palette)
# with metaball orbs drifting over it. Orbs merge where they overlap, and each
# carries its own slice of the palette so the merge is a colour mix.
#
#   m      rendering mode: split (above) / half ('▀' only, splash-style)
#   p      palette
#   space  pause the motion
#   +/-    more/fewer orbs
#   drag   pull the orbs towards the pointer
#   q      quit

BG = "#0a0616"

# ---------------------------------------------------------------------------
# palette
# ---------------------------------------------------------------------------

PAL_SIZE  = 128
PAL_MASK  = PAL_SIZE - 1
SIN_SIZE  = 1024
SIN_MASK  = SIN_SIZE - 1
SIN_SCALE = SIN_SIZE / (2.0 * Math::PI)

# Sine of a phase in radians, from a table: the plasma asks for four sines per
# sub-sample, and `Math.sin` there would dominate the frame.
SIN = Array(Float64).new(SIN_SIZE) { |i| Math.sin(i * 2.0 * Math::PI / SIN_SIZE) }

private def sinp(phase : Float64) : Float64
  SIN[(phase * SIN_SCALE).to_i & SIN_MASK]
end

private def blend(a : UInt32, b : UInt32, t : Float64) : UInt32
  ar = ((a >> 16) & 0xff).to_f
  ag = ((a >> 8) & 0xff).to_f
  ab = (a & 0xff).to_f
  br = ((b >> 16) & 0xff).to_f
  bg = ((b >> 8) & 0xff).to_f
  bb = (b & 0xff).to_f
  (((ar + (br - ar) * t).to_i.to_u32) << 16) |
    (((ag + (bg - ag) * t).to_i.to_u32) << 8) |
    ((ab + (bb - ab) * t).to_i.to_u32)
end

private def build_palette(stops : Array(UInt32)) : Array(UInt32)
  Array(UInt32).new(PAL_SIZE) do |i|
    pos = i.to_f / PAL_SIZE * stops.size
    k = pos.to_i
    blend(stops[k % stops.size], stops[(k + 1) % stops.size], pos - k)
  end
end

PALETTES = {
  "sunset" => build_palette([0x120024_u32, 0x4a0f6b_u32, 0x9d1a62_u32,
                             0xf04b3c_u32, 0xff9e4a_u32, 0xd63f8f_u32]),
  "ocean" => build_palette([0x02122b_u32, 0x04427a_u32, 0x0a8fbf_u32,
                            0x3ddc97_u32, 0xd9f9c8_u32, 0x2d6a8f_u32]),
  "toxic" => build_palette([0x0b1a12_u32, 0x134e2a_u32, 0x2f9e44_u32,
                            0xd8f3dc_u32, 0xa3e635_u32, 0x5c940d_u32]),
}

PALETTE_NAMES = PALETTES.keys

# Packed 0xRRGGBB from three channels. Five bits per channel: the terminal gets
# one SGR sequence per colour change, and rounding to 32 levels makes most
# neighbouring cells of a gradient share a colour, so `Screen#flush` can emit
# them as a run instead of a sequence per cell.
private def pack(r : Float64, g : Float64, b : Float64) : UInt32
  ri = r.to_i
  gi = g.to_i
  bi = b.to_i
  ri = 0 if ri < 0
  gi = 0 if gi < 0
  bi = 0 if bi < 0
  ri = 255 if ri > 255
  gi = 255 if gi > 255
  bi = 255 if bi > 255
  ((ri & 0xf8).to_u32 << 16) | ((gi & 0xf8).to_u32 << 8) | (bi & 0xf8).to_u32
end

# ---------------------------------------------------------------------------
# scene
# ---------------------------------------------------------------------------

class Orb
  property x : Float64
  property y : Float64
  property vx : Float64
  property vy : Float64
  property radius : Float64
  property hue : Float64
  property phase : Float64

  def initialize(@x : Float64, @y : Float64, @vx : Float64, @vy : Float64,
                 @radius : Float64, @hue : Float64)
    @phase = rand * Math::PI * 2
  end
end

# One orb as the sampler sees it: a squared radius, a cull radius and the colour
# its core is blending towards.
private record Blob,
  x : Float64, y : Float64, rr2 : Float64, reach : Float64,
  cr : Float64, cg : Float64, cb : Float64

class PlasmaView < Ori::Node
  # The seven ways to split four quadrants into two non-empty groups. A mask and
  # its complement are the same split with fg and bg swapped, so only masks with
  # the top-left quadrant lit are worth trying. The eighth outcome - no split -
  # is a solid block, drawn when nothing clears MIN_CONTRAST.
  CANDIDATES = {1, 3, 5, 7, 9, 11, 13}

  # mask -> Block Elements glyph. Bit 0 top-left, 1 top-right, 2 bottom-left,
  # 3 bottom-right.
  BLOCKS = {
    ' ', '▘', '▝', '▀',
    '▖', '▌', '▞', '▛',
    '▗', '▚', '▐', '▜',
    '▄', '▙', '▟', '█',
  }

  # Below this weighted channel distance a split is not worth drawing: the two
  # means are too close for the glyph to read as an edge, and picking one anyway
  # would dither a smooth area into noise.
  MIN_CONTRAST = 36

  # Flat enough that the four quadrant samples quantize to the same colour.
  FLAT = 8

  getter paused : Bool = false
  getter orbs : Array(Orb)
  @time : Float64
  @mode : Symbol
  @palette_idx : Int32
  @blobs : Array(Blob)
  @palette : Array(UInt32)
  @pointer : Tuple(Float64, Float64)?
  @world_w : Float64
  @world_h : Float64

  def initialize(style : Ori::S = Ori::S.new(flex: 1))
    super(style)
    @time = 0.0
    @mode = :split
    @palette_idx = 0
    @blobs = [] of Blob
    @palette = PALETTES[PALETTE_NAMES[0]]
    @orbs = [] of Orb
    @world_w = 80.0
    @world_h = 24.0
    5.times { add_orb }
  end

  def mode_name : String
    @mode == :split ? "split" : "half"
  end

  def palette_name : String
    PALETTE_NAMES[@palette_idx]
  end

  def cycle_mode : Nil
    @mode = @mode == :split ? :half : :split
  end

  def cycle_palette : Nil
    @palette_idx = (@palette_idx + 1) % PALETTE_NAMES.size
    @palette = PALETTES[PALETTE_NAMES[@palette_idx]]
  end

  def toggle_pause : Nil
    @paused = !@paused
  end

  def add_orb : Nil
    return if @orbs.size >= 12
    hue = rand * PAL_SIZE
    radius = 3.0 + rand * 4.0
    @orbs << Orb.new(
      rand * @world_w, rand * @world_h,
      (rand - 0.5) * 24.0, (rand - 0.5) * 16.0,
      radius, hue)
  end

  def remove_orb : Nil
    @orbs.pop? if @orbs.size > 1
  end

  def advance(dt : Float64) : Nil
    return if @paused || dt <= 0
    dt = dt.clamp(0.0, 0.05)
    @time += dt
    ww = @world_w
    wh = @world_h
    @orbs.each do |o|
      if p = @pointer
        dx = p[0] - o.x
        dy = p[1] - o.y
        d = Math.sqrt(dx * dx + dy * dy) + 1.5
        pull = 220.0 / d
        o.vx += dx / d * pull * dt
        o.vy += dy / d * pull * dt
      end
      speed = Math.hypot(o.vx, o.vy)
      if speed > 30.0
        o.vx *= 30.0 / speed
        o.vy *= 30.0 / speed
      end
      o.x += o.vx * dt
      o.y += o.vy * dt

      reach = o.radius * 2.0
      if ww > reach * 2.0
        if o.x < reach
          o.x = reach
          o.vx = o.vx.abs
        elsif o.x > ww - reach
          o.x = ww - reach
          o.vx = -o.vx.abs
        end
      end
      if wh > reach * 2.0
        if o.y < reach
          o.y = reach
          o.vy = o.vy.abs
        elsif o.y > wh - reach
          o.y = wh - reach
          o.vy = -o.vy.abs
        end
      end
    end
  end

  def on_mouse(mouse : Ori::Mouse) : Bool
    if mouse.release?
      @pointer = nil
      return true
    end
    return false unless mouse.press? || mouse.motion?
    r = @rect
    @pointer = {(mouse.x - r.x + 0.5) * 0.5, (mouse.y - r.y + 0.5).to_f}
    true
  end

  def content_height : Int32
    0
  end

  def content_width : Int32
    0
  end

  def render(io : IO) : Nil
  end

  # Scene coordinates are isotropic: one unit is one cell tall but only half a
  # cell wide, because a character is about twice as tall as it is wide. A
  # circle in scene coordinates therefore looks like a circle on screen, and the
  # four sub-samples of a cell sit a quarter unit apart.
  def render_screen(screen : Ori::Screen) : Nil
    r = @rect
    return if r.w <= 0 || r.h <= 0
    @world_w = r.w * 0.5
    @world_h = r.h.to_f
    refresh_blobs

    w = r.w
    h = r.h
    half = @mode == :half
    cy = 0
    while cy < h
      v0 = cy.to_f + 0.25
      v1 = v0 + 0.5
      cx = 0
      while cx < w
        u0 = (cx + 0.25) * 0.5
        u1 = u0 + 0.25
        a = sample(u0, v0)
        b = sample(u1, v0)
        c = sample(u0, v1)
        d = sample(u1, v1)
        cell =
          if half
            Ori::Screen::Cell.new('▀', blend(a, b, 0.5), blend(c, d, 0.5), 0_u8)
          else
            ch, fg, bg = quantize(a, b, c, d)
            Ori::Screen::Cell.new(ch, fg, bg, 0_u8)
          end
        screen.put_cell(r.x + cx, r.y + cy, cell)
        cx += 1
      end
      cy += 1
    end
  end

  private def refresh_blobs : Nil
    @blobs.clear
    shift = @time * 16.0
    @orbs.each do |o|
      hue = (o.hue + shift).to_i & PAL_MASK
      c = @palette[hue]
      cr = ((c >> 16) & 0xff).to_f * 1.45
      cg = ((c >> 8) & 0xff).to_f * 1.45
      cb = (c & 0xff).to_f * 1.45
      rr = o.radius * (1.0 + 0.12 * sinp(@time * 1.7 + o.phase))
      @blobs << Blob.new(o.x, o.y, rr * rr, rr * 3.0,
        cr + 24.0, cg + 24.0, cb + 24.0)
    end
  end

  # The scene at one world point.
  private def sample(u : Float64, v : Float64) : UInt32
    t = @time
    f = sinp(u * 0.21 + t * 1.2) +
        sinp(v * 0.26 - t * 0.9) +
        sinp((u + v) * 0.14 + t * 0.7) +
        sinp(rift(u, v, t) - t * 1.5)

    # The field's own value also lights it, so the plasma reads as a surface
    # with valleys rather than a flat sheet of hue: where the waves cancel the
    # colour is pulled towards black.
    lum = f * 0.125 + 0.5
    shade = 0.20 + 0.80 * lum * lum

    idx = (lum * 88.0 + t * 9.0).to_i & PAL_MASK
    c = @palette[idx]
    r = ((c >> 16) & 0xff).to_f * shade
    g = ((c >> 8) & 0xff).to_f * shade
    b = (c & 0xff).to_f * shade

    unless @blobs.empty?
      sw = 0.0
      sr = 0.0
      sg = 0.0
      sb = 0.0
      i = 0
      count = @blobs.size
      while i < count
        blob = @blobs.unsafe_fetch(i)
        i += 1
        dx = u - blob.x
        dy = v - blob.y
        next unless dx < blob.reach && dx > -blob.reach
        next unless dy < blob.reach && dy > -blob.reach
        q = blob.rr2 / (dx * dx + dy * dy + 0.2)
        next if q < 0.02
        q = 1.0 if q > 1.0
        w = q * q * (3.0 - 2.0 * q)
        sw += w
        sr += blob.cr * w
        sg += blob.cg * w
        sb += blob.cb * w
      end
      if sw > 0.0
        inv = 1.0 / sw
        k = sw > 1.0 ? 1.0 : sw
        r += (sr * inv - r) * k
        g += (sg * inv - g) * k
        b += (sb * inv - b) * k
      end
    end

    pack(r, g, b)
  end

  # Distance from a drifting centre, squared so no square root is needed.
  private def rift(u : Float64, v : Float64, t : Float64) : Float64
    du = u - 5.0 * sinp(t * 0.21)
    dv = v - 9.0 * sinp(t * 0.17 + 1.0)
    (du * du + dv * dv) * 0.009
  end

  # Picks the glyph and the two colours that best reproduce four quadrant
  # samples. Returns {char, fg, bg}; a flat cell gets '█' with no bg colour.
  private def quantize(a : UInt32, b : UInt32, c : UInt32, d : UInt32) : {Char, UInt32, UInt32}
    r0 = ((a >> 16) & 0xff).to_i
    r1 = ((b >> 16) & 0xff).to_i
    r2 = ((c >> 16) & 0xff).to_i
    r3 = ((d >> 16) & 0xff).to_i
    g0 = ((a >> 8) & 0xff).to_i
    g1 = ((b >> 8) & 0xff).to_i
    g2 = ((c >> 8) & 0xff).to_i
    g3 = ((d >> 8) & 0xff).to_i
    b0 = (a & 0xff).to_i
    b1 = (b & 0xff).to_i
    b2 = (c & 0xff).to_i
    b3 = (d & 0xff).to_i

    mr = (r0 + r1 + r2 + r3 + 2) >> 2
    mg = (g0 + g1 + g2 + g3 + 2) >> 2
    mb = (b0 + b1 + b2 + b3 + 2) >> 2

    # Flat cell: no glyph can beat one solid block, and most cells of a smooth
    # field land here.
    if (r0 - mr).abs < FLAT && (r1 - mr).abs < FLAT && (r2 - mr).abs < FLAT && (r3 - mr).abs < FLAT &&
       (g0 - mg).abs < FLAT && (g1 - mg).abs < FLAT && (g2 - mg).abs < FLAT && (g3 - mg).abs < FLAT &&
       (b0 - mb).abs < FLAT && (b1 - mb).abs < FLAT && (b2 - mb).abs < FLAT && (b3 - mb).abs < FLAT
      return {'█', pack(mr.to_f, mg.to_f, mb.to_f), Ori::Screen::Cell::NO_COLOR}
    end

    rs = {r0, r1, r2, r3}
    gs = {g0, g1, g2, g3}
    bs = {b0, b1, b2, b3}

    d01 = dist2(r0, g0, b0, r1, g1, b1)
    d02 = dist2(r0, g0, b0, r2, g2, b2)
    d03 = dist2(r0, g0, b0, r3, g3, b3)
    d12 = dist2(r1, g1, b1, r2, g2, b2)
    d13 = dist2(r1, g1, b1, r3, g3, b3)
    d23 = dist2(r2, g2, b2, r3, g3, b3)

    # Error of a partition is its within-group spread. For four points that is
    # the sum of the pairwise distances inside each group, over the group size,
    # so the whole search is six distances and one addition per candidate.
    errs = {
      (d12 + d13 + d23) // 3, # {0}   | {1,2,3}
      (d01 + d23) // 2,       # {0,1} | {2,3}
      (d02 + d13) // 2,       # {0,2} | {1,3}
      (d01 + d02 + d12) // 3, # {0,1,2} | {3}
      (d03 + d12) // 2,       # {0,3} | {1,2}
      (d01 + d03 + d13) // 3, # {0,1,3} | {2}
      (d02 + d03 + d23) // 3, # {0,2,3} | {1}
    }

    best_mask = 0
    best_err = Int32::MAX
    CANDIDATES.each_with_index do |mask, idx|
      err = errs[idx]
      if err < best_err
        best_err = err
        best_mask = mask
      end
    end

    fr = 0
    fg = 0
    fb = 0
    br = 0
    bg = 0
    bb = 0
    n = 0
    m = 0
    i = 0
    while i < 4
      if (best_mask >> i) & 1 == 1
        fr += rs[i]
        fg += gs[i]
        fb += bs[i]
        n += 1
      else
        br += rs[i]
        bg += gs[i]
        bb += bs[i]
        m += 1
      end
      i += 1
    end
    fr //= n
    fg //= n
    fb //= n
    br //= m
    bg //= m
    bb //= m

    # Weighted, because the eye resolves green far better than blue: a split it
    # cannot see is not worth a glyph, and the average colour is smoother.
    contrast = (fr - br).abs * 2 + (fg - bg).abs * 4 + (fb - bb).abs
    if contrast < MIN_CONTRAST
      {'█', pack(mr.to_f, mg.to_f, mb.to_f), Ori::Screen::Cell::NO_COLOR}
    else
      {BLOCKS[best_mask],
       pack(fr.to_f, fg.to_f, fb.to_f),
       pack(br.to_f, bg.to_f, bb.to_f)}
    end
  end

  # Squared colour distance with the same channel weights the contrast test uses.
  private def dist2(r1 : Int32, g1 : Int32, b1 : Int32,
                    r2 : Int32, g2 : Int32, b2 : Int32) : Int32
    dr = r1 - r2
    dg = g1 - g2
    db = b1 - b2
    dr * dr * 2 + dg * dg * 4 + db * db
  end
end

class PlasmaApp < Ori::App
  @view : PlasmaView
  # The status line is a node kept across rebuilds and rewritten from the tick.
  # `render` only runs when the tree is rebuilt (input, resize), while `@dirty`
  # repaints the tree that already exists: a `text` node built inside `render`
  # would sit frozen on its first frame for as long as nothing else rebuilds.
  @hud : Ori::TextNode

  def initialize
    @view = PlasmaView.new
    @hud = Ori::TextNode.new(hud_text, Ori::S.new(fg: "#cbb6ff", bold: true, bg: BG))
  end

  def on_start : Nil
    start_tick_with_elapsed(16.milliseconds) do |dt|
      tick(dt)
    end
  end

  # One frame of the animation: advance the scene, refresh the status line, then
  # let the renderer repaint the tree (the tick marks it dirty).
  def tick(dt : Float64) : Nil
    @view.advance(dt)
    @hud.content = hud_text
  end

  def hud_text : String
    " plasma · #{@view.mode_name} · #{@view.palette_name} · " \
    "#{@view.orbs.size} orbs · #{current_fps} fps#{@view.paused ? " · paused" : ""}"
  end

  def render : Ori::Box
    box bg: BG, padding: {0, 1} do
      attach @hud
      attach @view
      text "m mode   p palette   space pause   +/- orbs   drag to pull   q quit",
        fg: "#6c7086", bg: BG
    end
  end

  def on_key(key : Ori::Key) : Bool
    case key.text
    when "q"
      quit
      true
    when " "
      @view.toggle_pause
      true
    when "m"
      @view.cycle_mode
      true
    when "p"
      @view.cycle_palette
      true
    when "+", "="
      @view.add_orb
      true
    when "-", "_"
      @view.remove_orb
      true
    else
      false
    end
  end
end

PlasmaApp.run
