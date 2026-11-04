require "../src/ori"

AC = "#cba6f7"; FG = "#cdd6f4"; BG = "#1e1e2e"; DM = "#6c7086"
GR = "#a6e3a1"; RD = "#f38ba8"; YL = "#f9e2af"; BL = "#89b4fa"

COLORS = ["Red", "Green", "Blue", "Yellow", "Magenta", "Cyan", "White", "Black"]
COLOR_HEX = {"Red" => RD, "Green" => GR, "Blue" => BL, "Yellow" => YL, "Magenta" => AC, "Cyan" => "#94e2d5", "White" => FG, "Black" => "#45475a"}

class SelectApp < Ori::App
  @color_idx : Int32 = 0
  @size_idx : Int32 = 2
  @sel_open : Bool = false
  @sel_hl : Int32 = 0
  @size_open : Bool = false
  @size_hl : Int32 = 2
  @message : String = ""

  def render : Ori::Box
    box height: "100%", direction: :vertical, bg: BG do
      box padding: {1, 2} do
        text "Select Example", bold: true, fg: AC
      end

      box padding: {0, 2}, direction: :horizontal do
        text "Color: ", fg: FG
        dropdown(
          options: COLORS,
          selected: @color_idx,
          highlighted: @sel_open ? @sel_hl : @color_idx,
          open: @sel_open,
          focusable: true,
          highlight_bg: AC,
          highlight_fg: BG,
          border_fg: COLOR_HEX[COLORS[@color_idx]]?,
          fg: COLOR_HEX[COLORS[@color_idx]]?,
          on_change: ->(idx : Int32) { @color_idx = idx },
          on_toggle: ->(open : Bool) { @sel_open = open },
          on_highlight: ->(idx : Int32) { @sel_hl = idx },
        )
      end

      box padding: {0, 2}, direction: :horizontal do
        text "Size: ", fg: FG
        dropdown(
          options: ["Tiny", "Small", "Medium", "Large", "Huge"],
          selected: @size_idx,
          highlighted: @size_open ? @size_hl : @size_idx,
          open: @size_open,
          focusable: true,
          highlight_bg: AC,
          highlight_fg: BG,
          on_change: ->(idx : Int32) { @size_idx = idx },
          on_toggle: ->(open : Bool) { @size_open = open },
          on_highlight: ->(idx : Int32) { @size_hl = idx },
        )
      end

      box padding: {1, 2} do
        color_name = COLORS[@color_idx]? || "None"
        sizes = ["Tiny", "Small", "Medium", "Large", "Huge"]
        size_name = sizes[@size_idx]? || "Medium"
        text "You chose: #{color_name}, #{size_name}", fg: GR
      end

      unless @message.empty?
        box padding: {0, 2} do
          text @message, fg: YL
        end
      end

      box flex: 1 do
      end

      box padding: {0, 2} do
        text " enter/space:open  ↑↓:cycle  j/k:navigate  esc:close  tab:focus  q:quit", fg: DM
      end
    end
  end

  def on_key(key : Ori::Key) : Bool
    if key.ctrl && key.text == "c"
      @running = false; return false
    end
    if key.text == "q" && !@sel_open && !@size_open
      @running = false; return false
    end
    super
  end
end

SelectApp.run
