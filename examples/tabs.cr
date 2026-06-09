require "../src/ori"

BG = "#1e1e2e"; DM = "#6c7086"; MAUVE = "#cba6f7"; GREEN = "#a6e3a1"; BLUE = "#89b4fa"

class TabsApp < Ori::App
  @active : Int32 = 0
  @tabs : Ori::Tabs

  def initialize
    @tabs = Ori::Tabs.new(tabs: ["Files","Search","Git","Settings"],
      on_change: ->(idx : Int32) { @active = idx; nil },
      style: Ori::S.new(focusable: true))
  end

  def render : Ori::Box
    box bg: BG, padding: {1, 2} do
      text "Tabs Demo", fg: MAUVE, bold: true; attach @tabs
      case @active
      when 0; box padding: {1,2}, border: :single, border_fg: DM, height:8 do
        text "  report.pdf", fg: DM; text "  photo.jpg", fg: DM
        text "  Projects/", fg: BLUE; text "  Downloads/", fg: BLUE end
      when 1; box padding: {1,2}, border: :single, border_fg: DM, height:8 do
        text "  Search:", fg: DM; text "  No recent searches", fg: DM end
      when 2; box padding: {1,2}, border: :single, border_fg: DM, height:8 do
        text "  main  updated 2h ago", fg: GREEN
        text "  feat  updated 1d ago", fg: DM end
      when 3; box padding: {1,2}, border: :single, border_fg: DM, height:8 do
        text "  Theme: Catppuccin", fg: DM; text "  Font:  JetBrains Mono", fg: DM end
      end
      text "← →: switch  ctrl+c: quit", fg: DM
    end
  end
  def on_key(key : Ori::Key) : Bool
    if key.ctrl && key.text == "c"; @running = false; true else false end
  end
end
TabsApp.run
