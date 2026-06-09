class Ori::InputNode < Ori::Node
  BORDER_OFF    = "#4A3F6B"
  BORDER_ON     = "#A78BFA"

  @value : String
  @cursor : Int32
  @scroll : Int32
  @placeholder : String
  @prefix : String
  @on_change : Proc(String, Nil)?
  @on_submit : Proc(Nil)?
  @on_cursor : Proc(Int32, Nil)?

  def initialize(
    value : String = "",
    @placeholder : String = "",
    prefix : String = "▌",
    cursor : Int32? = nil,
    @on_change : Proc(String, Nil)? = nil,
    @on_submit : Proc(Nil)? = nil,
    @on_cursor : Proc(Int32, Nil)? = nil,
    style : Ori::S = Ori::S.none
  )
    super(style)
    @value = value
    @cursor = cursor || value.size
    @scroll = 0
    @prefix = prefix
  end

  getter value : String

  def value=(v : String)
    @value = v
    @cursor = {@cursor, @value.size}.min
  end

  def content_height : Int32
    1
  end

  def content_width : Int32
    {@value.size, @placeholder.size}.max + prefix_offset
  end

  def focusable? : Bool
    true
  end

  def cursor_position : {Int32, Int32}?
    return nil unless @focused
    adjust_scroll
    cx = {@cursor - @scroll, text_width - 1}.min
    {@rect.x + prefix_offset + cx, @rect.y}
  end

  def render_screen(screen : Ori::Screen) : Nil
    adjust_scroll
    if prefix_offset > 0
      border_color = @focused ? BORDER_ON : BORDER_OFF
      @prefix.each_char_with_index do |ch, i|
        screen.put(@rect.x + i, @rect.y, ch, fg: border_color)
      end
    end

    display = @value.empty? && !@focused ? @placeholder : @value
    tw = text_width
    visible = display[@scroll...@scroll + tw].to_s
    padded = visible.ljust(tw)
    dim = @value.empty? && !@focused
    padded.each_char_with_index do |ch, i|
      screen.put(@rect.x + prefix_offset + i, @rect.y, ch, fg: @style.fg, bg: effective_bg, dim: dim)
    end
  end

  def render(io : IO) : Nil
    adjust_scroll
    if prefix_offset > 0
      border_color = @focused ? BORDER_ON : BORDER_OFF
      io << Ori::Term.move(@rect.x, @rect.y) << Ori::Color.apply(border_color, @prefix)
    end

    display = @value.empty? && !@focused ? @placeholder : @value
    tw = text_width
    visible = display[@scroll...@scroll + tw].to_s.ljust(tw)
    visible = Ori::Color.dim(visible) if @value.empty? && !@focused
    visible = Ori::Color.apply(@style.fg, visible) if @style.fg
    io << Ori::Term.move(@rect.x + prefix_offset, @rect.y) << visible
  end

  private def prefix_offset : Int32
    @style.border? && @style.border != :none ? 1 : 0
  end

  def on_key(key : Ori::Key) : Bool
    case key.code
    when .enter?
      @on_submit.try(&.call)
      true
    when .backspace?
      if @cursor > 0
        @value = @value[0...@cursor - 1] + @value[@cursor..]
        @cursor -= 1
        @on_change.try(&.call(@value)); @on_cursor.try(&.call(@cursor))
      end
      true
    when .delete?
      if @cursor < @value.size
        @value = @value[0...@cursor] + @value[@cursor + 1..]
        @on_change.try(&.call(@value))
      end
      true
    when .left?
      if @cursor > 0; @cursor -= 1; @on_cursor.try(&.call(@cursor)) end
      true
    when .right?
      if @cursor < @value.size; @cursor += 1; @on_cursor.try(&.call(@cursor)) end
      true
    when .home?
      if @cursor != 0; @cursor = 0; @on_cursor.try(&.call(@cursor)) end
      true
    when .end?
      if @cursor != @value.size; @cursor = @value.size; @on_cursor.try(&.call(@cursor)) end
      true
    else
      if key.printable?
        @value = @value[0...@cursor] + key.text + @value[@cursor..]
        @cursor += 1
        @on_change.try(&.call(@value)); @on_cursor.try(&.call(@cursor))
        true
      else
        false
      end
    end
  end

  private def text_width : Int32
    {@rect.w - prefix_offset, 1}.max
  end

  private def adjust_scroll
    tw = text_width
    if @cursor < @scroll
      @scroll = @cursor
    elsif @cursor >= @scroll + tw
      @scroll = @cursor - tw + 1
    end
  end
end
