module Ori::DSL
  # Wrap any callback to discard its return value (return Nil).
  # Lets users omit `; nil` at end of callback lambdas.
  def self.wrap(cb : Proc(V)) : Proc(Nil) forall V
    -> { cb.call; nil }
  end

  def self.wrap(cb : Proc(T, V)) : Proc(T, Nil) forall T, V
    ->(x : T) { cb.call(x); nil }
  end

  def self.wrap(cb : Proc(T, U, V)) : Proc(T, U, Nil) forall T, U, V
    ->(x : T, y : U) { cb.call(x, y); nil }
  end

  def self.wrap(cb : Proc(T, U, V, W)) : Proc(T, U, V, Nil) forall T, U, V, W
    ->(x : T, y : U, z : V) { cb.call(x, y, z); nil }
  end

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
    getter min_width : Int32?
    getter max_width : Int32?
    getter min_height : Int32?
    getter max_height : Int32?
    getter spacing : Int32
    getter margin : Int32 | Tuple(Int32, Int32) | Tuple(Int32, Int32, Int32, Int32) | Nil
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
      @min_width : Int32? = nil,
      @max_width : Int32? = nil,
      @min_height : Int32? = nil,
      @max_height : Int32? = nil,
      @spacing : Int32 = 0,
      @margin : Int32 | Tuple(Int32, Int32) | Tuple(Int32, Int32, Int32, Int32) | Nil = nil,
      @flex : Int32 = 0,
      @direction : Symbol = :vertical,
      @align : Symbol = :left,
      @focusable : Bool = false,
      @scrollable : Bool = false,
      @bar_style : Symbol = :solid,
      @gradient_to : String? = nil,
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
      when String then width_pct = w.chomp('%').to_f
      when Int32  then width_val = w
      end
      case h
      when String then height_pct = h.chomp('%').to_f
      when Int32  then height_val = h
      end
      Ori::S.new(
        fg: @fg, bg: @bg, bold: @bold, dim: @dim,
        underline: @underline, strikethrough: @strikethrough,
        border: @border, border_fg: @border_fg, padding: @padding,
        width: width_val, height: height_val,
        width_pct: width_pct, height_pct: height_pct,
        min_width: @min_width, max_width: @max_width,
        min_height: @min_height, max_height: @max_height,
        spacing: @spacing, margin: @margin,
        flex: @flex, direction: @direction,
        align: @align, focusable: @focusable,
        scrollable: @scrollable, bar_style: @bar_style,
        gradient_to: @gradient_to,
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
      cursor: opts[:cursor]?.as?(Int32),
      on_change: opts[:on_change]?.try { |cb| wrap(cb) },
      on_submit: opts[:on_submit]?.try { |cb| wrap(cb) },
      on_cursor: opts[:on_cursor]?.try { |cb| wrap(cb) },
      style: style,
    )
  end

  def self.make_area(**opts) : Ori::TextArea
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
    Ori::TextArea.new(
      value: (opts[:value]? || "").as(String),
      on_change: opts[:on_change]?.try { |cb| wrap(cb) },
      on_cursor: opts[:on_cursor]?.try { |cb| wrap(cb) },
      cursor_row: (opts[:cursor_row]? || 0).as(Int32),
      cursor_col: opts[:cursor_col]?.as?(Int32),
      char_limit: (opts[:char_limit]? || 0).as(Int32),
      show_line_numbers: (opts[:show_line_numbers]? || false).as(Bool),
      highlights: opts[:highlights]?.try(&.as(Array(Tuple(Int32, Int32, Int32)))) || [] of Tuple(Int32, Int32, Int32),
      style: style,
    )
  end

  def self.make_text_area(**opts) : Ori::TextArea
    Ori::DSL.make_area(**opts)
  end

  def box(**opts, &block) : Ori::Box
    children = [] of Ori::Node
    style = Ori::DSL.extract_style(**opts)
    b = Ori::Box.new(children, style)
    with b yield
    b
  end

  def text(content : String, **opts) : Ori::TextNode
    cursor_col = opts[:cursor_col]?.as?(Int32)
    Ori::TextNode.new(content, cursor_col, Ori::DSL.extract_style(**opts))
  end

  def input(**opts) : Ori::InputNode
    Ori::DSL.make_input(**opts)
  end

  def area(**opts) : Ori::TextArea
    Ori::DSL.make_area(**opts)
  end

  def text_area(**opts) : Ori::TextArea
    Ori::DSL.make_area(**opts)
  end

  def progress_bar(**opts) : Ori::ProgressBar
    Ori::DSL.make_progress_bar(**opts)
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
      on_scroll: opts[:on_scroll]?.try { |cb| wrap(cb) },
      style: Ori::DSL.extract_style(**opts),
    )
  end

  def self.make_table(**opts) : Ori::Table
    Ori::Table.new(
      headers: opts[:headers]?.try(&.as(Array(String))) || [] of String,
      rows: opts[:rows]?.try(&.as(Array(Array(String)))) || [] of Array(String),
      selected_row: opts[:selected_row]?.try(&.as(Int32)) || 0,
      on_change: opts[:on_change]?.try { |cb| wrap(cb) },
      on_select: opts[:on_select]?.try { |cb| wrap(cb) },
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
      on_select: opts[:on_select]?.try { |cb| wrap(cb) },
      on_change: opts[:on_change]?.try { |cb| wrap(cb) },
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

  def self.make_select(**opts) : Ori::Select
    Ori::Select.new(
      options: opts[:options]?.try(&.as(Array(String))) || [] of String,
      selected: opts[:selected]?.try(&.as(Int32)) || 0,
      highlighted: opts[:highlighted]?.try(&.as(Int32)) || -1,
      open: opts[:open]?.try(&.as(Bool)) || false,
      on_change: opts[:on_change]?.try { |cb| wrap(cb) },
      on_toggle: opts[:on_toggle]?.try { |cb| wrap(cb) },
      on_highlight: opts[:on_highlight]?.try { |cb| wrap(cb) },
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
      on_change: opts[:on_change]?.try { |cb| wrap(cb) },
      on_toggle: opts[:on_toggle]?.try { |cb| wrap(cb) },
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
      on_change: opts[:on_change]?.try { |cb| wrap(cb) },
      on_toggle: opts[:on_toggle]?.try { |cb| wrap(cb) },
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
      on_select: opts[:on_select]?.try { |cb| wrap(cb) },
      style: Ori::DSL.extract_style(**opts),
    )
  end

  def self.make_markdown(**opts) : Ori::MarkdownNode
    Ori::MarkdownNode.new(
      content: (opts[:content]? || "").as(String),
      y_offset: (opts[:y_offset]? || 0).as(Int32),
      on_scroll: opts[:on_scroll]?.try { |cb| wrap(cb) },
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

  def self.make_canvas(**opts, &block : Ori::Canvas -> Nil) : Ori::CanvasNode
    Ori::CanvasNode.new(
      sub_x: opts[:sub_x]?.try(&.as(Int32)) || 2,
      sub_y: opts[:sub_y]?.try(&.as(Int32)) || 2,
      style: Ori::DSL.extract_style(**opts),
      &block
    )
  end

  def self.make_tabs(**opts) : Ori::Tabs
    Ori::Tabs.new(
      tabs: opts[:tabs]?.try(&.as(Array(String))) || [] of String,
      active: opts[:active]?.try(&.as(Int32)) || 0,
      on_change: opts[:on_change]?.try { |cb| wrap(cb) },
      style: Ori::DSL.extract_style(**opts),
    )
  end

  def self.make_button(**opts) : Ori::Button
    Ori::Button.new(
      label: (opts[:label]? || "Button").as(String),
      variant: (opts[:variant]? || :default).as(Symbol),
      on_press: opts[:on_press]?.try { |cb| wrap(cb) },
      style: Ori::DSL.extract_style(**opts),
    )
  end

  def self.make_checkbox(**opts) : Ori::Checkbox
    Ori::Checkbox.new(
      label: (opts[:label]? || "").as(String),
      checked: (opts[:checked]? || false).as(Bool),
      on_change: opts[:on_change]?.try { |cb| wrap(cb) },
      style: Ori::DSL.extract_style(**opts),
    )
  end

  def self.make_tree(**opts) : Ori::Tree
    Ori::Tree.new(
      root: opts[:root]?.try(&.as(Ori::Tree::Node)),
      on_select: opts[:on_select]?.try { |cb| wrap(cb) },
      style: Ori::DSL.extract_style(**opts),
    )
  end

  def self.make_slider(**opts) : Ori::Slider
    Ori::Slider.new(
      min: (opts[:min]? || 0.0).as(Float64),
      max: (opts[:max]? || 100.0).as(Float64),
      value: (opts[:value]? || 0.0).as(Float64),
      step: (opts[:step]? || 1.0).as(Float64),
      on_change: opts[:on_change]?.try { |cb| wrap(cb) },
      style: Ori::DSL.extract_style(**opts),
    )
  end

  def self.make_radio(**opts) : Ori::Radio
    Ori::Radio.new(
      label: (opts[:label]? || "").as(String),
      selected: (opts[:selected]? || false).as(Bool),
      on_change: opts[:on_change]?.try { |cb| wrap(cb) },
      style: Ori::DSL.extract_style(**opts),
    )
  end

  def self.make_radio_group(**opts) : Ori::RadioGroup
    Ori::RadioGroup.new(
      labels: opts[:labels]?.try(&.as(Array(String))) || [] of String,
      selected: (opts[:selected]? || 0).as(Int32),
      on_change: opts[:on_change]?.try { |cb| wrap(cb) },
      style: Ori::DSL.extract_style(**opts),
    )
  end

  def self.make_toast(**opts) : Ori::Toast
    Ori::Toast.new(
      message: (opts[:message]? || "").as(String),
      variant: (opts[:variant]? || :info).as(Symbol),
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

  def self.extract_style(**opts) : Ori::S
    StyleArgs.new(
      fg: opts[:fg]?.as?(String), bg: opts[:bg]?.as?(String),
      bold: (opts[:bold]? || false).as(Bool), dim: (opts[:dim]? || false).as(Bool),
      underline: (opts[:underline]? || false).as(Bool), strikethrough: (opts[:strikethrough]? || false).as(Bool),
      border: opts[:border]?, border_fg: opts[:border_fg]?.as?(String),
      padding: opts[:padding]?.as?(Int32 | Tuple(Int32, Int32) | Tuple(Int32, Int32, Int32, Int32)),
      width: opts[:width]?.as?(Int32 | String), height: opts[:height]?.as?(Int32 | String),
      min_width: opts[:min_width]?.as?(Int32), max_width: opts[:max_width]?.as?(Int32),
      min_height: opts[:min_height]?.as?(Int32), max_height: opts[:max_height]?.as?(Int32),
      spacing: (opts[:spacing]? || 0).as(Int32),
      margin: opts[:margin]?.as?(Int32 | Tuple(Int32, Int32) | Tuple(Int32, Int32, Int32, Int32)),
      flex: (opts[:flex]? || 0).as(Int32), direction: (opts[:direction]? || :vertical).as(Symbol),
      align: (opts[:align]? || :left).as(Symbol), focusable: (opts[:focusable]? || false).as(Bool),
      scrollable: (opts[:scrollable]? || false).as(Bool),
      bar_style: (opts[:bar_style]? || :solid).as(Symbol),
      gradient_to: opts[:gradient_to]?.as?(String),
    ).to_s
  end

  def spinner(**opts) : Ori::Spinner
    Ori::DSL.make_spinner(**opts)
  end

  def table(**opts) : Ori::Table
    Ori::DSL.make_table(**opts)
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

  def canvas(**opts, &block : Ori::Canvas -> Nil) : Ori::CanvasNode
    Ori::DSL.make_canvas(**opts, &block)
  end

  def tabs(**opts) : Ori::Tabs
    Ori::DSL.make_tabs(**opts)
  end

  def button(**opts) : Ori::Button
    Ori::DSL.make_button(**opts)
  end

  def checkbox(**opts) : Ori::Checkbox
    Ori::DSL.make_checkbox(**opts)
  end

  def tree(**opts) : Ori::Tree
    Ori::DSL.make_tree(**opts)
  end

  def slider(**opts) : Ori::Slider
    Ori::DSL.make_slider(**opts)
  end

  def radio(**opts) : Ori::Radio
    Ori::DSL.make_radio(**opts)
  end

  def radio_group(**opts) : Ori::RadioGroup
    Ori::DSL.make_radio_group(**opts)
  end

  def toast(**opts) : Ori::Toast
    Ori::DSL.make_toast(**opts)
  end

  def help(**opts) : Ori::Help
    Ori::DSL.make_help(**opts)
  end
end
