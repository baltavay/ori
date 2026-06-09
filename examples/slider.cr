require "../src/ori"

BG = "#1e1e2e"; DM = "#6c7086"; MAUVE = "#cba6f7"; GREEN = "#a6e3a1"

class SliderApp < Ori::App
  @volume : Float64 = 50.0; @brightness : Float64 = 80.0

  def render : Ori::Box
    box bg: BG, padding: {1, 2} do
      text "Slider Demo", fg: MAUVE, bold: true
      box padding: {1, 0} do
        text "Volume: #{@volume.round}", fg: GREEN
        slider min: 0.0, max: 100.0, value: @volume, step: 1.0, focusable: true,
          on_change: ->(v : Float64) { @volume = v }
        text "Brightness: #{@brightness.round}", fg: GREEN
        slider min: 0.0, max: 100.0, value: @brightness, step: 5.0, focusable: true,
          on_change: ->(v : Float64) { @brightness = v }
      end
      text "h/l: adjust  g/G: min/max  tab: switch  ctrl+c: quit", fg: DM
    end
  end

  def on_key(key : Ori::Key) : Bool
    if key.ctrl && key.text == "c"; @running = false; true else false end
  end
end

SliderApp.run
