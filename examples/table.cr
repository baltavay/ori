require "../src/ori"

AC = "#cba6f7"; FG = "#cdd6f4"; BG = "#1e1e2e"; DM = "#6c7086"
GR = "#a6e3a1"; RD = "#f38ba8"; YL = "#f9e2af"; BL = "#89b4fa"

class TableApp < Ori::App
  @data : Array(Array(String))
  @selected : Int32 = 0
  @status : String = ""

  def initialize
    @data = [
      ["1", "Alice", "Engineering", "Senior", "Active"],
      ["2", "Bob", "Design", "Junior", "Active"],
      ["3", "Charlie", "Marketing", "Lead", "On Leave"],
      ["4", "Diana", "Engineering", "Mid", "Active"],
      ["5", "Eve", "Sales", "Senior", "Active"],
      ["6", "Frank", "Engineering", "Junior", "Probation"],
      ["7", "Grace", "Design", "Senior", "Active"],
      ["8", "Hank", "Marketing", "Mid", "Active"],
      ["9", "Ivy", "Engineering", "Lead", "Active"],
      ["10", "Jack", "Sales", "Senior", "On Leave"],
    ]
  end

  def render : Ori::Box
    box height: "100%", direction: :vertical, bg: BG do
      box padding: {0, 2}, direction: :horizontal do
        text " Employees", bold: true, fg: AC
        text "  (#{@data.size} records)", fg: DM
      end
      table(
        headers: ["#", "Name", "Department", "Level", "Status"],
        rows: @data,
        selected_row: @selected,
        flex: 1,
        focusable: true,
        border: :rounded,
        border_fg: DM,
        header_fg: AC,
        selected_bg: AC,
        selected_fg: BG,
        on_change: ->(row : Int32) { @selected = row; nil },
        on_select: ->(row : Int32) { @status = "Selected: #{@data[row]?.try(&.[1]) || "none"}"; nil },
      )
      unless @status.empty?
        box padding: {0, 2} do
          text @status, fg: GR
        end
      end
      box padding: {0, 2} do
        text " j/k:navigate  enter:select  g/G:top/bottom  q:quit", fg: DM
      end
    end
  end

  def handle_key(key : Ori::Key) : Bool
    if key.ctrl && key.text == "c"
      @running = false; return false
    end
    if key.text == "q"
      @running = false; return false
    end
    super
  end
end

TableApp.run
