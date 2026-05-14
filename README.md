# ori

A component-based TUI framework for Crystal. Immediate-mode architecture — state lives in your `App`, `render` builds the tree each frame, callbacks sync back.

## Install

Add to `shard.yml`:

```yaml
dependencies:
  ori:
    github: baltavay/ori
```

## Quick Start

```crystal
require "ori"

class MyApp < Ori::App
  def render : Ori::Box
    box(fg: "#cdd6f4", bg: "#1e1e2e") do
      text "Hello, world!", bold: true
    end
  end
end

MyApp.run
```

## Widgets

### Text

```crystal
text "Hello", fg: "#cdd6f4", bold: true, dim: false, align: :left
```

### Input

```crystal
input(value: @name, placeholder: "Name...", border: true, on_change: ->(v : String) { @name = v; nil })
```

### Text Area

Multi-line text editor. `on_change` receives `(value, cursor_row, cursor_col)`.

```crystal
area(value: @bio, on_change: ->(v : String, r : Int32, c : Int32) { @bio = v; @row = r; @col = c; nil })
```

### Dropdown / Select

```crystal
dropdown(options: ["Red", "Green", "Blue"], selected: @color_idx,
  on_change: ->(i : Int32) { @color_idx = i; nil })
```

### List

Full-featured list with cursor, scroll, checkable items.

```crystal
list(items: [Ori::List::Item.new("Item 1"), Ori::List::Item.new("Item 2")],
  on_select: ->(i : Int32) { puts i; nil })
```

### Table

```crystal
table(headers: ["Name", "Age"], rows: [["Alice", "30"], ["Bob", "25"]],
  selected_row: @row, on_change: ->(i : Int32) { @row = i; nil })
```

### Date Picker

```crystal
date_picker(year: 2025, month: 6, day: 15, border: true,
  on_change: ->(t : Time) { @date = t; nil })
```

### DateTime Picker

```crystal
datetime_picker(year: 2025, hour: 14, minute: 30, border: true,
  on_change: ->(t : Time) { @dt = t; nil })
```

### File Picker

Interactive directory browser. Navigates with j/k, enter to select, backspace/h to go up.

```crystal
file_picker(flex: 1, on_select: ->(path : String) { @selected = path; nil })
```

### Progress Bar

```crystal
progress_bar(value: 50.0, max: 100.0, gradient_to: "#89b4fa")
```

### Spinner

```crystal
spinner(type: :dots)
```

### Sparkline

```crystal
sparkline(data: [1.0, 3.0, 2.0, 5.0], max: 10.0)
```

### Viewport

Scrollable text viewer with soft-wrap and mouse wheel support.

```crystal
viewport(content: long_text, on_scroll: ->(y : Int32) { @scroll_y = y; nil })
```

### Markdown

Renders markdown content with syntax highlighting.

```crystal
markdown(content: "# Hello\nWorld", on_scroll: ->(y : Int32) { nil })
```

### Help

Keybinding reference display.

```crystal
help(bindings: [Ori::HelpBinding.new("j/k", "navigate"), Ori::HelpBinding.new("q", "quit")])
```

## Layout

### Box

Container for children. Supports vertical (default) and horizontal direction.

```crystal
box(border: true, padding: 1, direction: :vertical, fg: "#cdd6f4", bg: "#1e1e2e") do
  text "Row 1"
  text "Row 2"
end
```

### Flex

Distribute remaining space with `flex: N`.

```crystal
box(direction: :horizontal) do
  text "Sidebar", width: 20
  box(flex: 1) { text "Main content" }
end
```

### Scrollable

```crystal
box(scrollable: true, height: 10) do
  50.times { |i| text "Line #{i + 1}" }
end
```

Keys: j/k scroll, f/b page down/up, g/G top/bottom.

### Attach

Reuse a node across rebuilds (preserves internal state like cursor position).

```crystal
class MyApp < Ori::App
  @picker : Ori::FilePicker

  def initialize
    @picker = Ori::FilePicker.new(on_select: ->(path : String) { nil })
  end

  def render : Ori::Box
    box do
      attach @picker
    end
  end
end
```

