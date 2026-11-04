require "../src/ori"

class ViewerApp < Ori::App
  @y_offset : Int32 = 0

  def render : Ori::Box
    box height: "100%", direction: :vertical do
      box padding: {1, 2}, direction: :horizontal do
        text "Viewport Demo", bold: true, fg: "#cba6f7"
        text "  j/k/arrows: scroll  pgup/pgdn: page  g/G: top/bottom  q: quit", fg: "#6c7086"
      end

      viewport(
        content: LOREM,
        focusable: true,
        flex: 1,
        y_offset: @y_offset,
        on_scroll: ->(y : Int32) { @y_offset = y },
      )
    end
  end

  def on_key(key : Ori::Key) : Bool
    if key.ctrl && key.text == "c"
      @running = false; return false
    end
    if key.text == "q"
      @running = false; return false
    end
    if fm = @focus
      fm.handle_key(key)
      rebuild
    end
    false
  end

  LOREM = <<-TEXT
  Ori Framework - Building Terminal UIs in Crystal
  =================================================

  Ori is an immediate-mode TUI framework for Crystal, inspired by
  Bubble Tea, Lip Gloss, and modern component architectures.

  Architecture
  ------------
  The framework uses an immediate-mode composite tree pattern. On each
  render cycle, the entire widget tree is rebuilt from the App's render
  method. The Screen maintains front/back buffers and only flushes the
  diff to the terminal, achieving efficient 60fps updates.

  Components
  ----------
  - Box: Container with vertical/horizontal layout, flex, padding
  - Text: Styled text with bold, dim, underline, strikethrough
  - Input: Single-line text input with placeholder and cursor
  - Area: Multi-line text area for longer content
  - List: Selectable item list with scrollbar and checkable mode
  - Viewport: Scrollable text content with soft wrapping
  - Table: Interactive data table with column sizing
  - Select: Dropdown picker with search and keyboard navigation
  - DatePicker: Calendar popup for date selection
  - DateTimePicker: Calendar + time picker
  - ProgressBar: Animated progress with solid/blocks/gradient styles
  - Spinner: Loading indicator with multiple animation presets

  Layout Engine
  -------------
  The layout is a single-pass constraint solver:
  - Vertical boxes lay children top-to-bottom
  - Horizontal boxes lay children left-to-right
  - Each child sized by: fixed > percentage > flex > auto
  - Remaining space distributed proportionally among flex children

  Styling
  -------
  The StyleArgs struct provides compile-time type safety for all
  style properties: fg, bg, bold, dim, underline, strikethrough,
  border (single/double/rounded/thick), padding, flex, direction,
  align, focusable, scrollable, and more.

  Mouse Support
  -------------
  Full SGR mouse protocol support including:
  - Click, release, motion, and wheel events
  - Modifier key detection (ctrl, alt, shift)
  - Rect-based hit testing for all interactive widgets
  - List and Select respond to mouse clicks and scroll

  Shadow DOM
  ----------
  The Screen class maintains front/back cell buffers. On each frame,
  only cells that changed are written to the terminal. This is the
  equivalent of a shadow DOM - the framework always renders at the
  configured FPS (default 60) but only flushes the minimal diff.

  DSL
  ---
  The block-based DSL makes building UIs natural:

    box padding: 2, direction: :vertical do
      text "Hello!", bold: true, fg: "#cba6f7"
      input value: @name, placeholder: "Name...", focusable: true,
        on_change: ->(v : String) { @name = v }
    end

  This creates a vertical box with padding, containing a bold heading
  and a text input. The DSL is fully type-checked at compile time.

  Comparison with Crubbletea
  --------------------------
  Crubbletea uses the Elm Architecture (Model/Update/View) with
  string-based rendering. Ori uses an immediate-mode composite tree
  with cell-based Screen rendering.

  Ori advantages:
  - 2x smaller codebase
  - Block-based DSL (more natural than string concatenation)
  - Cell-grid rendering with automatic diff flushing
  - Built-in layout engine (flex, percentages, auto-sizing)
  - Clean overlay system for dropdowns and popups

  Crubbletea advantages:
  - 3x more widgets (charts, file picker, viewport, timer)
  - 4.5x more tests and examples
  - Immutable style builder pattern
  - Structured message passing scales better for complex apps

  Getting Started
  ---------------
  1. Create a class that inherits from Ori::App
  2. Implement the render method, returning a Box
  3. Call YourApp.run

  That's it. The framework handles terminal setup, event loop,
  rendering, and cleanup automatically.

  Chapter 1: The Box Model
  -------------------------
  Every UI in Ori starts with a Box. Boxes can be nested, and each
  box controls the layout of its children. The direction property
  determines whether children are laid out vertically or horizontally.

  Flex boxes expand to fill remaining space. Fixed-size boxes take
  exactly the space specified. Percentage boxes take a fraction of
  the parent. Auto-sized boxes measure their content.

  Padding adds space inside the box, between the border and content.
  Border can be single, double, rounded, or thick. Border color is
  controlled independently from text color.

  Chapter 2: Text and Styling
  ----------------------------
  The text node renders a string with optional styling. All style
  properties are compile-time checked through the StyleArgs struct.

  Foreground and background colors use hex notation (#rrggbb). Text
  can be bold, dim, underlined, or strikethrough. These properties
  can be combined.

  Chapter 3: Input Handling
  --------------------------
  Interactive widgets accept focus. The FocusManager tracks a ring
  of focusable nodes. Tab/Shift+Tab cycles through them.

  Each widget handles its own keys via the on_key method. The App
  can also override handle_key for global shortcuts.

  Mouse events are dispatched to the correct widget via rect-based
  hit testing. Widgets that respond to mouse implement the on_mouse
  method.

  Chapter 4: Custom Widgets
  --------------------------
  To create a custom widget, inherit from Ori::Node and implement:
  - content_height : Int32
  - content_width : Int32
  - render(io) : Nil (IO-based, optional)
  - render_screen(screen) : Nil (Screen-based, recommended)

  Optionally implement:
  - on_key(key) : Bool for keyboard interaction
  - on_mouse(mouse) : Bool for mouse interaction
  - focusable? : Bool to accept focus
  - render_overlay(screen) for popup content

  Chapter 5: Animation
  ---------------------
  Use start_tick to create timed animations:

    start_tick(100.milliseconds) do
      @frame += 1
      rebuild
    end

  The Spinner and ProgressBar widgets demonstrate animation patterns.
  They update internal state on each tick and rebuild the tree.

  End of content. Scroll up to review.
  TEXT
end

ViewerApp.run
