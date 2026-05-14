class Ori::Sparkline < Ori::Node
  BLOCK_CHARS = {' ', '▁', '▂', '▃', '▄', '▅', '▆', '▇', '█'}

  @data : Array(Float64)
  @max : Float64
  @auto_max : Bool

  def initialize(
    data : Array(Float64) = [] of Float64,
    @max : Float64 = 0.0,
    @auto_max : Bool = true,
    style : Ori::S = Ori::S.none
  )
    super(style)
    @data = data
    @max = @auto_max ? (@data.max? || 1.0) : @max
    @max = 1.0 if @max <= 0
  end

  getter data : Array(Float64)
  getter max : Float64

  def push(value : Float64) : Nil
    @data << value
    if @auto_max && value > @max
      @max = value
    end
  end

  def push_all(values : Array(Float64)) : Nil
    values.each { |v| push(v) }
  end

  def content_height : Int32
    {@style.height || 1, 1}.max
  end

  def content_width : Int32
    {@data.size, @style.width || 1}.max
  end

  def focusable? : Bool
    false
  end

  def render_screen(screen : Ori::Screen) : Nil
    r = @rect
    return if r.w <= 0 || r.h <= 0
    fg = @style.fg || "#89b4fa"
    bg = effective_bg
    bar_height = r.h

    @data.each_with_index do |value, col|
      next if col >= r.w
      if @max > 0
        scaled = (value / @max * bar_height * (BLOCK_CHARS.size - 1)).round.to_i
        filled_rows = scaled // (BLOCK_CHARS.size - 1)
        partial = BLOCK_CHARS[{scaled % (BLOCK_CHARS.size - 1), BLOCK_CHARS.size - 1}.min]

        filled_rows.times do |row|
          from_bottom = bar_height - 1 - row
          screen.put(r.x + col, r.y + from_bottom, '█', fg: fg, bg: bg) if from_bottom >= 0
        end
        partial_row = bar_height - 1 - filled_rows
        if partial_row >= 0 && partial != ' '
          screen.put(r.x + col, r.y + partial_row, partial, fg: fg, bg: bg)
        end
      end
    end
  end

  def render(io : IO) : Nil
  end
end
