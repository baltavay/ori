require "../src/ori"

# A soft slab of light bouncing around the screen — no outline, no crisp shapes.
#
# A hard edge is the reason step-by-step motion keeps looking stepped: the shape
# sits on whole pixels, and a terminal cell holds two colours, so a sub-pixel
# move has almost nothing to show. Here nothing has an edge. The scene is one
# continuous field: a rounded core that decays to the background over several
# cells, coloured by a palette ramp that also slides with time. The slab moving
# by a fifth of a cell changes the field in a whole neighbourhood by a few RGB
# levels, and nothing flips from one colour to another.
#
# Each cell is sampled at its four quadrant centres; when those samples differ
# enough to split, the cell is drawn as a quadrant glyph whose two colours are
# the *means* of the two halves, so a cell that straddles a slope shows an
# averaged colour instead of snapping to one of the samples.
private BG = 0x0a0615_u32

private PAL_STOPS = [
  0x89b4fa_u32, 0xcba6f7_u32, 0xf5c2e7_u32,
  0xf9e2af_u32, 0xa6e3a1_u32, 0x94e2d5_u32,
]

private PAL_SIZE = 192
private PAL_MASK = PAL_SIZE - 1

# Half-extents of the flat middle of the glow, in cells, and how far it fades
# past that. The fade is wide on purpose: the same colour range spread over a
# dozen cells is a few RGB levels per cell, which reads as a gradient instead of
# a band.
private CORE_W    = 10.0
private CORE_H    =  2.0
private FALLOFF_X =  9.0
private FALLOFF_Y =  6.0

# Cells per second.
private SPEED_X = 16.0
private SPEED_Y =  9.0

# A split is only drawn when its two means differ by this much; below it the
# cell is painted flat, otherwise a smooth slope would be dithered into noise.
private MIN_CONTRAST = 36

# The seven non-trivial ways to split four quadrants into two groups. Bit 0 is
# top-left, 1 top-right, 2 bottom-left, 3 bottom-right.
private SPLITS = {1, 3, 5, 7, 9, 11, 13}
private BLOCKS = [' ', '▘', '▝', '▀', '▖', '▌', '▞', '▛',
                  '▗', '▚', '▐', '▜', '▄', '▙', '▟', '█']

private def lerp(a : UInt32, b : UInt32, t : Float64) : UInt32
  va = a.to_f
  (va + (b.to_f - va) * t).round.to_u32
end

# Mixes `fill` into `under` by `t`.
private def mix(under : UInt32, fill : UInt32, t : Float64) : UInt32
  return under if t <= 0.0
  return fill if t >= 1.0
  (lerp((under >> 16) & 0xff, (fill >> 16) & 0xff, t) << 16) |
    (lerp((under >> 8) & 0xff, (fill >> 8) & 0xff, t) << 8) |
    lerp(under & 0xff, fill & 0xff, t)
end

private def red(col : UInt32) : Int32
  ((col >> 16) & 0xff).to_i
end

private def green(col : UInt32) : Int32
  ((col >> 8) & 0xff).to_i
end

private def blue(col : UInt32) : Int32
  (col & 0xff).to_i
end

private def pack(r : Int32, g : Int32, b : Int32) : UInt32
  (r.to_u32 << 16) | (g.to_u32 << 8) | b.to_u32
end

private PALETTE = begin
  Array(UInt32).new(PAL_SIZE) do |i|
    pos = i.to_f / PAL_SIZE * PAL_STOPS.size
    k = pos.to_i
    mix(PAL_STOPS[k % PAL_STOPS.size], PAL_STOPS[(k + 1) % PAL_STOPS.size], pos - k)
  end
end

private def dist(a : UInt32, b : UInt32) : Int32
  (((a >> 16) & 0xff).to_i - ((b >> 16) & 0xff).to_i).abs +
    (((a >> 8) & 0xff).to_i - ((b >> 8) & 0xff).to_i).abs +
    ((a & 0xff).to_i - (b & 0xff).to_i).abs