## Style Options

All widgets accept these style kwargs:

| Option | Type | Description |
|---|---|---|
| `fg` | `String?` | Foreground color (`#rrggbb`) |
| `bg` | `String?` | Background color |
| `bold` | `Bool` | Bold text |
| `dim` | `Bool` | Dim text |
| `border` | `Bool/Symbol` | `:single`, `:double`, `:rounded`, `:thick` |
| `border_fg` | `String?` | Border color |
| `padding` | `Int/Tuple` | Padding (1, {2,3}, or {1,2,3,4}) |
| `width` | `Int/String` | Fixed width or `"50%"` |
| `height` | `Int/String` | Fixed height or `"30%"` |
| `flex` | `Int` | Flex grow factor |
| `direction` | `Symbol` | `:vertical` (default) or `:horizontal` |
| `align` | `Symbol` | `:left`, `:center`, `:right` |
| `focusable` | `Bool` | Receive keyboard focus |
| `scrollable` | `Bool` | Enable scroll on box |
| `gradient_to` | `String?` | Gradient end color |

## Input Handling

Override `handle_key` in your app for custom key bindings:

```crystal
def handle_key(key : Ori::Key) : Bool
  if key.text == "q"
    @running = false
    return false
  end
  super
end
```

`Ori::Key` has `text : String?`, `code : Ori::Key::Code` (with predicates like `up?`, `down?`, `enter?`, `tab?`, etc.), and `ctrl`/`shift`/`alt` modifiers.

## Mouse Support

Mouse events are enabled by default. Override `on_mouse` for custom handling:

```crystal
def on_mouse(mouse : Ori::Mouse) : Bool
  if mouse.action.press? && mouse.button.left?
    # handle click at mouse.x, mouse.y
  end
  false
end
```

`Ori::Mouse::Action`: `Press`, `Release`, `Wheel`. `Ori::Mouse::Button`: `Left`, `Middle`, `Right`, `WheelUp`, `WheelDown`.

## Navigation

- **Tab** / **Shift+Tab** — cycle focus
- **Enter** — activate/confirm
- **Esc** — cancel/close overlay
- **Ctrl+C** — quit

## Examples

```
crystal run examples/hello.cr
crystal run examples/counter.cr
crystal run examples/form.cr
crystal run examples/table.cr
crystal run examples/select.cr
crystal run examples/date_picker.cr
crystal run examples/datetime_picker.cr
crystal run examples/progress_bar.cr
crystal run examples/spinner.cr
crystal run examples/sparkline.cr
crystal run examples/file_picker.cr
crystal run examples/markdown.cr
crystal run examples/viewport.cr
crystal run examples/editor.cr
crystal run examples/vim.cr
crystal run examples/todo/main.cr
crystal run examples/stopwatch.cr
crystal run examples/timer.cr
crystal run examples/splash.cr
crystal run examples/bounce.cr
```

## Architecture

Ori uses an **immediate-mode** pattern:

1. Your `App` holds all state
2. `render` is called each frame, building a fresh tree of `Box`/`Node` objects
3. Callbacks (`on_change`, `on_select`, etc.) sync widget state back to your app
4. Use `attach` to reuse stateful nodes (like `FilePicker`, `Viewport`) across rebuilds

The renderer runs at 60 FPS by default (configurable via `@fps`). The screen does a full redraw each frame — no diffing, no artifacts.

## Requirements

- Crystal >= 1.19.1
- Unix-like OS (uses termios for raw terminal mode)

## Development

```bash
# Run specs
crystal spec

# Build an example
crystal build examples/hello.cr -o /tmp/hello && /tmp/hello

# Build all examples
for f in examples/*.cr examples/*/main.cr; do crystal build "$f" -o /tmp/ori_ex; done
```

## Contributing

1. Fork it (<https://github.com/baltavay/ori/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [baltavay](https://github.com/baltavay) — creator and maintainer

## License

MIT — see [LICENSE](LICENSE)
