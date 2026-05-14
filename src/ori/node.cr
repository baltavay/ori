abstract class Ori::Node
  getter style : Ori::S
  property rect : Ori::Rect
  property focused : Bool
  property inherited_bg : String?

  def initialize(@style : Ori::S = Ori::S.none)
    @rect = Ori::Rect.new(0, 0, 0, 0)
    @focused = false
    @inherited_bg = nil
  end

  abstract def render(io : IO) : Nil
  abstract def content_height : Int32
  abstract def content_width : Int32

  def render_screen(screen : Ori::Screen) : Nil
  end

  def render_overlay(screen : Ori::Screen) : Nil
  end

  def effective_bg : String?
    @style.bg || @inherited_bg
  end

  def focusable? : Bool
    @style.focusable
  end

  def on_key(key : Ori::Key) : Bool
    false
  end

  def on_mouse(mouse : Ori::Mouse) : Bool
    false
  end

  def blur : Nil
  end
end
