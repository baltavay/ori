require "../src/ori"

AC = "#cba6f7"; FG = "#cdd6f4"; BG = "#1e1e2e"; DM = "#6c7086"
GR = "#a6e3a1"; RD = "#f38ba8"; YL = "#f9e2af"; BL = "#89b4fa"
COLORS = ["Red","Green","Blue","Yellow","Mauve","Cyan","White","Black"]
COLORS_HEX = {"Red"=>RD,"Green"=>GR,"Blue"=>BL,"Yellow"=>YL,"Mauve"=>AC,"Cyan"=>"#94e2d5","White"=>FG,"Black"=>"#45475a"}

class FormPage < Ori::Page
  @name : String = ""
  @name_cursor : Int32 = 0
  @bio : String = ""
  @bio_row : Int32 = 0
  @bio_col : Int32 = 0
  @color_idx : Int32 = 0
  @color_open : Bool = false

  def render : Ori::Box
    box direction: :vertical, padding: {1, 3}, bg: BG do
      text "  Form Demo", bold: true, fg: AC; text ""
      box direction: :horizontal, spacing: 2 do
        box flex: 1 do
          text "  Name", bold: true, fg: YL
          input value: @name, cursor: @name_cursor, placeholder: "John Doe",
            focusable: true, border: :single, fg: FG, border_fg: DM, flex: 1,
            on_change: ->(v : String) { @name = v },
            on_cursor: ->(c : Int32) { @name_cursor = c }
        end
        box flex: 1 do
          text "  Color", bold: true, fg: YL
          dropdown options: COLORS, selected: @color_idx, open: @color_open,
            focusable: true, flex: 1, highlight_bg: AC, highlight_fg: BG,
            on_change: ->(idx : Int32) { @color_idx = idx },
            on_toggle: ->(open : Bool) { @color_open = open }
        end
      end
      text ""; text "  Bio", bold: true, fg: YL
      area value: @bio, cursor_row: @bio_row, cursor_col: @bio_col,
        focusable: true, border: :single, fg: FG, border_fg: DM, flex: 1,
        on_change: ->(v : String, r : Int32, c : Int32) { @bio = v; @bio_row = r; @bio_col = c }
      text ""
      box direction: :horizontal do
        button label: "Submit", variant: :primary, focusable: true,
          on_press: -> { app.push_page(ConfirmPage.new(app, @name, @bio, COLORS[@color_idx]? || "none")) }
        text "  tab: next field  ctrl+c: quit", fg: DM
      end
    end
  end

  def bindings : Hash(String, String)
    super.merge({"enter" => "submit form"})
  end
end

class ConfirmPage < Ori::Page
  def initialize(app, @name : String, @bio : String, @color_name : String)
    super(app)
  end

  def render : Ori::Box
    box bg: BG, padding: {3, 4} do
      box border: :double, border_fg: GR, bg: "#313244", padding: {1, 2} do
        text "  Submitted!", bold: true, fg: GR; text ""
        bio_short = @bio.empty? ? "(empty)" : @bio.gsub('\n', " | ")[0, 50]
        text "  Name:   #{@name}", fg: FG
        text "  Bio:    #{bio_short}", fg: FG
        text "  Color:  #{@color_name}", fg: FG
        text ""; text "  Enter: close  ctrl+c: quit", fg: DM
      end
    end
  end

  def on_enter : Nil
    @focus.focus_first
  end

  def on_key(key : Ori::Key) : Bool
    if key.code.enter?
      app.pop_page; true
    else
      false
    end
  end

  def bindings : Hash(String, String)
    super.merge({"enter" => "close confirm"})
  end
end

class FormApp < Ori::App
  def initialize
    super
    push_page(FormPage.new(self))
  end
end

FormApp.run
