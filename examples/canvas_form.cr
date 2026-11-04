require "../src/ori"

# A sign-up form drawn on a sub-cell canvas: the banner, field boxes, checkbox,
# button and completion rule are canvas pixels, and the labels, typed values and
# caret are canvas text cells composited on top at normal terminal size.
#
#     tab: next    space: toggle    enter: submit    ctrl+c: quit
private FIELD = 0x181825_u32
private EDGE  = 0x45475a_u32
private FG    = 0xcdd6f4_u32
private DM    = 0x6c7086_u32
private AC    = 0xcba6f7_u32
private GREEN = 0xa6e3a1_u32
private RED   = 0xf38ba8_u32
private DARK  = 0x1e1e2e_u32

private PX =  2 # canvas pixels per cell
private W  = 58 # canvas size in cells
private H  = 20

private BANNER_H     =  5 # cells
private FIELD_TOP    =  6 # first field, in cells
private FIELD_PITCH  =  3
private FIELD_X      = 13 # field box, in cells
private FIELD_RIGHT  = 55
private CONTROLS_ROW = 16
private HINT_ROW     = 19

private FIELDS  = 3 # name, email, workspace; then the checkbox and the button
private TARGETS = 5

private BAND_STOPS = [0x89b4fa_u32, 0xcba6f7_u32, 0xf5c2e7_u32]

# 5x7 capitals for the banner wordmark, one glyph pixel per canvas pixel.
private LETTERS = {
  'S' => {"01110", "10001", "10000", "01110", "00001", "10001", "01110"},
  'I' => {"11111", "00100", "00100", "00100", "00100", "00100", "11111"},
  'G' => {"01110", "10001", "10000", "10111", "10001", "10001", "01110"},
  'N' => {"10001", "11001", "10101", "10011", "10001", "10001", "10001"},
  'U' => {"10001", "10001", "10001", "10001", "10001", "10001", "01110"},
  'P' => {"11110", "10001", "10001", "11110", "10000", "10000", "10000"},
  ' ' => {"...", "...", "...", "...", "...", "...", "..."},
}

private def wordmark(text : String) : Array(String)
  rows = [] of String
  7.times do |gy|
    s = String::Builder.new
    text.each_char_with_index do |ch, i|
      s << '.' if i > 0
      LETTERS[ch][gy].each_char { |c| s << (c == '1' ? '#' : '.') }
    end
    rows << s.to_s
  end
  rows
end

private TITLE = wordmark("SIGN UP")

# 0xRRGGBB mix of two packed colours.
private def mix(a : UInt32, b : UInt32, t : Float64) : UInt32
  ar = ((a >> 16) & 0xff).to_f
  ag = ((a >> 8) & 0xff).to_f
  ab = (a & 0xff).to_f
  br = ((b >> 16) & 0xff).to_f
  bg = ((b >> 8) & 0xff).to_f
  bb = (b & 0xff).to_f
  r = (ar + (br - ar) * t).round.to_u32
  g = (ag + (bg - ag) * t).round.to_u32
  bl = (ab + (bb - ab) * t).round.to_u32
  (r << 16) | (g << 8) | bl
end

# Cyclic blue -> mauve -> pink ramp; `t` wraps, so the banner can scroll it.
private def ramp(t : Float64) : UInt32
  pos = (t % 1.0) * BAND_STOPS.size
  i = pos.floor.to_i % BAND_STOPS.size
  mix(BAND_STOPS[i], BAND_STOPS[(i + 1) % BAND_STOPS.size], pos - pos.floor)
end

# One text field: value, caret and placeholder. All of it lives in the page.
class Field
  property label : String
  property placeholder : String
  property value : String
  property cursor : Int32

  def initialize(@label : String, @placeholder : String)
    @value = ""
    @cursor = 0
  end

  # First visible character, so the caret stays inside `inner` cells.
  def scroll(inner : Int32) : Int32
    return 0 if @cursor < inner
    @cursor - inner + 1
  end

  def insert(text : String) : Nil
    @value = @value[0, @cursor] + text + @value[@cursor, @value.size - @cursor]
    @cursor += text.size
  end

  def backspace : Nil
    return if @cursor <= 0
    @value = @value[0, @cursor - 1] + @value[@cursor, @value.size - @cursor]
    @cursor -= 1
  end

  def delete : Nil
    return if @cursor >= @value.size
    @value = @value[0, @cursor] + @value[@cursor + 1, @value.size - @cursor - 1]
  end
end