end

# The field: a superellipse dome that reaches 1 at the centre and 0 at its outer
# contour, `FALLOFF_X`/`FALLOFF_Y` cells past the core. Every point of it is
# smooth — there is no core boundary to see, which is what removes the outline.
# The whole glow spans about forty cells by twenty, which is what makes a fifth
# of a cell of movement a small colour change in hundreds of cells at once.
private def glow(cx : Float64, cy : Float64, x : Float64, y : Float64) : Float64
  qx = ((x - cx) / (CORE_W + FALLOFF_X)).abs
  qy = ((y - cy) / (CORE_H + FALLOFF_Y)).abs
  qx2 = qx * qx
  qy2 = qy * qy
  q = Math.sqrt(Math.sqrt(qx2 * qx2 + qy2 * qy2)) # (qx^4 + qy^4)^(1/4)
  return 0.0 if q >= 1.0
  # smoothstep down from the flat middle to the outer contour: the plateau
  # keeps the slab's shape, and flat ends mean no edge is visible anywhere.
  1.0 - q * q * (3.0 - 2.0 * q)
end

# Samples the palette between entries: a whole-entry index turns a smooth
# intensity into visible colour bands.
private def palette_at(pos : Float64) : UInt32
  if pos >= PAL_SIZE
    pos -= PAL_SIZE * (pos / PAL_SIZE).to_i
  end
  i = pos.to_i & PAL_MASK
  mix(PALETTE[i], PALETTE[(i + 1) & PAL_MASK], pos - pos.to_i)
end

# Colour at a point: the palette position is driven by the field value, so the
# hue follows the intensity and the whole glow cycles with time. Indexing by
# position instead would draw the ramp's own edges across the glow.
private def shade(cx : Float64, cy : Float64, x : Float64, y : Float64, phase : Float64) : UInt32
  v = glow(cx, cy, x, y)
  return BG if v <= 0.0
  # Dim: a 24-row terminal only fits so many cells of fade, and a full-range
  # gradient over that few cells shows its steps.
  mix(BG, palette_at(phase + v * 16.0), v * 0.8)
end

unless STDIN.tty?
  STDERR.puts "bounce: requires an interactive terminal"; exit 1
end

saved = Ori::Term.enter_raw
STDOUT << Ori::Term.enter_alt << Ori::Term.hide_cursor << Ori::Term.clear_screen
STDOUT.flush

cx = 20.0
cy = 10.0
vx = SPEED_X
vy = SPEED_Y
t = 0.0

screen = Ori::Screen.new

running = true
Signal::INT.trap { running = false }
Signal::TERM.trap { running = false }
STDIN.read_timeout = 16.milliseconds

last = Time.instant

