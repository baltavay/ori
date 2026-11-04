require "../src/ori"

class PickerApp < Ori::App
  @selected : String?
  @picker : Ori::FilePicker

  def initialize
    @selected = nil
    @picker = Ori::FilePicker.new(
      on_select: ->(path : String) { @selected = path },
      style: Ori::S.new(flex: 1),
    )
  end

  def render : Ori::Box
    box height: "100%", direction: :vertical do
      box padding: {0, 1}, direction: :horizontal do
        text "File Picker", bold: true, fg: "#cba6f7"
        if s = @selected
          text "  Selected: #{s}", fg: "#a6e3a1"
        else
          text "  j/k: navigate  enter: select  backspace: up  q: quit", fg: "#6c7086"
        end
      end

      attach @picker
    end
  end

  def on_key(key : Ori::Key) : Bool
    if key.text == "q"
      @running = false
      return false
    end
    super
  end
end

PickerApp.run