class SignUpPage < Ori::Page
  @fields : Array(Field) = [
    Field.new("Name", "Ada Lovelace"),
    Field.new("Email", "ada@example.com"),
    Field.new("Workspace", "acme"),
  ]
  @current = 0
  @agree = false
  @status = ""
  @status_fg = DM
  @phase = 0.0
  @progress = 0.0
  @ticking = false

  def render : Ori::Box
    box direction: :vertical, padding: {1, 2}, bg: "#1e1e2e" do
      canvas(width: W, height: H) do |c|
        draw(c)
      end
    end
  end

  # --- drawing -------------------------------------------------------------

  private def draw(c : Ori::Canvas) : Nil
    band(c)
    @fields.each_with_index { |f, i| field(c, f, i) }
    controls(c)
    hint(c)
  end

  private def band(c : Ori::Canvas) : Nil
    w = c.px_w
    h = BANNER_H * PX
    w.times do |px|
      c.fill_rect(px.to_f, 0.0, 1.0, h.to_f, ramp(px.to_f / w + @phase * 0.06))
    end
    c.fill_rect(0.0, 0.0, w.to_f, 1.0, FG)
    # The bottom rule doubles as the completion meter.
    c.fill_rect(0.0, (h - 1).to_f, w.to_f, 1.0, EDGE)
    filled = (@progress * w).round.to_f
    if filled > 0.0
      c.fill_rect(0.0, (h - 1).to_f, filled, 1.0, @progress >= 0.999 ? GREEN : AC)
    end
    c.bitmap((w - TITLE[0].size) // 2, (h - TITLE.size) // 2, TITLE, DARK)
  end

  private def field(c : Ori::Canvas, f : Field, index : Int32) : Nil
    top = FIELD_TOP + index * FIELD_PITCH
    px = FIELD_X * PX
    py = top * PX
    pw = (FIELD_RIGHT - FIELD_X + 1) * PX
    ph = FIELD_PITCH * PX
    focused = @current == index
    edge = focused ? AC : EDGE

    c.fill_rect(px.to_f, py.to_f, pw.to_f, ph.to_f, FIELD)
    c.fill_rect(px.to_f, py.to_f, pw.to_f, 1.0, edge)
    c.fill_rect(px.to_f, (py + ph - 1).to_f, pw.to_f, 1.0, edge)
    c.fill_rect(px.to_f, py.to_f, 1.0, ph.to_f, edge)

    c.text(2, top + 1, f.label, focused ? FG : DM)
    inner = FIELD_RIGHT - FIELD_X - 2
    scroll = f.scroll(inner)
    shown = f.value[scroll, f.value.size - scroll]
    tx = FIELD_X + 2
    ty = top + 1
    if shown.empty?
      c.text(tx, ty, f.placeholder[0, inner], DM)
    else
      c.text(tx, ty, shown[0, inner], FG)
    end

    return unless focused
    caret = f.cursor - scroll
    ch = caret < shown.size ? shown[caret] : ' '
    c.text(tx + caret, ty, ch.to_s, FIELD, AC)
  end

  private def controls(c : Ori::Canvas) : Nil
    row = CONTROLS_ROW + 1
    focused = @current == 3

    # A text checkbox sits at the same weight as the rest of the text; a pixel
    # box would be three cells tall and read as a slab next to it.
    c.text(FIELD_X, row, @agree ? "[x]" : "[ ]", focused ? AC : DM)
    c.text(FIELD_X + 4, row, "I agree", focused ? FG : DM)

    press = @current == 4
    fill = press ? AC : EDGE
    bx = 36 * PX
    bw = 18 * PX
    py = CONTROLS_ROW * PX
    c.fill_rect(bx.to_f, py.to_f, bw.to_f, 6.0, fill)
    c.fill_rect(bx.to_f, py.to_f, bw.to_f, 1.0, mix(fill, 0xffffff_u32, 0.3))
    label = "Sign up"
    c.text(36 + (18 - label.size) // 2, row, label, press ? DARK : FG)
  end

  private def hint(c : Ori::Canvas) : Nil
    if @status.empty?
      c.text(2, HINT_ROW, "tab: next    space: toggle    enter: submit", DM)
    else
      c.text(2, HINT_ROW, @status, @status_fg)
    end
  end

  # --- state ---------------------------------------------------------------

  private def completion : Float64
    done = 0
    done += 1 unless @fields[0].value.strip.empty?
    done += 1 if @fields[1].value.includes?('@')
    done += 1 unless @fields[2].value.strip.empty?
    done += 1 if @agree
    done / 4.0
  end

  private def submit : Nil
    if @fields[0].value.strip.empty? || !@fields[1].value.includes?('@') || !@agree
      @status = "Name, a valid email and the terms are required"
      @status_fg = RED
    else
      @status = "Welcome, #{@fields[0].value.strip}!"
      @status_fg = GREEN
    end
  end

  private def edit(key : Ori::Key) : Bool
    f = @fields[@current]
    case
    when key.code.backspace? then f.backspace
    when key.code.delete?    then f.delete
    when key.code.left?      then f.cursor = {f.cursor - 1, 0}.max
    when key.code.right?     then f.cursor = {f.cursor + 1, f.value.size}.min
    when key.code.home?      then f.cursor = 0
    when key.code.end?       then f.cursor = f.value.size
    when key.printable?      then f.insert(key.text)
    else
      return false
    end
    true
  end

  # --- lifecycle -----------------------------------------------------------

  def on_enter : Nil
    return if @ticking
    @ticking = true
    app.start_tick_with_elapsed(16.milliseconds) do |dt|
      @phase += dt
      @progress += (completion - @progress) * {dt * 10.0, 1.0}.min
    end
  end

  def on_key(key : Ori::Key) : Bool
    if key.code.tab?
      @current = (@current + (key.shift ? TARGETS - 1 : 1)) % TARGETS
      return true
    end
    if key.code.enter?
      submit
      return true
    end
    return edit(key) if @current < FIELDS
    if key.code.space? || key.text == " "
      @current == 3 ? (@agree = !@agree) : submit
      return true
    end
    false
  end

  def bindings : Hash(String, String)
    {"tab" => "next", "space" => "toggle", "enter" => "submit", "ctrl+c" => "quit"}
  end
end

class CanvasFormApp < Ori::App
  def initialize
    super
    push_page(SignUpPage.new(self))
  end
end

CanvasFormApp.run
