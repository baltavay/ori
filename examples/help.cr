require "../src/ori"

AC = "#cba6f7"; FG = "#cdd6f4"; BG = "#1e1e2e"; DM = "#6c7086"; GR = "#a6e3a1"

class HelpApp < Ori::App
  def render : Ori::Box
    bindings = [
      Ori::HelpBinding.new(["j/k"], "j/k", "scroll"),
      Ori::HelpBinding.new(["f/b"], "f/b", "page down/up"),
      Ori::HelpBinding.new(["g/G"], "g/G", "top/bottom"),
      Ori::HelpBinding.new(["q"], "q", "quit"),
    ]
    box bg: BG, padding: {1, 2} do
      text "Help Demo", bold: true, fg: AC
      help bindings: bindings, show_all: true
      text ""
      help bindings: bindings, show_all: false
      text "ctrl+c: quit", fg: DM
    end
  end

  def on_key(key : Ori::Key) : Bool
    if key.ctrl && key.text == "c"; @running = false; true else false end
  end
end

HelpApp.run
