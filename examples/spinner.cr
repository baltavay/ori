require "../src/ori"

class SpinnerApp < Ori::App
  BG = "#1e1e2e"; FG = "#cdd6f4"; DM = "#6c7086"; MAUVE = "#cba6f7"
  TYPES = [:dots, :line, :arc, :circle, :pipe, :triangle, :bounce, :star]
  @spinners : Array(Ori::Spinner)

  def initialize
    @spinners = TYPES.map { |t| Ori::Spinner.new(type: t, style: Ori::S.new(fg: FG)) }
  end

  def render : Ori::Box
    box height: "100%", direction: :vertical, padding: 2, bg: BG do
      text "Spinner Demo", bold: true, fg: MAUVE
      text ""
      TYPES.each_with_index do |t, i|
        box direction: :horizontal do
          text "  #{t.to_s.ljust(9)} ", fg: DM
          attach @spinners[i]
        end
      end
      text ""
      text "q: quit", fg: DM
    end
  end

  def on_start : Nil
    start_tick(80.milliseconds) { }
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
