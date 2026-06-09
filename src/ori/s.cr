struct Ori::S
  getter fg : String?
  getter bg : String?
  getter bold : Bool
  getter dim : Bool
  getter underline : Bool
  getter strikethrough : Bool
  getter border : Symbol
  getter border_fg : String?
  getter padding : Int32
  getter padding_top : Int32
  getter padding_right : Int32
  getter padding_bottom : Int32
  getter padding_left : Int32
  getter width : Int32?
  getter height : Int32?
  getter width_pct : Float64?
  getter height_pct : Float64?
  getter min_width : Int32?
  getter max_width : Int32?
  getter min_height : Int32?
  getter max_height : Int32?
  getter spacing : Int32
  getter margin : Int32
  getter margin_top : Int32
  getter margin_right : Int32
  getter margin_bottom : Int32
  getter margin_left : Int32
  getter flex : Int32
  getter direction : Symbol
  getter align : Symbol
  getter valign : Symbol
  getter focusable : Bool
  getter scrollable : Bool
  getter bar_style : Symbol
  getter gradient_to : String?

  def initialize(
    *,
    @fg : String? = nil,
    @bg : String? = nil,
    @bold : Bool = false,
    @dim : Bool = false,
    @underline : Bool = false,
    @strikethrough : Bool = false,
    border : Bool | Symbol | Nil = nil,
    @border_fg : String? = nil,
    padding : Int32 | Tuple(Int32, Int32) | Tuple(Int32, Int32, Int32, Int32) | Nil = nil,
    @width : Int32? = nil,
    @height : Int32? = nil,
    @width_pct : Float64? = nil,
    @height_pct : Float64? = nil,
    @min_width : Int32? = nil,
    @max_width : Int32? = nil,
    @min_height : Int32? = nil,
    @max_height : Int32? = nil,
    @spacing : Int32 = 0,
    margin : Int32 | Tuple(Int32, Int32) | Tuple(Int32, Int32, Int32, Int32) | Nil = nil,
    @flex : Int32 = 0,
    @direction : Symbol = :vertical,
    @align : Symbol = :left,
    @valign : Symbol = :top,
    @focusable : Bool = false,
    @scrollable : Bool = false,
    @bar_style : Symbol = :solid,
    @gradient_to : String? = nil
  )
    @border = case border
              when true  then :single
              when false, nil then :none
              when Symbol then border
              else :none
              end
    case padding
    when Int32
      @padding = padding
      @padding_top = padding
      @padding_right = padding
      @padding_bottom = padding
      @padding_left = padding
    when Tuple(Int32, Int32)
      v, h = padding
      @padding = v
      @padding_top = v
      @padding_bottom = v
      @padding_right = h
      @padding_left = h
    when Tuple(Int32, Int32, Int32, Int32)
      @padding_top, @padding_right, @padding_bottom, @padding_left = padding
      @padding = {@padding_top, @padding_right, @padding_bottom, @padding_left}.max
    else
      @padding = 0
      @padding_top = 0
      @padding_right = 0
      @padding_bottom = 0
      @padding_left = 0
    end
    case margin
    when Int32
      @margin = margin
      @margin_top = margin
      @margin_right = margin
      @margin_bottom = margin
      @margin_left = margin
    when Tuple(Int32, Int32)
      v, h = margin
      @margin = v
      @margin_top = v
      @margin_bottom = v
      @margin_right = h
      @margin_left = h
    when Tuple(Int32, Int32, Int32, Int32)
      @margin_top, @margin_right, @margin_bottom, @margin_left = margin
      @margin = {@margin_top, @margin_right, @margin_bottom, @margin_left}.max
    else
      @margin = 0
      @margin_top = 0
      @margin_right = 0
      @margin_bottom = 0
      @margin_left = 0
    end
  end

  def self.none : S
    new
  end

  def border_size : Int32
    @border == :none ? 0 : 1
  end

  def border? : Bool
    @border != :none
  end

  def hpadding : Int32
    @padding_left + @padding_right
  end

  def vpadding : Int32
    @padding_top + @padding_bottom
  end

  def hmargin : Int32
    @margin_left + @margin_right
  end

  def vmargin : Int32
    @margin_top + @margin_bottom
  end

  def frame_h : Int32
    border_size * 2 + hpadding
  end

  def frame_v : Int32
    border_size * 2 + vpadding
  end
end
