# An offscreen bitmap finer than the terminal grid.
#
# Every cell holds `sub_x * sub_y` pixels instead of one character. When the
# canvas is composited into a `Screen` those pixels become block characters —
# `▀`, `▚`, `▛` for a 2x2 grid, `▀`/`▄` for 1x2 — so shapes and motion get twice
# the resolution a glyph-per-cell drawing has. Draw in pixel coordinates
# (`Canvas#px_w` x `Canvas#px_h`), then `blit` at a cell position.
#
#     canvas = Ori::Canvas.new(20, 10)          # 20x10 cells, 40x20 pixels
#     canvas.clear("#1e1e2e")                   # opaque background
#     canvas.fill_rect(5.4, 3.0, 8.0, 4.0, "#89b4fa")
#     canvas.blit(screen, 2, 1)
#
# A cell can only show two colours (the block character's foreground and
# background), so a pixel cell holding more than one ink colour is painted with
# the most common one. Cells the canvas never touched are left alone, which is
# what makes a canvas usable as an overlay.
class Ori::Canvas
  TRANSPARENT = Ori::Screen::Cell::NO_COLOR

  # Block characters per sub-cell bitmask, indexed by `py * sub_x + px`.
  QUADS  = [' ', '▘', '▝', '▀', '▖', '▌', '▞', '▛', '▗', '▚', '▐', '▜', '▄', '▙', '▟', '█']
  HALVES = [' ', '▀', '▄', '█']
  WIDES  = [' ', '▌', '▐', '█']
  SINGLE = [' ', '█']

  getter w : Int32
  getter h : Int32
  getter sub_x : Int32
  getter sub_y : Int32

  @px : Array(UInt32)
  @bg : UInt32
  @blocks : Array(Char)

  # Text layer: one character per cell, drawn over the pixels by `blit`. A
  # canvas that carries characters too is what lets a widget draw its whole
  # frame — chrome and labels — in one pass.
  @glyphs : Array(Char)
  @glyph_fg : Array(UInt32)
  @glyph_bg : Array(UInt32)
  @glyph_attrs : Array(UInt8)

  # `sub_x`/`sub_y` are pixels per cell: 2x2 gives quadrants, 1x2 half blocks,
  # 2x1 left/right halves, 1x1 plain cells (i.e. no sub-cell detail).
  def initialize(@w : Int32 = 0, @h : Int32 = 0, @sub_x : Int32 = 2, @sub_y : Int32 = 2)
    unless (1..2).includes?(@sub_x) && (1..2).includes?(@sub_y)
      raise ArgumentError.new("canvas sub-cell grid must be 1 or 2 per axis, got #{@sub_x}x#{@sub_y}")
    end
    @blocks = case {@sub_x, @sub_y}
              when {2, 2} then QUADS
              when {1, 2} then HALVES
              when {2, 1} then WIDES
              else             SINGLE
              end
    @bg = TRANSPARENT
    @px = Array(UInt32).new(px_w * px_h, TRANSPARENT)
    @glyphs = Array(Char).new(@w * @h, '\0')
    @glyph_fg = Array(UInt32).new(@w * @h, TRANSPARENT)
    @glyph_bg = Array(UInt32).new(@w * @h, TRANSPARENT)
    @glyph_attrs = Array(UInt8).new(@w * @h, 0_u8)
  end

  # Canvas width/height in pixels.
  def px_w : Int32
    @w * @sub_x
  end

  def px_h : Int32
    @h * @sub_y
  end

  # True when the canvas has anything to show for this cell grid, i.e. it has
  # sub-cell detail beyond what a plain character gives.
  def subcell? : Bool
    @sub_x * @sub_y > 1
  end

  def resize?(w : Int32, h : Int32) : Bool
    return false if w == @w && h == @h
    @w = w
    @h = h
    @px = Array(UInt32).new(px_w * px_h, TRANSPARENT)
    @glyphs = Array(Char).new(@w * @h, '\0')
    @glyph_fg = Array(UInt32).new(@w * @h, TRANSPARENT)
    @glyph_bg = Array(UInt32).new(@w * @h, TRANSPARENT)
    @glyph_attrs = Array(UInt8).new(@w * @h, 0_u8)
    true
  end

  def resize(w : Int32, h : Int32) : Nil
    resize?(w, h)
  end

  # Clears every pixel and makes untouched cells transparent.
  def clear : Nil
    @bg = TRANSPARENT
    @px.fill(TRANSPARENT)
    @glyphs.fill('\0')
  end

  # Clears every pixel and paints untouched cells as `color`.
  def clear(color : String | UInt32) : Nil
    @bg = pack(color)
    @px.fill(TRANSPARENT)
    @glyphs.fill('\0')
  end

  # The colour underneath the ink, `nil` while the canvas is transparent.
  def background : UInt32?
    @bg == TRANSPARENT ? nil : @bg
  end

  def plot(px : Int32, py : Int32, color : String | UInt32) : Nil
    return if px < 0 || px >= px_w || py < 0 || py >= px_h
    @px[py * px_w + px] = pack(color)
  end

  # Fills the pixels whose centre falls inside (x, y, w, h), in pixel units.
  # Fractional coordinates land on half-pixel boundaries, which is the whole
  # point: a box at x = 5.4 gets its left edge in a different sub-cell than one
  # at x = 5.0.
  def fill_rect(x : Float64, y : Float64, w : Float64, h : Float64, color : String | UInt32) : Nil
    return if w <= 0.0 || h <= 0.0
    c = pack(color)
    x0 = Math.max(0, x.floor.to_i)
    x1 = Math.min(px_w - 1, (x + w).ceil.to_i)
    y0 = Math.max(0, y.floor.to_i)
    y1 = Math.min(px_h - 1, (y + h).ceil.to_i)
    return if x1 < x0 || y1 < y0
    (y0..y1).each do |py|
      cy = py + 0.5
      next if cy < y || cy >= y + h
      row = py * px_w
      (x0..x1).each do |px|
        cx = px + 0.5
        next if cx < x || cx >= x + w
        @px[row + px] = c
      end
    end
  end

  # Same, in whole-cell units.
  def fill_cells(cx : Int32, cy : Int32, w : Int32, h : Int32, color : String | UInt32) : Nil
    fill_rect((cx * @sub_x).to_f, (cy * @sub_y).to_f,
      (w * @sub_x).to_f, (h * @sub_y).to_f, color)
  end

  # Draws a bitmap given as rows of characters; `ink` marks a lit pixel and
  # everything else is skipped. One bitmap character is one sub-cell pixel, so a
  # 5x7 glyph is 2.5 x 3.5 cells on a 2x2 canvas.
  def bitmap(x : Int32, y : Int32, rows : Array(String), color : String | UInt32, ink : Char = '#') : Nil
    c = pack(color)
    rows.each_with_index do |row, ry|
      row.each_char_with_index do |ch, rx|
        plot(x + rx, y + ry, c) if ch == ink
      end
    end
  end

  # Writes `text` into the character layer at cell (`cx`, `cy`). Characters are
  # one cell wide, like `Screen#write`. `bg` nil keeps whatever the pixel layer
  # produced underneath; `bold` and `dim` map to the cell attributes.
  def text(cx : Int32, cy : Int32, text : String, fg : String | UInt32,
           bg : String | UInt32? = nil, bold : Bool = false, dim : Bool = false) : Nil
    return if cy < 0 || cy >= @h
    f = pack(fg)
    b = bg.nil? ? TRANSPARENT : pack(bg.not_nil!)
    attrs = Ori::Screen::Cell.attrs(bold, dim)
    x = cx
    text.each_char do |ch|
      if x >= 0 && x < @w
        i = cy * @w + x
        @glyphs[i] = ch
        @glyph_fg[i] = f
        @glyph_bg[i] = b
        @glyph_attrs[i] = attrs
      end
      x += 1
    end
  end

  # Composites the canvas into `screen` with its top-left corner at (ox, oy).
  # `fallback_bg` is the colour painted behind the ink in cells that hold both
  # ink and empty pixels when the canvas itself is transparent.
  def blit(screen : Ori::Screen, ox : Int32 = 0, oy : Int32 = 0, fallback_bg : String? = nil) : Nil
    return if @w <= 0 || @h <= 0
    bg = @bg
    if bg == TRANSPARENT && fallback_bg
      bg = Ori::Screen.color(fallback_bg)
    end
    pw = px_w

    @h.times do |cy|
      sy = oy + cy
      next if sy < 0 || sy >= screen.h
      @w.times do |cx|
        sx = ox + cx
        next if sx < 0 || sx >= screen.w
        gi = cy * @w + cx
        base = cy * @sub_y * pw + cx * @sub_x
        lit = 0
        colors = StaticArray(UInt32, 4).new(TRANSPARENT)
        n = 0
        @sub_y.times do |py|
          row = base + py * pw
          @sub_x.times do |px|
            c = @px[row + px]
            next if c == TRANSPARENT
            lit |= 1 << (py * @sub_x + px)
            colors[n] = c
            n += 1
          end
        end

        # What the pixel layer alone paints. A character drawn on top keeps this
        # background, so a label inside a filled box sits on the box, not on the
        # canvas background.
        char = ' '
        fg = Ori::Screen::Cell::NO_COLOR
        cell_bg = bg
        if n == 0
          next if bg == TRANSPARENT && @glyphs[gi] == '\0'
        elsif n < @sub_x * @sub_y
          # Partly covered: the canvas background shows through, the painted
          # pixels are the mark.
          char = @blocks[lit]
          fg = majority(colors, n)
        else
          # Fully painted: split the cell into the fill it mostly is and the
          # mark painted over that fill, so a glyph on a filled box survives.
          fill = majority(colors, n)
          cell_bg = fill
          mark = second(colors, n, fill)
          unless mark == TRANSPARENT
            mask = 0
            n.times { |i| mask |= 1 << i unless near?(colors[i], fill) }
            char = @blocks[mask]
            fg = mark
          end
        end

        glyph = @glyphs[gi]
        if glyph == '\0'
          screen.put_cell(sx, sy, Ori::Screen::Cell.new(char, fg, cell_bg, 0_u8))
        else
          gbg = @glyph_bg[gi]
          screen.put_cell(sx, sy, Ori::Screen::Cell.new(glyph, @glyph_fg[gi],
            gbg == TRANSPARENT ? cell_bg : gbg, @glyph_attrs[gi]))
        end
      end
    end
  end

  # Colours this close to the fill are treated as the fill. Without it a smooth
  # gradient paints every cell as two half-cell stripes one shade apart.
  private COLOR_TOLERANCE = 8

  private def near?(a : UInt32, b : UInt32) : Bool
    r = (((a >> 16) & 0xff).to_i - ((b >> 16) & 0xff).to_i).abs
    g = (((a >> 8) & 0xff).to_i - ((b >> 8) & 0xff).to_i).abs
    bl = ((a & 0xff).to_i - (b & 0xff).to_i).abs
    r <= COLOR_TOLERANCE && g <= COLOR_TOLERANCE && bl <= COLOR_TOLERANCE
  end

  # The colour that appears most often in `colors[0, n)`.
  private def majority(colors : StaticArray(UInt32, 4), n : Int32) : UInt32
    best = colors[0]
    best_count = 0
    n.times do |i|
      count = 0
      n.times { |j| count += 1 if colors[j] == colors[i] }
      if count > best_count
        best_count = count
        best = colors[i]
      end
    end
    best
  end

  # The most common colour that is not `fill`, or TRANSPARENT when there is none.
  private def second(colors : StaticArray(UInt32, 4), n : Int32, fill : UInt32) : UInt32
    best = TRANSPARENT
    best_count = 0
    n.times do |i|
      next if near?(colors[i], fill)
      count = 0
      n.times { |j| count += 1 if colors[j] == colors[i] }
      if count > best_count
        best_count = count
        best = colors[i]
      end
    end
    best
  end

  private def pack(color : UInt32) : UInt32
    color
  end

  private def pack(color : String) : UInt32
    Ori::Screen.color(color)
  end
