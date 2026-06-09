class Ori::TestHarness
  getter width : Int32
  getter height : Int32
  getter screen : Ori::Screen
  property root : Ori::Box
  getter focus : Ori::FocusManager

  def initialize(@width : Int32 = 80, @height : Int32 = 24)
    @screen = Ori::Screen.new(@width, @height)
    @focus = Ori::FocusManager.new
    @root = Ori::Box.new
    @root.rect = Ori::Rect.new(0, 0, @width, @height)
  end

  def focused_node : Ori::Node?
    @focus.focused_node
  end

  # --- AI-friendly inspect API ---

  # Full state: screen text + widget tree + focus + terminal size
  def state
    fn = focused_node
    focus_info = fn ? {
      "type"  => fn.class.to_s.split("::").last,
      "x"     => fn.rect.x.to_s,
      "y"     => fn.rect.y.to_s,
      "w"     => fn.rect.w.to_s,
      "h"     => fn.rect.h.to_s,
      "label" => widget_label(fn),
    } : nil

    {
      screen: lines,
      widget_tree: print_widget_tree(@root),
      focus: focus_info,
      width: @width,
      height: @height,
    }
  end

  # One keypress + frame, returns state before and after
  def step(key : Ori::Key)
    before = state
    key(key)
    frame
    after = state
    {"before" => before, "after" => after}
  end

  def step(code : Ori::Key::Code, text : String = "")
    step(Ori::Key.new(code: code, text: text))
  end

  # JSON string of full state (AI-friendly)
  def state_json : String
    s = state
    focus = s[:focus]
    focus_str = focus ? "\"focus\": #{hash_to_json(focus)}" : "\"focus\": null"
    lines = s[:screen].map { |l| "\"#{escape_json(l)}\"" }.join(",\n    ")
    String.build do |io|
      io << "{\n"
      io << "  \"width\": #{s[:width]},\n"
      io << "  \"height\": #{s[:height]},\n"
      io << "  \"widget_tree\": #{escape_json(s[:widget_tree])},\n"
      io << "  #{focus_str},\n"
      io << "  \"screen\": [\n    #{lines}\n  ]\n"
      io << "}"
    end
  end

  private def hash_to_json(h : Hash(String, String)) : String
    pairs = h.map do |k, v|
      case v
      when String then "\"#{k}\": #{escape_json(v)}"
      when Bool   then "\"#{k}\": #{v}"
      when Int32  then "\"#{k}\": #{v}"
      when Nil    then "\"#{k}\": null"
      else             "\"#{k}\": #{v}"
      end
    end
    "{#{pairs.join(", ")}}"
  end

  private def escape_json(s : String) : String
    s.gsub("\\", "\\\\\\\\").gsub("\"", "\\\"").gsub("\n", "\\n")
  end

  # All widgets as flat array with type/rect/focused/label
  def widgets(root : Ori::Node? = nil) : Array(Hash(String, String | Bool))
    nodes = [] of Hash(String, String | Bool)
    collect_widgets(root || @root, nodes)
    nodes
  end

  private def collect_widgets(node : Ori::Node, result : Array(Hash(String, String | Bool))) : Nil
    entry = {
      "type"    => node.class.to_s.split("::").last,
      "x"       => node.rect.x.to_s,
      "y"       => node.rect.y.to_s,
      "w"       => node.rect.w.to_s,
      "h"       => node.rect.h.to_s,
      "focused" => node.focused,
      "label"   => widget_label(node),
    }
    result << entry
    if node.is_a?(Ori::Box)
      node.children.each { |c| collect_widgets(c, result) }
    end
  end

  private def widget_label(node : Ori::Node) : String
    case node
    when Ori::Button    then node.label
    when Ori::Checkbox  then node.label
    when Ori::Radio     then node.label
    when Ori::TextNode  then node.content
    when Ori::InputNode then node.value
    when Ori::TextArea  then node.value
    when Ori::Tabs      then node.tabs.join(", ")
    when Ori::Select    then node.selected_value || ""
    when Ori::Tree      then node.selected_data || ""
    when Ori::Slider    then node.value.to_s
    when Ori::Toast     then node.message
    else ""
    end
  end

  # Full widget tree as indented string (AI-readable)
  def print_widget_tree(node : Ori::Node? = nil, indent : Int32 = 0) : String
    n = node || @root
    name = n.class.to_s.split("::").last
    r = n.rect
    info = "#{name}[#{r.w}x#{r.h} @(#{r.x},#{r.y})]"
    info += " focused" if n.focused
    info += " \"#{widget_label(n)}\"" if widget_label(n) != ""
    result = "#{"  " * indent}#{info}"
    if n.is_a?(Ori::Box)
      n.children.each do |c|
        result += "\n#{print_widget_tree(c, indent + 1)}"
      end
    end
    result
  end

  # --- Standard inspect ---

  def dump_tree(node : Ori::Node? = nil, indent : Int32 = 0) : String
    n = node || @root
    name = n.class.to_s.split("::").last
    rect = n.rect
    style = n.style
    info = "#{name} x=#{rect.x} y=#{rect.y} w=#{rect.w} h=#{rect.h}"
    info += " focused" if n.focused
    info += " scrollable" if n.responds_to?(:scrollable?) && n.as(Ori::Box).scrollable?
    result = "#{"  " * indent}#{info}"
    if n.is_a?(Ori::Box)
      n.children.each do |c|
        result += "\n#{dump_tree(c, indent + 1)}"
      end
    end
    if n.responds_to?(:open) && n.open
      result += " [open]"
    end
    result
  end

  def styled_char_at(x : Int32, y : Int32) : Ori::Screen::Cell
    return Ori::Screen::Cell.new if x < 0 || x >= @width || y < 0 || y >= @height
    @screen.back[y * @width + x]
  end

  def build(&) : Nil
    @root = Ori::Box.new
    @root.rect = Ori::Rect.new(0, 0, @width, @height)
    with @root yield
    layout
  end

  def layout : Nil
    @root.layout
    @focus.update(@root)
  end

  def render : Nil
    @screen.clear
    @root.render_screen(@screen)
    render_overlays(@root)
  end

  def frame : Nil
    layout
    render
  end

  def key(key : Ori::Key) : Bool
    @focus.handle_key(key)
  end

  def key(code : Ori::Key::Code, text : String = "") : Bool
    key(Ori::Key.new(code: code, text: text))
  end

  def type(text : String) : Nil
    text.each_char { |ch| key(Ori::Key.new(text: ch.to_s)) }
  end

  def tab : Bool
    key(:tab)
  end

  def focus_first : Nil
    @focus.focus_first
  end

  def lines : Array(String)
    (0...@height).map { |y| line(y) }
  end

  def line(y : Int32) : String
    String.build(@width) do |io|
      @width.times do |x|
        io << char_at(x, y)
      end
    end
  end

  def char_at(x : Int32, y : Int32) : Char
    return ' ' if x < 0 || x >= @width || y < 0 || y >= @height
    c = @screen.back[y * @width + x]
    c.char == '\0' ? ' ' : c.char
  end

  def text_at(x : Int32, y : Int32, len : Int32 = @width - x) : String
    String.build(len) do |io|
      len.times do |i|
        io << char_at(x + i, y)
      end
    end
  end

  def text : String
    lines.join("\n")
  end

  def include?(text : String) : Bool
    lines.any? { |l| l.includes?(text) }
  end

  private def render_overlays(node : Ori::Node) : Nil
    node.render_overlay(@screen)
    if node.is_a?(Ori::Box)
      node.children.each { |c| render_overlays(c) }
    end
  end
end
