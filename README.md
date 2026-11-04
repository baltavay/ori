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

Callbacks (`on_change`, `on_select`, `on_press`, ...) may return anything — the
return value is discarded, so a lambda body has no trailer to remember. The
widget sees a `Proc(..., Nil)`; `Ori::DSL.wrap` adapts it.

### Text

```crystal
text "Hello", fg: "#cdd6f4", bold: true, dim: false, align: :left
```

### Input

```crystal
input(value: @name, placeholder: "Name...", border: true, on_change: ->(v : String) { @name = v })
```

### Text Area

Multi-line text editor. `on_change` receives `(value, cursor_row, cursor_col)`.

```crystal
area(value: @bio, on_change: ->(v : String, r : Int32, c : Int32) { @bio = v; @row = r; @col = c })
```

### Dropdown / Select

```crystal
dropdown(options: ["Red", "Green", "Blue"], selected: @color_idx,
  on_change: ->(i : Int32) { @color_idx = i })
```

### List

Full-featured list with cursor, scroll, checkable items.

```crystal
list(items: [Ori::List::Item.new("Item 1"), Ori::List::Item.new("Item 2")],
  on_select: ->(i : Int32) { puts i })
```

### Table

```crystal
table(headers: ["Name", "Age"], rows: [["Alice", "30"], ["Bob", "25"]],
  selected_row: @row, on_change: ->(i : Int32) { @row = i })
```

### Radio Group

Focused group: up/down move the selection and fire `on_change`; `enter`/`space`
fire it again for the current row. Add `focusable: true` to let the group take
focus (the individual radios then never take focus themselves).

```crystal
radio_group(labels: ["Small", "Medium", "Large"], selected: @size,
  focusable: true, on_change: ->(i : Int32) { @size = i })
```

### Date Picker

```crystal
date_picker(year: 2025, month: 6, day: 15, border: true,
  on_change: ->(t : Time) { @date = t })
```

### DateTime Picker

```crystal
datetime_picker(year: 2025, hour: 14, minute: 30, border: true,
  on_change: ->(t : Time) { @dt = t })
```

### File Picker

Interactive directory browser. Navigates with j/k, enter to select, backspace/h to go up.

```crystal
file_picker(flex: 1, on_select: ->(path : String) { @selected = path })
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

### Canvas

Sub-cell drawing surface for shapes and motion: every terminal cell holds a 2x2
pixel grid that is composited as block characters (`▀`, `▚`, `▛`), so a drawing
gets twice the resolution of a glyph-per-cell one.

```crystal
canvas(width: 20, height: 10) do |c|
  c.clear("#1e1e2e")                            # opaque background
  c.fill_rect(3.4, 2.0, 12.0, 6.0, "#89b4fa")   # pixel coordinates
  c.bitmap(4, 4, ["#.#", ".#."], "#cdd6f4")     # one character per pixel
end
```

Coordinates are pixels, not cells — `fill_rect(3.4, ...)` lands on a different
sub-cell than `fill_rect(3.0, ...)`. `bitmap` paints one bitmap character per
pixel (pixel-art text, as `examples/canvas_form.cr` does for a whole form);
`text` writes ordinary characters into a cell layer that is composited over the
pixels, for widgets that need readable labels on top of canvas chrome.

A cell can only show two colours, so a painted cell is split into its dominant
fill colour and the mark drawn over it; cells the canvas never touched stay
transparent and leave the widget beneath visible (pass a colour to `clear` to
make it opaque). Pass `sub_x: 1, sub_y: 2` for half blocks or `sub_x: 1,
sub_y: 1` for plain cells if your terminal font has no quadrant glyphs.

`fill_rect` is a hard edge: a box at `x = 3.0` and one at `x = 3.4` paint the
same pixels, so slow motion snaps from pixel to pixel. A cell also holds only
two colours, so a sub-pixel step has very few shades to spend — position alone
cannot look smooth. Blend the boundary pixels by the fraction of them the shape
covers, fade the border over a couple of pixels and/or animate a palette ramp
across the face (`examples/plasma.cr`). Keep text on whole pixels at full
strength: a blended edge on a one-pixel stroke changes brightness every frame
and reads as flicker.

A hard silhouette still flips whole cells when it crosses one. To move without
any flipping, drop the edge entirely: sample a continuous field at each cell's
four quadrant centres and paint the means of the two halves —
`examples/bounce.cr` writes its cells straight into `Screen` this way (no
`Canvas`), so a fifth of a cell of movement changes hundreds of cells by a few
RGB levels.

### Viewport

Scrollable text viewer with soft-wrap and mouse wheel support. Soft wrap follows
the width the layout gives it, so a resize re-wraps the content.

```crystal
viewport(content: long_text, on_scroll: ->(y : Int32) { @scroll_y = y })
```

### Markdown

Renders markdown content with syntax highlighting.

```crystal
markdown(content: "# Hello\nWorld", on_scroll: ->(y : Int32) { @scroll_y = y })
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

