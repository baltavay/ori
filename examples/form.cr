require "../src/ori"

AC = "#cba6f7"; FG = "#cdd6f4"; BG = "#1e1e2e"; DM = "#6c7086"
GR = "#a6e3a1"; RD = "#f38ba8"; YL = "#f9e2af"; BL = "#89b4fa"

class FormApp < Ori::App
  @name : String = ""
  @bio : String = ""
  @bio_row : Int32 = 0
  @bio_col : Int32 = 0
  @color_idx : Int32 = 0
  @color_open : Bool = false
  @dp_year : Int32 = 0
  @dp_month : Int32 = 0
  @dp_day : Int32 = 0
  @dp_open : Bool = false
  @dtp_year : Int32 = 0
  @dtp_month : Int32 = 0
  @dtp_day : Int32 = 0
  @dtp_hour : Int32 = 9
  @dtp_minute : Int32 = 0
  @dtp_open : Bool = false
  @dtp_section : Ori::DateTimePicker::Section = Ori::DateTimePicker::Section::Date
  @dtp_tfield : Ori::DateTimePicker::TField = Ori::DateTimePicker::TField::Hour
  @submitted : Bool = false

  def initialize
    super
    now = Time.utc
    @dp_year = @dtp_year = now.year
    @dp_month = @dtp_month = now.month
    @dp_day = @dtp_day = now.day
  end

  def render : Ori::Box
    box direction: :vertical, padding: {1, 3}, bg: BG, scrollable: true do
      text " Form Demo", bold: true, fg: AC
      text ""

      if @submitted
        text "  Submitted!", bold: true, fg: GR
        text ""
        text "  Name:     #{@name}", fg: FG
        text "  Bio:      #{@bio.gsub('\n', " ")}", fg: FG
        text "  Color:    #{COLORS[@color_idx]?}", fg: COLORS_HEX[@color_idx]? || FG
        text "  Date:     #{sprintf("%04d-%02d-%02d", @dp_year, @dp_month, @dp_day)}", fg: FG
        text "  DateTime: #{sprintf("%04d-%02d-%02d %02d:%02d", @dtp_year, @dtp_month, @dtp_day, @dtp_hour, @dtp_minute)}", fg: FG
        text ""
        text "  Press 'r' to reset", fg: DM
      else
        text "  Name", bold: true, fg: YL
        input value: @name, placeholder: "John Doe",
          focusable: true, border: :single, fg: FG, border_fg: DM,
          on_change: ->(v : String) { @name = v; nil },
          on_submit: -> { @submitted = true; rebuild; nil }

        text ""
        text "  Bio", bold: true, fg: YL
        area value: @bio,
          focusable: true, border: :single, fg: FG, border_fg: DM,
          width: 40, height: 3,
          cursor_row: @bio_row, cursor_col: @bio_col,
          on_change: ->(v : String, r : Int32, c : Int32) { @bio = v; @bio_row = r; @bio_col = c; nil }

        text ""
        text "  Color", bold: true, fg: YL
        dropdown(
          options: COLORS,
          selected: @color_idx,
          open: @color_open,
          focusable: true,
          border: :single, border_fg: DM,
          highlight_bg: AC, highlight_fg: BG,
          fg: COLORS_HEX[@color_idx]?,
          on_change: ->(idx : Int32) { @color_idx = idx; nil },
          on_toggle: ->(open : Bool) { @color_open = open; nil },
        )

        text ""
        text "  Date", bold: true, fg: YL
        date_picker(
          focusable: true,
          open: @dp_open,
          year: @dp_year, month: @dp_month, day: @dp_day,
          border: :single, border_fg: DM,
          fg: FG, header_fg: YL,
          selected_bg: AC, selected_fg: BG,
          today_bg: BL, today_fg: BG,
          other_month_fg: "#45475a",
          on_change: ->(t : Time) {
            @dp_year = t.year; @dp_month = t.month; @dp_day = t.day
            nil
          },
          on_toggle: ->(open : Bool) { @dp_open = open; nil },
        )

        text ""
        text "  DateTime", bold: true, fg: YL
        datetime_picker(
          focusable: true,
          open: @dtp_open,
          section: @dtp_section, tfield: @dtp_tfield,
          year: @dtp_year, month: @dtp_month, day: @dtp_day,
          hour: @dtp_hour, minute: @dtp_minute,
          border: :single, border_fg: DM,
          fg: FG, header_fg: YL,
          selected_bg: AC, selected_fg: BG,
          today_bg: BL, today_fg: BG,
          other_month_fg: "#45475a",
          time_fg: FG, active_bg: AC, active_fg: BG,
          on_change: ->(t : Time) {
            @dtp_year = t.year; @dtp_month = t.month; @dtp_day = t.day
            @dtp_hour = t.hour; @dtp_minute = t.minute
            nil
          },
          on_toggle: ->(open : Bool) { @dtp_open = open; nil },
        )

        text ""
        text "  tab: next field  ctrl+c: quit", fg: DM
      end
    end
  end

  def handle_key(key : Ori::Key) : Bool
    if key.ctrl && key.text == "c"
      @running = false; return false
    end
    if key.text == "r" && @submitted
      reset; return true
    end
    super
  end

  private def reset : Nil
    now = Time.utc
    @name = ""; @bio = ""; @color_idx = 0
    @dp_year = @dtp_year = now.year
    @dp_month = @dtp_month = now.month
    @dp_day = @dtp_day = now.day
    @dtp_hour = 9; @dtp_minute = 0
    @submitted = false
    rebuild
  end
end

COLORS     = ["Red", "Green", "Blue", "Yellow", "Mauve", "Cyan", "White", "Black"]
COLORS_HEX = {
  "Red" => RD, "Green" => GR, "Blue" => BL, "Yellow" => YL,
  "Mauve" => AC, "Cyan" => "#94e2d5", "White" => FG, "Black" => "#45475a",
}

FormApp.run
