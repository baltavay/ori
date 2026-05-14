require "../src/ori"

class ChartsApp < Ori::App
  @data : Array(Float64)

  def initialize
    @data = (1..40).map { |i| Math.sin(i * 0.3).abs * 10 + rand * 3 }
  end

  def render : Ori::Box
    box height: "100%", direction: :vertical do
      box padding: {0, 1} do
        text "Sparkline Demo", bold: true, fg: "#cba6f7"
        text "  r: randomize  q: quit", fg: "#6c7086"
      end

      box padding: {0, 2}, flex: 1 do
        text "Server Load (40 samples):", fg: "#89b4fa"
        sparkline(
          data: @data,
          height: 8,
          fg: "#a6e3a1",
          flex: 1,
        )
        text ""
        text "Network I/O:", fg: "#89b4fa"
        sparkline(
          data: @data.reverse,
          height: 4,
          fg: "#f38ba8",
          flex: 1,
        )
      end
    end
  end

  def handle_key(key : Ori::Key) : Bool
    if (key.ctrl && key.text == "c") || key.text == "q"
      @running = false
      return false
    end
    if key.text == "r"
      @data = (1..40).map { |i| Math.sin(i * 0.3).abs * 10 + rand * 3 }
      rebuild
    end
    false
  end
end

ChartsApp.run
