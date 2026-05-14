struct Ori::Mouse
  enum Button
    None
    Left
    Middle
    Right
    WheelUp
    WheelDown
  end

  enum Action
    Press
    Release
    Motion
    Wheel
  end

  getter x : Int32
  getter y : Int32
  getter button : Button
  getter action : Action
  getter ctrl : Bool
  getter alt : Bool
  getter shift : Bool

  def initialize(
    @x : Int32 = 0,
    @y : Int32 = 0,
    @button : Button = Button::None,
    @action : Action = Action::Press,
    @ctrl : Bool = false,
    @alt : Bool = false,
    @shift : Bool = false
  )
  end

  def wheel? : Bool
    @action == Action::Wheel
  end

  def press? : Bool
    @action == Action::Press
  end

  def release? : Bool
    @action == Action::Release
  end

  def motion? : Bool
    @action == Action::Motion
  end

  def left? : Bool
    @button == Button::Left
  end

  def right? : Bool
    @button == Button::Right
  end

  def middle? : Bool
    @button == Button::Middle
  end

  def in?(rect : Ori::Rect) : Bool
    @x >= rect.x && @x < rect.x + rect.w && @y >= rect.y && @y < rect.y + rect.h
  end

  def to_s : String
    mods = [] of String
    mods << "ctrl" if ctrl
    mods << "alt" if alt
    mods << "shift" if shift
    parts = mods
    parts << button.to_s.downcase
    parts << action.to_s.downcase
    parts << "(#{@x},#{@y})"
    parts.join("+")
  end
end
