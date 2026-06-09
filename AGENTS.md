# ori — agent quick-start

Crystal TUI framework. Immediate-mode: App holds state, `render` builds tree every frame (60fps, full redraw, no diffing).

## Commands

```bash
crystal spec                    # run all 805 tests
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

- **Callback procs**: always end with `; nil` — Crystal casts bare return as `Proc(Symbol)` otherwise
- **`@running`**: protected setter. Use `self.running = false` from subclasses, or `app.quit`
- **`attach` required**: widgets with internal state (FilePicker, Viewport, Spinner, Select, DatePicker, etc.) must be stored as ivars and `attach`ed in render — otherwise state resets each frame
- **`on_start`**: after initial render, before event loop. Start ticks here, not in `initialize`
- **`start_tick`**: spawns fiber, sets `@dirty = true` after block call

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

## Tests

- Standard Crystal spec in `spec/`
- `spec_helper.cr` requires `../src/ori`
- Tests for edge cases (empty lists, zero-height viewports, etc.) in `verify_bugs_spec.cr`
- Spring tests in `spring_spec.cr`
