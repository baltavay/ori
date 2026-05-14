struct Ori::Key
  enum Code
    Unknown; Up; Down; Left; Right; Enter; Backspace
    Tab; Escape; Space; Home; End; Insert; Delete
    PgUp; PgDown
    F1; F2; F3; F4; F5; F6; F7; F8; F9; F10; F11; F12
  end

  getter text : String
  getter code : Code
  getter ctrl : Bool
  getter alt : Bool
  getter shift : Bool

  def initialize(@text = "", @code = Code::Unknown, @ctrl = false, @alt = false, @shift = false)
  end

  def printable? : Bool
    !@text.empty? && !@ctrl && !@alt
  end

  def to_s : String
    parts = [] of String
    parts << "ctrl" if ctrl; parts << "alt" if alt; parts << "shift" if shift
    parts << (code.unknown? ? text : code.to_s.downcase)
    parts.join("+")
  end
end
