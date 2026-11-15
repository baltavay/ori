struct Ori::Rect
  getter x : Int32
  getter y : Int32
  getter w : Int32
  getter h : Int32

  def initialize(@x : Int32 = 0, @y : Int32 = 0, @w : Int32 = 0, @h : Int32 = 0)
  end

  # Content area: the frame (border) and the padding are both outside it. The
  # border was missing here, so a bordered box drew its children on the frame.
  def inner(s : Ori::S) : Rect
    bs = s.border_size
    Rect.new(
      @x + s.padding_left + bs,
      @y + s.padding_top + bs,
      {@w - s.frame_h, 0}.max,
      {@h - s.frame_v, 0}.max
    )
  end

  def contains?(px : Int32, py : Int32) : Bool
    px >= @x && px < @x + @w && py >= @y && py < @y + @h
  end
end
