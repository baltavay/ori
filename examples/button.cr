require "../src/ori"

BG = "#1e1e2e"; DM = "#6c7086"; MAUVE = "#cba6f7"
GREEN = "#a6e3a1"

class ButtonApp < Ori::App
  @clicks : Int32 = 0; @last_variant : Symbol = :default

  def render : Ori::Box
    box bg: BG, padding: {1, 2} do
      text "Button Demo", fg: MAUVE, bold: true
      box padding: {1, 0} do
        button label: "Click me", variant: :primary, focusable: true,
          on_press: -> { @clicks += 1; @last_variant = :primary }
        button label: "Save", variant: :success, focusable: true,
          on_press: -> { @clicks += 1; @last_variant = :success }
        button label: "Delete", variant: :danger, focusable: true,
          on_press: -> { @clicks += 1; @last_variant = :danger }
      end
      text "Clicked #{@clicks} times (last: #{@last_variant})", fg: GREEN
      text "tab: navigate  enter/space: click  ctrl+c: quit", fg: DM
    end
  end

  def on_key(key : Ori::Key) : Bool
    if key.ctrl && key.text == "c"; @running = false; true else false end
  end
end

ButtonApp.run
