# AI-friendly headless harness for Ori apps.
# Lets an AI run any Ori app, inspect state, and step through interactions.
#
# Usage:
#   h = Ori::Harness.new(MyApp, width: 80, height: 24)
#   h.frame
#   puts h.state_json               # full TUI state as JSON
#   h.step("j")                     # press a key, see what changed
#   puts h.focused_node             # currently focused widget
class Ori::Harness
  getter harness : Ori::TestHarness
  getter app : Ori::App

  def initialize(app_class : Ori::App.class, width : Int32 = 80, height : Int32 = 24)
    @app = app_class.new
    @harness = Ori::TestHarness.new(width, height)
  end

  def frame : Nil
    root = @app.render
    root.rect = Ori::Rect.new(0, 0, @harness.width, @harness.height)
    @harness.root = root
    @harness.layout
    @harness.render
  end

  # Full state including screen, widget tree, focus, bindings
  def state
    s = @harness.state
    bindings = @app.bindings
    # Convert to named tuple with bindings
    {
      screen: s[:screen],
      widget_tree: s[:widget_tree],
      focus: s[:focus],
      width: s[:width],
      height: s[:height],
      bindings: bindings,
    }
  end

  # Full state as JSON
  def state_json : String
    s = state
    focus = s[:focus]
    focus_str = focus ? "\"focus\": #{hash_to_json(focus)}" : "\"focus\": null"
    lines = s[:screen].map { |l| "\"#{escape_json(l)}\"" }.join(",\n    ")
    b = s[:bindings]
    bindings_str = b.keys.map { |k| "\"#{escape_json(k)}\": \"#{escape_json(b[k])}\"" }.join(", ")
    String.build do |io|
      io << "{\n"
      io << "  \"width\": #{s[:width]},\n"
      io << "  \"height\": #{s[:height]},\n"
      io << "  \"widget_tree\": \"#{escape_json(s[:widget_tree])}\",\n"
      io << "  #{focus_str},\n"
      io << "  \"bindings\": {#{bindings_str}},\n"
      io << "  \"screen\": [\n    #{lines}\n  ]\n"
      io << "}"
    end
  end

  def step(key : Ori::Key)
    before = state
    unless @app.on_key(key)
      @harness.key(key)
    end
    frame
    after = state
    {"before" => before, "after" => after}
  end

  def step(text : String)
    step(Ori::Key.new(text: text))
  end

  def step(code : Ori::Key::Code)
    step(Ori::Key.new(code: code))
  end

  def focused_node : Ori::Node?
    @harness.focused_node
  end

  def screen_lines : Array(String)
    @harness.lines
  end

  private def hash_to_json(h : Hash(String, String)) : String
    pairs = h.map { |k, v| "\"#{k}\": \"#{escape_json(v)}\"" }.join(", ")
    "{#{pairs}}"
  end

  private def escape_json(s : String) : String
    s.gsub("\\", "\\\\\\\\").gsub("\"", "\\\"").gsub("\n", "\\n")
  end
end