while running
  now = Time.instant
  dt = (now - last).total_seconds
  last = now
  # A stalled frame must not teleport the slab across the screen.
  dt = 0.05 if dt > 0.05
  t += dt

  w, h = Ori::Term.window_size
  screen.resize(w, h)

  cx += vx * dt
  cy += vy * dt

  # Keep the last row for the hint line and the glow inside the screen.
  xmin = Math.min(CORE_W, w * 0.5)
  xmax = Math.max(xmin, w - CORE_W)
  ymin = Math.min(CORE_H, (h - 1) * 0.5)
  ymax = Math.max(ymin, h - 1 - CORE_H)
  if cx <= xmin
    cx = xmin; vx = vx.abs
  elsif cx >= xmax
    cx = xmax; vx = -vx.abs
  end
  if cy <= ymin
    cy = ymin; vy = vy.abs
  elsif cy >= ymax
    cy = ymax; vy = -vy.abs
  end

  phase = t * 48.0

  # Cells the glow cannot reach are the background: painting them with one
  # constant cell keeps the frame cheap (and the flush sees no change in them).
  bg_cell = Ori::Screen::Cell.new(' ', Ori::Screen::Cell::NO_COLOR, BG, 0_u8)
  gx0 = (cx - CORE_W - FALLOFF_X).floor.clamp(0, w - 1)
  gx1 = (cx + CORE_W + FALLOFF_X).ceil.clamp(0, w - 1)
  gy0 = (cy - CORE_H - FALLOFF_Y).floor.clamp(0, h - 1)
  gy1 = (cy + CORE_H + FALLOFF_Y).ceil.clamp(0, h - 1)

  # Every cell is the field sampled at its four quadrant centres.
  used = 0
  while used < h - 1
    x = 0
    if used < gy0 || used > gy1
      while x < w
        screen.put_cell(x, used, bg_cell)
        x += 1
      end
      used += 1
      next
    end
    while x < w
      unless gx0 <= x <= gx1
        screen.put_cell(x, used, bg_cell)
        x += 1
        next
      end
      fx = x.to_f
      fy = used.to_f
      tl = shade(cx, cy, fx + 0.25, fy + 0.25, phase)
      tr = shade(cx, cy, fx + 0.75, fy + 0.25, phase)
      bl = shade(cx, cy, fx + 0.25, fy + 0.75, phase)
      br = shade(cx, cy, fx + 0.75, fy + 0.75, phase)

      # A split can only beat MIN_CONTRAST if the four samples differ that much,
      # so a cell whose samples agree is painted flat without searching splits.
      hi = Math.max(Math.max(red(tl), red(tr)), Math.max(red(bl), red(br))) +
           Math.max(Math.max(green(tl), green(tr)), Math.max(green(bl), green(br))) +
           Math.max(Math.max(blue(tl), blue(tr)), Math.max(blue(bl), blue(br)))
      lo = Math.min(Math.min(red(tl), red(tr)), Math.min(red(bl), red(br))) +
           Math.min(Math.min(green(tl), green(tr)), Math.min(green(bl), green(br))) +
           Math.min(Math.min(blue(tl), blue(tr)), Math.min(blue(bl), blue(br)))

      best_mask = 0
      best_a = BG
      best_b = BG
      if hi - lo >= MIN_CONTRAST
        best_contrast = MIN_CONTRAST
        SPLITS.each do |mask|
          r0 = 0
          g0 = 0
          b0 = 0
          n0 = 0
          r1 = 0
          g1 = 0
          b1 = 0
          n1 = 0
          {tl, tr, bl, br}.each_with_index do |col, bit|
            if (mask >> bit) & 1 == 1
              r0 += red(col); g0 += green(col); b0 += blue(col); n0 += 1
            else
              r1 += red(col); g1 += green(col); b1 += blue(col); n1 += 1
            end
          end
          ca = pack(r0 // n0, g0 // n0, b0 // n0)
          cb = pack(r1 // n1, g1 // n1, b1 // n1)
          contrast = dist(ca, cb)
          if contrast > best_contrast
            best_contrast = contrast
            best_mask = mask
            best_a = ca
            best_b = cb
          end
        end
      end

      if best_mask == 0
        flat = pack((red(tl) + red(tr) + red(bl) + red(br)) // 4,
          (green(tl) + green(tr) + green(bl) + green(br)) // 4,
          (blue(tl) + blue(tr) + blue(bl) + blue(br)) // 4)
        screen.put_cell(x, used, Ori::Screen::Cell.new(' ', Ori::Screen::Cell::NO_COLOR, flat, 0_u8))
      else
        screen.put_cell(x, used, Ori::Screen::Cell.new(BLOCKS[best_mask], best_a, best_b, 0_u8))
      end
      x += 1
    end
    used += 1
  end

  screen.write(0, h - 1, " Press any key to quit", fg: "#6c7086") if h > 0

  screen.flush(STDOUT)

  begin
    byte = STDIN.read_byte
    running = false if byte
  rescue IO::TimeoutError
  end
end

STDOUT << "\e[0m" << Ori::Term.show_cursor << Ori::Term.exit_alt
STDOUT.flush
Ori::Term.restore(saved)
