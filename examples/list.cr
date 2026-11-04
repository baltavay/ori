require "../src/ori"

AC = "#cba6f7"; FG = "#cdd6f4"; BG = "#1e1e2e"; DM = "#6c7086"; GR = "#a6e3a1"

class ListApp < Ori::App
  @items : Array(Ori::List::Item)
  @selected : Int32 = 0
  @list : Ori::List

  def initialize
    @items = [
      Ori::List::Item.new("Apple"), Ori::List::Item.new("Banana"),
      Ori::List::Item.new("Cherry"), Ori::List::Item.new("Date"),
      Ori::List::Item.new("Elderberry"), Ori::List::Item.new("Fig"),
      Ori::List::Item.new("Grape"), Ori::List::Item.new("Honeydew"),
    ]
    @list = Ori::List.new(items: @items, selected: @selected,
      on_select: ->(i : Int32) { @selected = i },
      style: Ori::S.new(focusable: true))
  end

  def render : Ori::Box
    box bg: BG, padding: {1, 2} do
      text "List Demo", bold: true, fg: AC
      text ""
      box border: :single, border_fg: DM, padding: {0, 1} do
        attach @list
      end
      text ""
      text "Selected: #{@list.index}", fg: GR
      text "j/k: navigate  enter: select  ctrl+c: quit", fg: DM
    end
  end

  def on_key(key : Ori::Key) : Bool
    if key.ctrl && key.text == "c"; @running = false; true else false end
  end
end

ListApp.run
