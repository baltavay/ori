require "../src/ori"

BG = "#1e1e2e"; DM = "#6c7086"; MAUVE = "#cba6f7"; GREEN = "#a6e3a1"

class TreeApp < Ori::App
  @tree : Ori::Tree

  def initialize
    @tree = Ori::Tree.new(
      root: Ori::Tree::Node.new("Home", [
        Ori::Tree::Node.new("Documents", [
          Ori::Tree::Node.new("report.pdf"), Ori::Tree::Node.new("notes.txt"),
          Ori::Tree::Node.new("Projects", [
            Ori::Tree::Node.new("web-app"), Ori::Tree::Node.new("cli-tool"),
          ], expanded: true),
        ], expanded: true),
        Ori::Tree::Node.new("Downloads", [Ori::Tree::Node.new("image.jpg")]),
        Ori::Tree::Node.new("Pictures"),
      ], expanded: true),
      style: Ori::S.new(focusable: true),
      on_select: ->(s : String) { puts "selected: #{s}" },
    )
  end

  def render : Ori::Box
    box bg: BG, padding: {1, 2} do
      text "Tree Demo", fg: MAUVE, bold: true
      box padding: {1, 0} do; attach @tree; end
      text "j/k: navigate  l: expand  h: collapse  enter: select  ctrl+c: quit", fg: DM
    end
  end

  def on_key(key : Ori::Key) : Bool
    if key.ctrl && key.text == "c"; @running = false; true else false end
  end
end
TreeApp.run
