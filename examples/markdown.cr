require "../src/ori"

class MarkdownApp < Ori::App
  @y_offset : Int32 = 0

  def render : Ori::Box
    box height: "100%", direction: :vertical do
      box padding: {0, 1} do
        text "Markdown Renderer", bold: true, fg: "#cba6f7"
        text "  j/k/arrows: scroll  pgup/pgdn: page  g/G: top/bottom  q: quit", fg: "#6c7086"
      end

      markdown(
        content: MD,
        focusable: true,
        flex: 1,
        y_offset: @y_offset,
        on_scroll: ->(y : Int32) { @y_offset = y; nil },
      )
    end
  end

  def on_key(key : Ori::Key) : Bool
    if (key.ctrl && key.text == "c") || key.text == "q"
      @running = false; return false
    end
    if fm = @focus
      fm.handle_key(key)
      rebuild
    end
    false
  end

  MD = <<-TEXT
  # Ori Markdown Renderer

  This is a demonstration of the **Ori** markdown widget.
  It supports styled rendering with scroll, keyboard and mouse.

  ## Features

  - Headings (h1, h2, h3)
  - Unordered lists with bullets
  - Numbered lists
  - Blockquotes
  - Code blocks with syntax highlighting
  - Horizontal rules
  - Scrollable with keyboard and mouse

  ## Code Example

  ```
  class MyWidget < Ori::Node
    def render_screen(screen)
      screen.put(0, 0, 'H', fg: "#cba6f7")
    end
  end
  ```

  ## Architecture

  The framework uses an immediate-mode composite tree pattern.
  On each render cycle, the entire widget tree is rebuilt from
  the App's render method.

  The Screen maintains front/back buffers and only flushes the
  diff to the terminal, achieving efficient 60fps updates.

  ## Blockquote

  > The best way to predict the future is to invent it.
  > -- Alan Kay

  > Any sufficiently advanced technology is indistinguishable
  > from magic.
  > -- Arthur C. Clarke

  ## Numbered List

  1. First item
  2. Second item
  3. Third item
  4. Fourth item
  5. Fifth item

  ## More Code

  ```
  class MyApp < Ori::App
    def render : Ori::Box
      box height: "100%", direction: :vertical do
        text "Hello World", bold: true, fg: "#cba6f7"
        input placeholder: "Type here...", focusable: true,
          on_change: ->(v : String) { @name = v; nil }
      end
    end
  end

  MyApp.run
  ```

  ## Widgets

  - Box: Container with vertical/horizontal layout
  - Text: Styled text with formatting
  - Input: Single-line text input
  - Area: Multi-line text editor
  - List: Selectable item list
  - Table: Data table with columns
  - Viewport: Scrollable text content
  - Markdown: This widget you're looking at
  - FilePicker: Directory browser
  - Sparkline: Mini chart visualization
  - Help: Keybinding display
  - ProgressBar: Animated progress indicator
  - Spinner: Loading animation
  - Select: Dropdown picker
  - DatePicker: Calendar date selection
  - DateTimePicker: Calendar + time selection
  - Paginator: Page calculator

  ---

  End of markdown content. Scroll up to review.
  TEXT
end

MarkdownApp.run
