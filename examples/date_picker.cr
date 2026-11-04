require "../src/ori"

AC = "#cba6f7"; FG = "#cdd6f4"; BG = "#1e1e2e"; DM = "#6c7086"
GR = "#a6e3a1"; YL = "#f9e2af"; BL = "#89b4fa"

class DatePickerApp < Ori::App
  @status : String = ""
  @dp_open : Bool = false
  @dp_year : Int32 = 0
  @dp_month : Int32 = 0
  @dp_day : Int32 = 0

  def initialize
    super
    now = Time.utc
    @dp_year = now.year
    @dp_month = now.month
    @dp_day = now.day
  end

  def render : Ori::Box
    box height: "100%", direction: :vertical, bg: BG do
      box padding: {0, 1}, direction: :horizontal do
        text " DatePicker", bold: true, fg: AC
        text "  (enter/space:open  hjkl:move  H/L:month  J/K:year  t:today  q:quit)", fg: DM
      end
      box padding: {1, 2} do
        date_picker(
          focusable: true,
          open: @dp_open,
          year: @dp_year,
          month: @dp_month,
          day: @dp_day,
          fg: FG,
          header_fg: YL,
          selected_bg: AC,
          selected_fg: BG,
          today_bg: BL,
          today_fg: BG,
          other_month_fg: "#45475a",
          on_change: ->(t : Time) {
            @dp_year = t.year; @dp_month = t.month; @dp_day = t.day
            @status = "Selected: #{t}"
            nil
          },
          on_toggle: ->(open : Bool) { @dp_open = open },
        )
      end
      unless @status.empty?
        box padding: {0, 1} do
          text @status, fg: GR
        end
      end
    end
  end

  def on_key(key : Ori::Key) : Bool
    if key.ctrl && key.text == "c"
      @running = false; return false
    end
    if key.text == "q" && !@dp_open
      @running = false; return false
    end
    super
  end
end

DatePickerApp.run
