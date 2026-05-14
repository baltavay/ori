require "../src/ori"

class CounterApp < Ori::App
  BG = "#1e1e2e"; FG = "#cdd6f4"; DM = "#6c7086"; MAUVE = "#cba6f7"
  @count : Int32 = 0

  def render : Ori::Box
    box height: "100%", direction: :vertical, padding: 2, bg: BG do
      text "Counter", bold: true, fg: MAUVE
      text ""
      text "Value: #{@count}", fg: FG, bold: true
      text ""
      text "up/k: inc  down/j: dec  q: quit", fg: DM
    end
  end

  def handle_key(key : Ori::Key) : Bool
    case
    when key.text == "q"                  then @running = false; true
    when key.code.up? || key.text == "k"  then @count += 1; rebuild; true
    when key.code.down? || key.text == "j" then @count -= 1; rebuild; true
    else super
    end
  end
end

CounterApp.run
