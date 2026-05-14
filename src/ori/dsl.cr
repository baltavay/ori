module Ori::DSL
  struct StyleArgs
    getter fg : String?
    getter bg : String?
    getter bold : Bool
    getter dim : Bool
    getter underline : Bool
    getter strikethrough : Bool
    getter border : Bool | Symbol | Nil
    getter border_fg : String?
    getter padding : Int32 | Tuple(Int32, Int32) | Tuple(Int32, Int32, Int32, Int32) | Nil
    getter width : Int32 | String | Nil
    getter height : Int32 | String | Nil
    getter flex : Int32
    getter direction : Symbol
    getter align : Symbol
    getter focusable : Bool
    getter scrollable : Bool
    getter bar_style : Symbol
    getter gradient_to : String?

    def initialize(
      @fg : String? = nil,
      @bg : String? = nil,
      @bold : Bool = false,
      @dim : Bool = false,
      @underline : Bool = false,
      @strikethrough : Bool = false,
      @border : Bool | Symbol | Nil = nil,
      @border_fg : String? = nil,
      @padding : Int32 | Tuple(Int32, Int32) | Tuple(Int32, Int32, Int32, Int32) | Nil = nil,
      @width : Int32 | String | Nil = nil,
      @height : Int32 | String | Nil = nil,
      @flex : Int32 = 0,
      @direction : Symbol = :vertical,
      @align : Symbol = :left,
      @focusable : Bool = false,
      @scrollable : Bool = false,
      @bar_style : Symbol = :solid,
      @gradient_to : String? = nil
    )
    end

    def to_s : Ori::S
      w = @width
      h = @height
      width_val : Int32? = nil
      height_val : Int32? = nil
      width_pct : Float64? = nil
      height_pct : Float64? = nil

      case w
      when String
        width_pct = w.chomp('%').to_f
      when Int32
        width_val = w
      end

      case h
      when String
        height_pct = h.chomp('%').to_f
      when Int32
        height_val = h
      end

      Ori::S.new(
        fg: @fg, bg: @bg, bold: @bold, dim: @dim,
        underline: @underline, strikethrough: @strikethrough,
        border: @border, border_fg: @border_fg, padding: @padding,
        width: width_val, height: height_val,
        width_pct: width_pct, height_pct: height_pct,
        flex: @flex, direction: @direction, align: @align,
        focusable: @focusable, scrollable: @scrollable,
        bar_style: @bar_style, gradient_to: @gradient_to,
      )
    end
  end

  def self.make_input(**opts) : Ori::InputNode
    bs = opts.fetch(:border, true)
    default_prefix = bs.is_a?(Symbol) ? Ori.border_chars(bs)[:prefix].to_s : "▌"
    style = Ori::DSL::StyleArgs.new(
      fg: opts[:fg]?.as?(String),
      bg: opts[:bg]?.as?(String),
      bold: (opts[:bold]? || false).as(Bool),
      dim: (opts[:dim]? || false).as(Bool),
      underline: (opts[:underline]? || false).as(Bool),
      strikethrough: (opts[:strikethrough]? || false).as(Bool),
      border: opts.fetch(:border, true).as(Bool | Symbol | Nil),
      border_fg: opts[:border_fg]?.as?(String),
      padding: opts[:padding]?.as?(Int32 | Tuple(Int32, Int32) | Tuple(Int32, Int32, Int32, Int32)),
      width: opts[:width]?.as?(Int32),
      height: opts[:height]?.as?(Int32),
      flex: (opts[:flex]? || 0).as(Int32),
      direction: (opts[:direction]? || :vertical).as(Symbol),
      align: (opts[:align]? || :left).as(Symbol),
      focusable: (opts[:focusable]? || false).as(Bool),
    ).to_s
    Ori::InputNode.new(
      value: (opts[:value]? || "").as(String),
      placeholder: (opts[:placeholder]? || "").as(String),
      prefix: (opts[:prefix]? || default_prefix).as(String),
      on_change: opts[:on_change]?.as?(Proc(String, Nil)),
      on_submit: opts[:on_submit]?.as?(Proc(Nil)),
      style: style,
    )
  end

  def self.make_area(**opts) : Ori::AreaNode
    style = Ori::DSL::StyleArgs.new(
      fg: opts[:fg]?.as?(String),
      bg: opts[:bg]?.as?(String),
      bold: (opts[:bold]? || false).as(Bool),
      dim: (opts[:dim]? || false).as(Bool),
      underline: (opts[:underline]? || false).as(Bool),
      strikethrough: (opts[:strikethrough]? || false).as(Bool),
      border: opts.fetch(:border, true).as(Bool | Symbol | Nil),
      border_fg: opts[:border_fg]?.as?(String),
      padding: opts[:padding]?.as?(Int32 | Tuple(Int32, Int32) | Tuple(Int32, Int32, Int32, Int32)),
      width: opts[:width]?.as?(Int32),
      height: opts[:height]?.as?(Int32),
      flex: (opts[:flex]? || 0).as(Int32),
      direction: (opts[:direction]? || :vertical).as(Symbol),
      align: (opts[:align]? || :left).as(Symbol),
      focusable: (opts[:focusable]? || false).as(Bool),
    ).to_s
    Ori::AreaNode.new(
      value: (opts[:value]? || "").as(String),
      on_change: opts[:on_change]?.as?(Proc(String, Int32, Int32, Nil)),
      on_cursor: opts[:on_cursor]?.as?(Proc(Int32, Int32, Nil)),
      cursor_row: (opts[:cursor_row]? || 0).as(Int32),
      cursor_col: opts[:cursor_col]?.as?(Int32),
      char_limit: (opts[:char_limit]? || 0).as(Int32),
      show_line_numbers: (opts[:show_line_numbers]? || false).as(Bool),
      highlights: opts[:highlights]?.try(&.as(Array(Tuple(Int32, Int32, Int32)))) || [] of Tuple(Int32, Int32, Int32),
      style: style,
    )
  end

  def box(**opts, &block) : Ori::Box
    children = [] of Ori::Node
    style = Ori::DSL.extract_style(**opts)
    b = Ori::Box.new(children, style)
    with b yield
    b
  end

  def text(content : String, **opts) : Ori::TextNode
    Ori::TextNode.new(content, Ori::DSL.extract_style(**opts))
  end

  def input(**opts) : Ori::InputNode
    Ori::DSL.make_input(**opts)
  end

  def area(**opts) : Ori::AreaNode
    Ori::DSL.make_area(**opts)
  end

  def self.make_progress_bar(**opts) : Ori::ProgressBar
    Ori::ProgressBar.new(
      value: opts[:value]?.try(&.as(Float64)) || 0.0,
      max: opts[:max]?.try(&.as(Float64)) || 100.0,
      style: Ori::DSL.extract_style(**opts),
    )
  end

  def self.make_viewport(**opts) : Ori::Viewport
    Ori::Viewport.new(
      content: (opts[:content]? || "").as(String),
      soft_wrap: (opts[:soft_wrap]? || true).as(Bool),
      y_offset: (opts[:y_offset]? || 0).as(Int32),
      on_scroll: opts[:on_scroll]?.as?(Proc(Int32, Nil)),
      style: Ori::DSL.extract_style(**opts),
    )
  end

  def self.make_table(**opts) : Ori::Table
    Ori::Table.new(
      headers: opts[:headers]?.try(&.as(Array(String))) || [] of String,
      rows: opts[:rows]?.try(&.as(Array(Array(String)))) || [] of Array(String),
      selected_row: opts[:selected_row]?.try(&.as(Int32)) || 0,
      on_change: opts[:on_change]?.try(&.as(Proc(Int32, Nil))),
      on_select: opts[:on_select]?.try(&.as(Proc(Int32, Nil))),
      header_fg: opts[:header_fg]?.try(&.as(String)),
      selected_fg: opts[:selected_fg]?.try(&.as(String)),
      selected_bg: opts[:selected_bg]?.try(&.as(String)),
      style: Ori::DSL.extract_style(**opts),
    )
  end

  def self.make_list(**opts) : Ori::List
    Ori::List.new(
      items: opts[:items]?.try(&.as(Array(Ori::List::Item))) || [] of Ori::List::Item,
      selected: opts[:selected]?.try(&.as(Int32)) || 0,
      checked: opts[:checked]?.try(&.as(Array(Bool))) || [] of Bool,
      on_select: opts[:on_select]?.try(&.as(Proc(Int32, Nil))),
      on_change: opts[:on_change]?.try(&.as(Proc(Int32, Nil))),
      selected_fg: opts[:selected_fg]?.try(&.as(String)),
      selected_bg: opts[:selected_bg]?.try(&.as(String)),
      selected_prefix: opts[:selected_prefix]?.try(&.as(String)) || "▌ ",
      normal_prefix: opts[:normal_prefix]?.try(&.as(String)) || "  ",
      truncate: opts[:truncate]?.try(&.as(Int32)) || 0,
      checkable: opts[:checkable]?.try(&.as(Bool)) || false,
      style: Ori::DSL.extract_style(**opts),
    )
  end

  def self.make_spinner(**opts) : Ori::Spinner
    Ori::Spinner.new(
      type: opts[:type]?.try(&.as(Symbol)) || :dots,
      style: Ori::DSL.extract_style(**opts),
    )
  end

  def self.make_list(**opts) : Ori::List
    Ori::List.new(
      items: opts[:items]?.try(&.as(Array(Ori::List::Item))) || [] of Ori::List::Item,
      selected: opts[:selected]?.try(&.as(Int32)) || 0,
      checked: opts[:checked]?.try(&.as(Array(Bool))) || [] of Bool,
      on_select: opts[:on_select]?.try(&.as(Proc(Int32, Nil))),
      on_change: opts[:on_change]?.try(&.as(Proc(Int32, Nil))),
      selected_fg: opts[:selected_fg]?.try(&.as(String)),
      selected_bg: opts[:selected_bg]?.try(&.as(String)),
      selected_prefix: opts[:selected_prefix]?.try(&.as(String)) || "▌ ",
      normal_prefix: opts[:normal_prefix]?.try(&.as(String)) || "  ",
      truncate: opts[:truncate]?.try(&.as(Int32)) || 0,
      checkable: opts[:checkable]?.try(&.as(Bool)) || false,
      style: Ori::DSL.extract_style(**opts),
    )
  end

  def self.make_table(**opts) : Ori::Table
    Ori::Table.new(
      headers: opts[:headers]?.try(&.as(Array(String))) || [] of String,
      rows: opts[:rows]?.try(&.as(Array(Array(String)))) || [] of Array(String),
      selected_row: opts[:selected_row]?.try(&.as(Int32)) || 0,
      on_change: opts[:on_change]?.try(&.as(Proc(Int32, Nil))),
      on_select: opts[:on_select]?.try(&.as(Proc(Int32, Nil))),
      header_fg: opts[:header_fg]?.try(&.as(String)),
      selected_fg: opts[:selected_fg]?.try(&.as(String)),
      selected_bg: opts[:selected_bg]?.try(&.as(String)),
      style: Ori::DSL.extract_style(**opts),
    )
  end

  def self.make_select(**opts) : Ori::Select
    Ori::Select.new(
      options: opts[:options]?.try(&.as(Array(String))) || [] of String,
      selected: opts[:selected]?.try(&.as(Int32)) || 0,
      highlighted: opts[:highlighted]?.try(&.as(Int32)) || -1,
      open: opts[:open]?.try(&.as(Bool)) || false,
      on_change: opts[:on_change]?.try(&.as(Proc(Int32, Nil))),
      on_toggle: opts[:on_toggle]?.try(&.as(Proc(Bool, Nil))),
      on_highlight: opts[:on_highlight]?.try(&.as(Proc(Int32, Nil))),
      max_visible: opts[:max_visible]?.try(&.as(Int32)) || 8,
      highlight_fg: opts[:highlight_fg]?.try(&.as(String)),
      highlight_bg: opts[:highlight_bg]?.try(&.as(String)),
      style: Ori::DSL.extract_style(**opts),
    )
  end

  def self.make_date_picker(**opts) : Ori::DatePicker
    Ori::DatePicker.new(
      year: opts[:year]?.try(&.as(Int32)),
      month: opts[:month]?.try(&.as(Int32)),
      day: opts[:day]?.try(&.as(Int32)),
      monday_first: opts[:monday_first]?.try(&.as(Bool)) || false,
      open: opts[:open]?.try(&.as(Bool)) || false,
      on_change: opts[:on_change]?.try(&.as(Proc(Time, Nil))),
      on_toggle: opts[:on_toggle]?.try(&.as(Proc(Bool, Nil))),
      header_fg: opts[:header_fg]?.try(&.as(String)),
      selected_fg: opts[:selected_fg]?.try(&.as(String)),
      selected_bg: opts[:selected_bg]?.try(&.as(String)),
      today_fg: opts[:today_fg]?.try(&.as(String)),
      today_bg: opts[:today_bg]?.try(&.as(String)),
      day_fg: opts[:day_fg]?.try(&.as(String)),
      other_month_fg: opts[:other_month_fg]?.try(&.as(String)),
      style: Ori::DSL.extract_style(**opts),
    )
  end

  def self.make_datetime_picker(**opts) : Ori::DateTimePicker
    Ori::DateTimePicker.new(
      year: opts[:year]?.try(&.as(Int32)),
      month: opts[:month]?.try(&.as(Int32)),
      day: opts[:day]?.try(&.as(Int32)),
      hour: opts[:hour]?.try(&.as(Int32)) || 0,
      minute: opts[:minute]?.try(&.as(Int32)) || 0,
      monday_first: opts[:monday_first]?.try(&.as(Bool)) || false,
      open: opts[:open]?.try(&.as(Bool)) || false,
      section: opts[:section]?.try(&.as(Ori::DateTimePicker::Section)) || Ori::DateTimePicker::Section::Date,
      tfield: opts[:tfield]?.try(&.as(Ori::DateTimePicker::TField)) || Ori::DateTimePicker::TField::Hour,
      on_change: opts[:on_change]?.try(&.as(Proc(Time, Nil))),
      on_toggle: opts[:on_toggle]?.try(&.as(Proc(Bool, Nil))),
      time_fg: opts[:time_fg]?.try(&.as(String)),
      active_fg: opts[:active_fg]?.try(&.as(String)),
      active_bg: opts[:active_bg]?.try(&.as(String)),
      header_fg: opts[:header_fg]?.try(&.as(String)),
      selected_fg: opts[:selected_fg]?.try(&.as(String)),
      selected_bg: opts[:selected_bg]?.try(&.as(String)),
      today_fg: opts[:today_fg]?.try(&.as(String)),
      today_bg: opts[:today_bg]?.try(&.as(String)),
      day_fg: opts[:day_fg]?.try(&.as(String)),
      other_month_fg: opts[:other_month_fg]?.try(&.as(String)),
      style: Ori::DSL.extract_style(**opts),
    )
  end

  def self.make_file_picker(**opts) : Ori::FilePicker
    Ori::FilePicker.new(
      current_dir: (opts[:current_dir]? || Dir.current).as(String),
      allowed_types: opts[:allowed_types]?.try(&.as(Array(String))) || [] of String,
      show_hidden: (opts[:show_hidden]? || false).as(Bool),
      on_select: opts[:on_select]?.as?(Proc(String, Nil)),
      style: Ori::DSL.extract_style(**opts),
    )
  end

  def self.make_markdown(**opts) : Ori::MarkdownNode
    Ori::MarkdownNode.new(
      content: (opts[:content]? || "").as(String),
      y_offset: (opts[:y_offset]? || 0).as(Int32),
      on_scroll: opts[:on_scroll]?.as?(Proc(Int32, Nil)),
      style: Ori::DSL.extract_style(**opts),
    )
  end

  def self.make_sparkline(**opts) : Ori::Sparkline
    Ori::Sparkline.new(
      data: opts[:data]?.try(&.as(Array(Float64))) || [] of Float64,
      max: opts[:max]?.try(&.as(Float64)) || 0.0,
      auto_max: (opts[:auto_max]? || true).as(Bool),
      style: Ori::DSL.extract_style(**opts),
    )
  end

  def self.make_help(**opts) : Ori::Help
    Ori::Help.new(
      bindings: opts[:bindings]?.try(&.as(Array(Ori::HelpBinding))) || [] of Ori::HelpBinding,
      show_all: (opts[:show_all]? || false).as(Bool),
      style: Ori::DSL.extract_style(**opts),
    )
  end

  def progress_bar(**opts) : Ori::ProgressBar
    Ori::DSL.make_progress_bar(**opts)
  end

  def self.extract_style(**opts) : Ori::S
    StyleArgs.new(
      fg: opts[:fg]?.as?(String),
      bg: opts[:bg]?.as?(String),
      bold: (opts[:bold]? || false).as(Bool),
      dim: (opts[:dim]? || false).as(Bool),
      underline: (opts[:underline]? || false).as(Bool),
      strikethrough: (opts[:strikethrough]? || false).as(Bool),
      border: opts[:border]?,
      border_fg: opts[:border_fg]?.as?(String),
      padding: opts[:padding]?.as?(Int32 | Tuple(Int32, Int32) | Tuple(Int32, Int32, Int32, Int32)),
      width: opts[:width]?.as?(Int32 | String),
      height: opts[:height]?.as?(Int32 | String),
      flex: (opts[:flex]? || 0).as(Int32),
      direction: (opts[:direction]? || :vertical).as(Symbol),
      align: (opts[:align]? || :left).as(Symbol),
      focusable: (opts[:focusable]? || false).as(Bool),
      scrollable: (opts[:scrollable]? || false).as(Bool),
      bar_style: (opts[:bar_style]? || :solid).as(Symbol),
      gradient_to: opts[:gradient_to]?.as?(String),
    ).to_s
  end

  def spinner(**opts) : Ori::Spinner
    Ori::DSL.make_spinner(**opts)
  end

  def table(**opts) : Ori::Table
    t = Ori::DSL.make_table(**opts)
    t
  end

  def list(**opts) : Ori::List
    Ori::DSL.make_list(**opts)
  end

  def viewport(**opts) : Ori::Viewport
    Ori::DSL.make_viewport(**opts)
  end

  def dropdown(**opts) : Ori::Select
    Ori::DSL.make_select(**opts)
  end

  def date_picker(**opts) : Ori::DatePicker
    Ori::DSL.make_date_picker(**opts)
  end

  def datetime_picker(**opts) : Ori::DateTimePicker
    Ori::DSL.make_datetime_picker(**opts)
  end

  def file_picker(**opts) : Ori::FilePicker
    Ori::DSL.make_file_picker(**opts)
  end

  def markdown(**opts) : Ori::MarkdownNode
    Ori::DSL.make_markdown(**opts)
  end

  def sparkline(**opts) : Ori::Sparkline
    Ori::DSL.make_sparkline(**opts)
  end

  def help(**opts) : Ori::Help
    Ori::DSL.make_help(**opts)
  end
end
