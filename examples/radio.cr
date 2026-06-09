require "../src/ori"

BG = "#1e1e2e"; DM = "#6c7086"; MAUVE = "#cba6f7"; GREEN = "#a6e3a1"

class RadioApp < Ori::App
  @selected : Int32 = 0

  def render : Ori::Box
    box bg: BG, padding: {1, 2} do
      text "Radio Demo", fg: MAUVE, bold: true
      box padding: {1, 0} do
        text "Choose:", fg: DM
        radio_group labels: ["Option A", "Option B", "Option C"],
          selected: @selected, on_change: ->(i : Int32) { @selected = i }
      end
      labels = ["Option A", "Option B", "Option C"]
      text "Selected: #{labels[@selected]}", fg: GREEN
      text "ctrl+c: quit", fg: DM
    end
  end

  def on_key(key : Ori::Key) : Bool
    if key.ctrl && key.text == "c"; @running = false; true else false end
  end
end

RadioApp.run
