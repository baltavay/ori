require "../src/ori"

class HelloApp < Ori::App
  BG = "#1e1e2e"; FG = "#cdd6f4"; DM = "#6c7086"; MAUVE = "#cba6f7"

  def render : Ori::Box
    box height: "100%", direction: :vertical, padding: 2, bg: BG do
      text "Hello, p!", bold: true, fg: MAUVE
      text ""
      text "This is a TUI framework.", fg: FG
      text ""
      text "Press q to quit.", fg: DM
    end
  end

  def on_key(key : Ori::Key) : Bool
    if key.text == "q"
      @running = false; true
    else
      super
    end
  end
end

HelloApp.run