end

# A widget that owns a `Canvas` sized to its rectangle and redraws it every
# frame. The block receives the canvas in pixel coordinates.
#
#     canvas(width: 20, height: 10) do |c|
#       c.clear("#1e1e2e")
#       c.fill_rect(2.0, 2.0, 12.0, 6.0, "#89b4fa")
#     end
class Ori::CanvasNode < Ori::Node
  getter canvas : Ori::Canvas

  def initialize(sub_x : Int32 = 2, sub_y : Int32 = 2, style : Ori::S = Ori::S.none,
                 &draw : Ori::Canvas -> Nil)
    super(style)
    @canvas = Ori::Canvas.new(0, 0, sub_x, sub_y)
    @draw = draw
  end

  # Sub-cell grid the node renders at; falls back to whole cells on request.
  def subcell? : Bool
    @canvas.subcell?
  end

  def content_width : Int32
    @style.width || 1
  end

  def content_height : Int32
    @style.height || 1
  end

  def render(io : IO) : Nil
  end

  def render_screen(screen : Ori::Screen) : Nil
    r = @rect
    return if r.w <= 0 || r.h <= 0
    @canvas.resize(r.w, r.h)
    @canvas.clear
    @draw.call(@canvas)
    @canvas.blit(screen, r.x, r.y, effective_bg)
  end
end
