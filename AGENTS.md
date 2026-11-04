# ori — agent quick-start

Crystal TUI framework. Immediate-mode: App holds state, `render` builds the tree every frame (60 fps by default); `Screen#flush` diffs the frame against the previous one and writes only changed cells, so a frame with no visible change emits nothing.

## Commands

```bash
crystal spec                    # run all 851 tests
crystal build examples/X.cr -o /tmp/x && /tmp/x   # run example
crystal run examples/X.cr       # run w/o building
```

## App vs Page

- **App subclass**: `def initialize` (no args), call `super`, optionally `push_page(MyPage.new(self))`
- **Page subclass**: `def initialize(app : Ori::App)`, must call `super(app)`
- Page gets: own focus manager, bindings, `on_enter`/`on_exit` hooks. App delegates to current_page.

## Key handling

- `on_key(key) : Bool` — return `true` = handled (skips focus dispatch), `false` = falls through to focus
- `on_key` returning `true` auto-sets `@dirty = true`
- Ctrl+C quit is built into `handle_key` before dispatch
- Simple apps without pages: override `on_key` directly on App

## Gotchas

- **Callbacks**: every `on_*` callback is accepted with any return type and wrapped by `Ori::DSL.wrap` into `Proc(..., Nil)`; no `; nil` trailer is needed (widgets stored directly still take a `Proc(..., Nil)`)
- **`@running`**: protected setter. Use `self.running = false` from subclasses, or `app.quit`
- **`attach` required**: widgets with internal state (FilePicker, Viewport, Spinner, Select, DatePicker, ProgressBar, ...) must be stored as ivars and `attach`ed in render — otherwise state resets each frame
- **`on_start`**: after initial render, before event loop. Start ticks here, not in `initialize`
- **`start_tick`**: spawns fiber, sets `@dirty = true` after block call
- **`start_tick_with_elapsed`**: same loop, but the block gets the wall-clock seconds since its last call (a block's parameter count isn't part of overload resolution, so it's a separate method). Feed it to `Ori::Spring::Clock#take` + `Ori::Spring.apply` to advance springs in fixed 4 ms steps that don't depend on the frame rate; past `MAX_STEPS` (300) a spring snaps onto its target. `Ori::Spring.update` is the single-step form
- **Frame ≠ redraw**: `Screen#flush` emits zero bytes for a frame identical to the previous one, so measuring animation by frame count overcounts unless you count `\e[?2026h` sync blocks on the wire

## Harness / AI mode

```crystal
Ori::Harness.new(MyApp, width: 80, height: 24).tap { |h| h.frame; puts h.state_json }
h.step("j")  # press key, get before/after state
```

App flags: `--json` (dump state once), `--headless` (interactive: keys in, JSON out)

## Style

- Colors: `#rrggbb` hex strings
- `Ori::S.new(fg:, bg:, bold:, dim:, border:, padding:, ...)` — all widgets accept style kwargs
- Box direction defaults to `:vertical`

## Canvas (sub-cell drawing)

`Ori::Canvas` draws on a raster finer than the cell grid: `sub_x`x`sub_y` pixels
per cell (default 2x2), composited by `blit` into block characters.

```crystal
canvas(width: 20, height: 10) do |c|          # widget, redraws every frame
  c.clear("#1e1e2e")                           # opaque background
  c.fill_rect(3.4, 2.0, 12.0, 6.0, "#89b4fa")  # pixel coordinates
  c.bitmap(4, 4, ["#.#"], "#cdd6f4")           # '#' = ink, rest skipped
end
```

- Coordinates are **pixels**, not cells: multiply cell geometry by `sub_x`/`sub_y`.
- A cell shows two colours. A fully painted cell is split into its most common
  colour (background) and the mark drawn over it (foreground); partly painted
  cells use the canvas background behind the ink.
- Untouched cells are transparent and keep whatever is already on the screen.
- `c.bitmap(x, y, rows, color)` paints pixel text (one bitmap char per canvas
  pixel); `c.text(cx, cy, "label", fg, bg)` writes real characters into a cell
  layer drawn over the pixels, inheriting the colour painted underneath.
- Only use it for geometry (borders, shadows, bars, animation). Text stays on
  the normal cell grid — a font glyph cannot be split across cells.
- Quadrants are U+2596-U+259F; if a terminal font lacks them, construct the
  canvas (or node) with `sub_x: 1, sub_y: 2` (half blocks) or `1, 1` (plain).
- `fill_rect` samples pixel centres, so it is a hard edge: `x = 3.0` and
  `x = 3.4` paint the same pixels. Slow motion has to move in colour: blend the
  boundary pixels by their coverage and/or animate a palette ramp across the
  face (`examples/plasma.cr`). Keep text on whole pixels at full strength — a
  blended stroke flickers.
- A hard silhouette still flips whole cells (2 colours per cell, so a crossing
  cannot be shown as a small change). For motion that never flips, drop the
  edge: sample a continuous field at each cell's four quadrant centres and paint
  the *means* of the two halves, only splitting when they differ by more than a
  contrast threshold — `examples/bounce.cr` builds its cells directly on
  `Screen` that way (no `Canvas`), which is why a fifth of a cell of movement
  changes hundreds of cells by a few RGB levels.
- `canvas(...)` inside `box do ... end` needs `Ori::Box#canvas` (the DSL method
  alone returns a node without attaching it). Node trees have no z-order: a
  canvas cannot be drawn *behind* siblings, so a widget that wants chrome under
  its own text blits the canvas and then writes the text in its own
  `render_screen`.

## Tests

- Standard Crystal spec in `spec/`
- `spec_helper.cr` requires `../src/ori`
- Tests for edge cases (empty lists, zero-height viewports, etc.) in `verify_bugs_spec.cr`
- Spring tests in `spring_spec.cr`
