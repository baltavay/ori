require "../src/ori"

class EditorApp < Ori::App
  @text : String
  @cursor_row : Int32 = 0
  @cursor_col : Int32 = 0

  def initialize
    @text = "Welcome to the Ori Text Editor!\n\nTry editing this text.\nUse arrow keys to navigate.\nCtrl+a: home  Ctrl+e: end\nAlt+left/right: word jump\nAlt+backspace: delete word\nCtrl+k: kill to end  Ctrl+u: kill to start\nCtrl+c: quit"
  end

  def render : Ori::Box
    box height: "100%", direction: :vertical do
      box padding: {0, 1}, direction: :horizontal do
        text "Ori Editor", bold: true, fg: "#cba6f7"
        text "  ctrl+c: quit", fg: "#6c7086"
      end

      area(
        value: @text,
        flex: 1,
        focusable: true,
        border: true,
        cursor_row: @cursor_row,
        cursor_col: @cursor_col,
        on_change: ->(v : String, row : Int32, col : Int32) { @text = v; @cursor_row = row; @cursor_col = col },
        on_cursor: ->(row : Int32, col : Int32) { @cursor_row = row; @cursor_col = col },
        show_line_numbers: true,
      )
    end
  end

  def on_key(key : Ori::Key) : Bool
    if key.ctrl && key.text == "c"
      @running = false
      return false
    end
    if fm = @focus
      fm.handle_key(key)
      rebuild
    end
    false
  end
end

EditorApp.run
