require "../src/ori"

class SpinnerApp < Ori::App
  BG = "#1e1e2e"; FG = "#cdd6f4"; DM = "#6c7086"; MAUVE = "#cba6f7"

  def initialize
    @spinners = [] of Ori::Spinner
  end

  def render : Ori::Box
    @spinners.clear
    box height: "100%", direction: :vertical, padding: 2, bg: BG do
      text "Spinner Demo", bold: true, fg: MAUVE
      text ""
      [:dots, :line, :arc, :circle, :pipe, :triangle, :bounce, :star].each do |t|
        box direction: :horizontal do
          text "  #{t.to_s.ljust(9)} ", fg: DM
          s = spinner type: t, fg: FG
          @spinners << s
        end
      end
      text ""
      text "q: quit", fg: DM
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

SpinnerApp.run
