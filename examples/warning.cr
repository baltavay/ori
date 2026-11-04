require "../src/ori"

class WarningApp < Ori::App
  RED = "#cba6f7"
  BG = "#1e1e2e"
  @visible : Bool = true

  def on_start : Nil
    start_tick(500.milliseconds) do
      @visible = !@visible
      rebuild
    end
  end

  def render : Ori::Box
    box height: "100%", direction: :vertical, align: :center, valign: :center, bg: BG do
      if @visible
        box border: :double, border_fg: RED, padding: {1, 4} do
          text "WARNING!", fg: RED, bold: true
        end
      end
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

WarningApp.run
