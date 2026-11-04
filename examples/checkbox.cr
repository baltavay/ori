require "../src/ori"

BG = "#1e1e2e"; DM = "#6c7086"; MAUVE = "#cba6f7"; GREEN = "#a6e3a1"

class CheckboxApp < Ori::App
  @checks : Array(Bool) = [false, false, false]

  def render : Ori::Box
    box bg: BG, padding: {1, 2} do
      text "Checkbox Demo", fg: MAUVE, bold: true
      box padding: {1, 0} do
        checkbox label: "Enable notifications", focusable: true,
          checked: @checks[0], on_change: ->(v : Bool) { @checks[0] = v }
        checkbox label: "Dark mode", focusable: true,
          checked: @checks[1], on_change: ->(v : Bool) { @checks[1] = v }
        checkbox label: "Auto-save", focusable: true,
          checked: @checks[2], on_change: ->(v : Bool) { @checks[2] = v }
      end
      status = @checks.each_with_index.map { |c,i| "#{i}:#{c}" }.join(", ")
      text "Status: #{status}", fg: GREEN
      text "tab: navigate  space: toggle  ctrl+c: quit", fg: DM
    end
  end

  def on_key(key : Ori::Key) : Bool
    if key.ctrl && key.text == "c"; @running = false; true else false end
  end
end

CheckboxApp.run