## Animation

`start_tick` runs a block every `interval` and marks the app dirty, so the value
it changes is on screen next frame:

```crystal
def on_start : Nil
  start_tick(500.milliseconds) { @blink = !@blink }
end
```

Timing-sensitive state (springs, physics, easing) should not read the clock
itself: `start_tick_with_elapsed` hands the block the real seconds since the
previous call, and `Ori::Spring::Clock` turns that into whole fixed-size steps
(4 ms) plus a remainder carried into the next frame. The state is then the same
however frames are divided, and a stalled frame snaps instead of replaying the
backlog:

```crystal
def on_start : Nil
  start_tick_with_elapsed(16.milliseconds) do |dt|
    schedule = @clock.take(dt)                     # Ori::Spring::Clock
    @pos, @vel = Ori::Spring.apply(schedule, @pos, @vel, @target, 5.0, 0.5)
  end
end
```

`frequency` is the angular frequency (higher = faster) and `damping` the ratio:
below 1 overshoots, 1 is critically damped, above 1 crawls in.
`Ori::Spring.update(pos, vel, target, frequency, damping, dt)` is the single-step
form. See `examples/spring.cr`, `examples/bounce.cr`, `examples/plasma.cr`.

## Input Handling

Override `on_key` for app-level keys. Return `true` when the key was handled —
focus dispatch is then skipped and the app is marked dirty:

```crystal
def on_key(key : Ori::Key) : Bool
  case key.text
  when "q" then @running = false; true
  else false
  end
end
```

`handle_key` is the lower-level hook: it runs on every key *before* the focused
widget sees it, and returns `false` to let focus dispatch continue. Override it
only to intercept keys the focused widget would otherwise consume.

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
# basics
crystal run examples/hello.cr
crystal run examples/counter.cr
crystal run examples/help.cr
crystal run examples/pages.cr

# widgets
crystal run examples/tabs.cr
crystal run examples/button.cr
crystal run examples/checkbox.cr
crystal run examples/radio.cr
crystal run examples/slider.cr
crystal run examples/select.cr
crystal run examples/list.cr
crystal run examples/table.cr
crystal run examples/tree.cr
crystal run examples/form.cr
crystal run examples/date_picker.cr
crystal run examples/datetime_picker.cr
crystal run examples/file_picker.cr
crystal run examples/editor.cr
crystal run examples/viewport.cr
crystal run examples/markdown.cr
crystal run examples/progress_bar.cr
crystal run examples/spinner.cr
crystal run examples/sparkline.cr
crystal run examples/toast.cr
crystal run examples/warning.cr

# animation
crystal run examples/stopwatch.cr
crystal run examples/timer.cr
crystal run examples/spring.cr

# graphics
crystal run examples/splash.cr
crystal run examples/bounce.cr
crystal run examples/plasma.cr
crystal run examples/canvas_form.cr

# text UI
crystal run examples/vim.cr
```

## Architecture

Ori uses an **immediate-mode** pattern:

1. Your `App` holds all state
2. `render` is called each frame, building a fresh tree of `Box`/`Node` objects
3. Callbacks (`on_change`, `on_select`, etc.) sync widget state back to your app
4. Use `attach` to reuse stateful nodes (like `FilePicker`, `Viewport`) across rebuilds

The renderer runs at 60 FPS by default (configurable via `@fps`). Each frame
builds a fresh tree; `Screen#flush` diffs it against the previous frame and only
writes the cells that changed, wrapped in a synchronized-update block — a frame
that looks identical to the previous one writes nothing at all.

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
