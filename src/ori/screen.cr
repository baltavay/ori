class Ori::Screen
  # One cell of the screen. Colours are packed 0xRRGGBB values rather than
  # "#rrggbb" Strings: `flush` writes an SGR sequence for every style change, and
  # expanding a hex String there cost six Strings per cell (`String#delete` plus
  # three `String#[]` slices per channel), which was the largest source of
  # garbage in a frame.
  struct Cell
    NO_COLOR = UInt32::MAX
    BOLD     = 1_u8
    DIM      = 2_u8

    getter char : Char
    getter fg : UInt32
    getter bg : UInt32
    getter attrs : UInt8

    # The style API's colours stay "#rrggbb" (or nil for none).
    def initialize(@char = ' ', fg : String? = nil, bg : String? = nil, bold = false, dim = false)
      @fg = Screen.color(fg)
      @bg = Screen.color(bg)
      @attrs = (bold ? BOLD : 0_u8) | (dim ? DIM : 0_u8)
    end

    # The packed form, for a cell rebuilt from another one.
    def initialize(@char : Char, @fg : UInt32, @bg : UInt32, @attrs : UInt8)
    end

    def bold : Bool
      @attrs & BOLD != 0
    end

    def dim : Bool
      @attrs & DIM != 0
    end

    def has_bg? : Bool
      @bg != NO_COLOR
    end

    def self.attrs(bold : Bool, dim : Bool) : UInt8
      (bold ? BOLD : 0_u8) | (dim ? DIM : 0_u8)
    end

    # A copy with `bg` as its background.
    def with_bg(bg : UInt32) : Cell
      Cell.new(@char, @fg, bg, @attrs)
    end

    def ==(other : Cell) : Bool
      @char == other.char && @fg == other.fg && @bg == other.bg && @attrs == other.attrs
    end

    def_hash @char, @fg, @bg, @attrs

    def write_sgr(io : IO) : Nil
      io << "\e[0m"
      unless @bg == NO_COLOR
        io << "\e[48;2;" << (@bg >> 16 & 0xff) << ';' << (@bg >> 8 & 0xff) << ';' << (@bg & 0xff) << 'm'
      end
      unless @fg == NO_COLOR
        io << "\e[38;2;" << (@fg >> 16 & 0xff) << ';' << (@fg >> 8 & 0xff) << ';' << (@fg & 0xff) << 'm'
      end
      io << "\e[1m" if bold
      io << "\e[2m" if dim
    end
  end

  # Memoized "#rrggbb" -> 0xRRGGBB, so a widget that hands the same style colour
  # to every cell of a frame pays one hash lookup per cell and allocates nothing.
  # The table holds one entry per distinct colour string an app uses.
  @@colors = Hash(String, UInt32).new

  def self.color(hex : String?) : UInt32
    return Cell::NO_COLOR if hex.nil?
    if packed = @@colors[hex]?
      return packed
    end
    packed = parse_hex(hex)
    @@colors[hex] = packed
    packed
  end

  # 0xRRGGBB for "#rrggbb" or "rrggbb". Anything else means no colour, where the
  # old code would have raised from `String#[]` on a short string.
  private def self.parse_hex(hex : String) : UInt32
    start = hex.starts_with?('#') ? 1 : 0
    return Cell::NO_COLOR unless hex.size - start == 6
    packed = 0_u32
    i = start
    while i < hex.size
      ch = hex[i]
      digit = case ch
              when '0'..'9' then ch.ord - '0'.ord
              when 'a'..'f' then ch.ord - 'a'.ord + 10
              when 'A'..'F' then ch.ord - 'A'.ord + 10
              else               return Cell::NO_COLOR
              end
      packed = (packed << 4) | digit.to_u32
      i += 1
    end
    packed
  end

  getter w : Int32
  getter h : Int32
  getter back : Array(Cell)

  @back : Array(Cell)
  @front : Array(Cell)
  @clip_stack : Array(Tuple(Int32, Int32, Int32, Int32))
  @buf : IO::Memory

  def initialize(@w : Int32 = 80, @h : Int32 = 24)
    @buf = IO::Memory.new
    size = @w * @h
    @back = Array(Cell).new(size) { Cell.new }
    @front = Array(Cell).new(size) { Cell.new }
    @clip_stack = [] of Tuple(Int32, Int32, Int32, Int32)
  end

  # One image to place after the text of this frame. `x`,`y`,`cols`,`rows` is the box
  # the node was given; `width`,`height` are the picture's own pixels, so the renderer
  # can fit it inside the box without touching the file.
  record Placement,
    x : Int32,
    y : Int32,
    cols : Int32,
    rows : Int32,
    path : String,
    width : Int32,
    height : Int32

  getter images = [] of Placement

  def place_image(x : Int32, y : Int32, cols : Int32, rows : Int32, path : String, width : Int32, height : Int32) : Nil
    return if cols < 1 || rows < 1
    @images << Placement.new(x, y, cols, rows, path, width, height)
  end

  def resize?(w : Int32, h : Int32) : Bool
    return false if @w == w && @h == h
    @w = w
    @h = h
    new_size = @w * @h
    @back = Array(Cell).new(new_size) { Cell.new }
    dummy = Cell.new('\0')
    @front = Array(Cell).new(new_size) { dummy }
    @clip_stack.clear
    true
  end

  def resize(w : Int32, h : Int32) : Nil
    resize?(w, h)
  end

  def clear : Nil
    empty = Cell.new
    @back.size.times do |i|
      @back[i] = empty
    end
    @images.clear
  end

  def clear_rect(x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    empty = Cell.new
    h.times do |row|
      w.times do |col|
        cx, cy = x + col, y + row
        next if cx < 0 || cx >= @w || cy < 0 || cy >= @h
        @back[cy * @w + cx] = empty
      end
    end
  end

  def push_clip(x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    @clip_stack.push({x, y, w, h})
  end

  def pop_clip : Nil
    @clip_stack.pop?
  end

  def put(x : Int32, y : Int32, char : Char, fg : String? = nil, bg : String? = nil, bold = false, dim = false) : Nil
    return if x < 0 || x >= @w || y < 0 || y >= @h
    if clip = @clip_stack.last?
      cx, cy, cw, ch = clip
      return if x < cx || x >= cx + cw || y < cy || y >= cy + ch
    end
    idx = y * @w + x
    @back[idx] = Cell.new(char, packed_fg(fg), packed_bg(bg), Cell.attrs(bold, dim))
  end

  # Drawing sets one style for a run of cells, so the last colour of each kind is
  # kept and the shared table is touched only when the style changes.
  @last_fg_hex : String? = nil
  @last_fg : UInt32 = Cell::NO_COLOR
  @last_bg_hex : String? = nil
  @last_bg : UInt32 = Cell::NO_COLOR

  private def packed_fg(hex : String?) : UInt32
    return Cell::NO_COLOR if hex.nil?
    unless hex == @last_fg_hex
      @last_fg_hex = hex
      @last_fg = Screen.color(hex)
    end
    @last_fg
  end

  private def packed_bg(hex : String?) : UInt32
    return Cell::NO_COLOR if hex.nil?
    unless hex == @last_bg_hex
      @last_bg_hex = hex
      @last_bg = Screen.color(hex)
    end
    @last_bg
  end

  # Copies a cell already in packed form, e.g. one a widget's own layout produced.
  # `fallback_bg` is its background when it has none.
  def put_cell(x : Int32, y : Int32, cell : Cell, fallback_bg : String? = nil) : Nil
    return if x < 0 || x >= @w || y < 0 || y >= @h
    if clip = @clip_stack.last?
      cx, cy, cw, ch = clip
      return if x < cx || x >= cx + cw || y < cy || y >= cy + ch
    end
    if !cell.has_bg? && fallback_bg
      cell = cell.with_bg(Screen.color(fallback_bg))
    end
    @back[y * @w + x] = cell
  end

  def write(x : Int32, y : Int32, text : String, fg : String? = nil, bg : String? = nil, bold = false, dim = false) : Nil
    cx = x
    cy = y
    text.each_char do |ch|
      if ch == '\n'
        cx = x
        cy += 1
        next
      end
      if cx >= 0 && cx < @w && cy >= 0 && cy < @h
        put(cx, cy, ch, fg, bg, bold, dim)
      end
      cx += 1
    end
  end

  # Re-emit the cells of a rectangle from the frame on screen. Sixel images cannot be
  # deleted with an escape the way kitty images can, so erasing one means painting
  # over it with what belongs there. These rectangles are a few hundred cells, so the
  # per-cell cursor move (rather than run merging) is not worth optimising.
  def repaint_rect(io : IO, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    return if w < 1 || h < 1
    io << Ori::Term.sync_begin
    h.times do |row|
      cy = y + row
      next if cy < 0 || cy >= @h
      w.times do |col|
        cx = x + col
        next if cx < 0 || cx >= @w
        cell = @back[cy * @w + cx]
        io << "\e[" << (cy + 1) << ';' << (cx + 1) << 'H'
        cell.write_sgr(io)
        io << cell.char
      end
    end
    io << Ori::Term.sync_end
  end

  def flush(io : IO) : Nil
    buf = @buf
    buf.clear
    w = @w
    size = @back.size
    i = 0
    run_row = -1
    run_next_x = -1
    continue_run = false
    cur_fg = Cell::NO_COLOR
    cur_bg = Cell::NO_COLOR
    cur_attrs = 0_u8
    have_style = false
    while i < size
      back = @back[i]
      if back == @front[i]
        i += 1
        next
      end
      y = i // w
      x = i - y * w
      if back.char == '\0'
        # wide-char filler: sync front, never emit
        @front[i] = back
        continue_run = false
        i += 1
        next
      end
      unless continue_run && y == run_row && x == run_next_x
        buf << "\e[" << (y + 1) << ';' << (x + 1) << 'H'
        continue_run = true
      end
      run_row = y
      run_next_x = x + 1
      unless have_style && back.fg == cur_fg && back.bg == cur_bg && back.attrs == cur_attrs
        back.write_sgr(buf)
        cur_fg = back.fg
        cur_bg = back.bg
        cur_attrs = back.attrs
        have_style = true
      end
      buf << back.char
      @front[i] = back
      i += 1
    end
    if buf.size > 0
      buf << "\e[0m"
      io << Ori::Term.sync_begin
      io.write(buf.to_slice)
      io << Ori::Term.sync_end
      io.flush
    end
  end
end
