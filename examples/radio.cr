require "../src/ori"

BG = "#1e1e2e"; DM = "#6c7086"; MAUVE = "#cba6f7"; GREEN = "#a6e3a1"; YL = "#f9e2af"

class RadioApp < Ori::App
  @selected : Int32 = 0
  @name : String = ""
  @name_cursor : Int32 = 0
  @comment : String = ""
  @comment_cursor : Int32 = 0

  def render : Ori::Box
    box bg: BG, padding: {1, 2} do
      text "Radio Demo", fg: MAUVE, bold: true
      text "Name:", fg: YL
      input value: @name, cursor: @name_cursor, placeholder: "your name",
        focusable: true, border: :single, fg: "#cdd6f4", border_fg: DM,
        on_change: ->(v : String) { @name = v },
        on_cursor: ->(c : Int32) { @name_cursor = c }
      text ""
      text "Choose:", fg: MAUVE
      radio_group labels: ["Option A", "Option B", "Option C"], focusable: true,
        selected: @selected, on_change: ->(i : Int32) { @selected = i }
      text ""
      text "Comment:", fg: YL
      input value: @comment, cursor: @comment_cursor, placeholder: "your comment",
        focusable: true, border: :single, fg: "#cdd6f4", border_fg: DM,
        on_change: ->(v : String) { @comment = v },
        on_cursor: ->(c : Int32) { @comment_cursor = c }
      text ""
      labels = ["Option A", "Option B", "Option C"]
      text "Selected: #{labels[@selected]}", fg: GREEN
      text "tab: navigate  ↑/↓: radio group  ctrl+c: quit", fg: DM
    end
  end

  def on_key(key : Ori::Key) : Bool
    if key.ctrl && key.text == "c"
      @running = false; true
    else
      false
    end
  end
end

RadioApp.run
