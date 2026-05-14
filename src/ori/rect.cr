struct Ori::Rect
  getter x : Int32
  getter y : Int32
  getter w : Int32
  getter h : Int32

  def initialize(@x : Int32 = 0, @y : Int32 = 0, @w : Int32 = 0, @h : Int32 = 0)
  end

  def inner(s : Ori::S) : Rect
    Rect.new(
      @x + s.padding_left,
      @y + s.padding_top,
      {@w - s.hpadding, 0}.max,
      {@h - s.vpadding, 0}.max
    )
  end

  def contains?(px : Int32, py : Int32) : Bool
    px >= @x && px < @x + @w && py >= @y && py < @y + @h
  end
end
