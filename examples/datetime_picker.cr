require "../src/ori"

AC = "#cba6f7"; FG = "#cdd6f4"; BG = "#1e1e2e"; DM = "#6c7086"
GR = "#a6e3a1"; YL = "#f9e2af"; BL = "#89b4fa"

class DateTimePickerApp < Ori::App
  @status : String = ""
  @dtp_open : Bool = false
  @dtp_section : Ori::DateTimePicker::Section = Ori::DateTimePicker::Section::Date
  @dtp_tfield : Ori::DateTimePicker::TField = Ori::DateTimePicker::TField::Hour
  @dtp_year : Int32 = 0
  @dtp_month : Int32 = 0
  @dtp_day : Int32 = 0
  @dtp_hour : Int32 = 0
  @dtp_minute : Int32 = 0

  def initialize
    super
    now = Time.utc
    @dtp_year = now.year
    @dtp_month = now.month
    @dtp_day = now.day
  end

  def render : Ori::Box
    box height: "100%", direction: :vertical, bg: BG do
      box padding: {0, 1}, direction: :horizontal do
        text " DateTimePicker", bold: true, fg: AC
        text "  (enter:open/confirm  tab:switch  hjkl:move  q:quit)", fg: DM
      end
      box padding: {1, 2} do
        datetime_picker(
          focusable: true,
          open: @dtp_open,
          section: @dtp_section,
          tfield: @dtp_tfield,
          year: @dtp_year,
          month: @dtp_month,
          day: @dtp_day,
          hour: @dtp_hour,
          minute: @dtp_minute,
          fg: FG,
          header_fg: YL,
          selected_bg: AC,
          selected_fg: BG,
          today_bg: BL,
          today_fg: BG,
          other_month_fg: "#45475a",
          time_fg: FG,
          active_bg: AC,
          active_fg: BG,
          on_change: ->(t : Time) {
            @dtp_year = t.year; @dtp_month = t.month; @dtp_day = t.day
            @dtp_hour = t.hour; @dtp_minute = t.minute
            @status = "Selected: #{t}"
            nil
          },
          on_toggle: ->(open : Bool) { @dtp_open = open; nil },
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
    if key.text == "q" && !@dtp_open
      @running = false; return false
    end
    super
  end
end

DateTimePickerApp.run
