class Ori::Screen
  struct Cell
    getter char : Char
    getter fg : String?
    getter bg : String?
    getter bold : Bool
    getter dim : Bool

    def initialize(@char = ' ', @fg : String? = nil, @bg : String? = nil, @bold = false, @dim = false)
    end

    def ==(other : Cell) : Bool
      @char == other.char && @fg == other.fg && @bg == other.bg && @bold == other.bold && @dim == other.dim
    end

    def_hash @char, @fg, @bg, @bold, @dim

    def write_ansi(io : IO) : Nil
      if bg = @bg
        h = bg.delete('#')
        io << "\e[48;2;" << h[0, 2].to_i(16) << ';' << h[2, 2].to_i(16) << ';' << h[4, 2].to_i(16) << 'm'
      end
      if fg = @fg
        h = fg.delete('#')
        io << "\e[38;2;" << h[0, 2].to_i(16) << ';' << h[2, 2].to_i(16) << ';' << h[4, 2].to_i(16) << 'm'
      end
      io << "\e[1m" if @bold
      io << "\e[2m" if @dim
      io << @char
      io << "\e[0m" if @fg || @bg || @bold || @dim
    end
  end

  getter w : Int32
  getter h : Int32
  getter back : Array(Cell)

  @back : Array(Cell)
  @front : Array(Cell)
  @clip_stack : Array(Tuple(Int32, Int32, Int32, Int32))

  def initialize(@w : Int32 = 80, @h : Int32 = 24)
    size = @w * @h
    @back = Array(Cell).new(size) { Cell.new }
    @front = Array(Cell).new(size) { Cell.new }
    @clip_stack = [] of Tuple(Int32, Int32, Int32, Int32)
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
    @back[idx] = Cell.new(char, fg, bg, bold, dim)
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

  def flush(io : IO) : Nil
    buf = IO::Memory.new
    w = @w
    size = @back.size
    i = 0
    while i < size
      back = @back[i]
      front = @front[i]
      unless back == front
        y = i // w
        x = i - y * w
        buf << "\e[#{y + 1};#{x + 1}H"
        back.write_ansi(buf)
        @front[i] = back
      end
      i += 1
    end
    if buf.size > 0
      buf << "\e[0m"
      io.write(buf.to_slice)
      io.flush
    end
  end
end
