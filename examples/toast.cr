require "../src/ori"

AC = "#cba6f7"; FG = "#cdd6f4"; BG = "#1e1e2e"; DM = "#6c7086"; GR = "#a6e3a1"
YL = "#f9e2af"; RD = "#f38ba8"

class ToastApp < Ori::App
  def render : Ori::Box
    box bg: BG, padding: {1, 2} do
      text "Toast Demo", bold: true, fg: AC
      text ""
      toast message: "File saved successfully", variant: :success
      toast message: "Connection lost", variant: :error
      toast message: "New update available", variant: :info
      toast message: "Check your settings", variant: :warning
      text ""
      text "Toasts are non-focusable display-only widgets", fg: DM
      text "ctrl+c: quit", fg: DM
    end
  end

  def on_key(key : Ori::Key) : Bool
    if key.ctrl && key.text == "c"; @running = false; true else false end
  end
end

ToastApp.run
