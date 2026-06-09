class Ori::Box < Ori::Node
  getter children : Array(Ori::Node)
  @scroll_offset : Int32

  def initialize(@children : Array(Ori::Node) = [] of Ori::Node, style : Ori::S = Ori::S.none)
    super(style)
    @scroll_offset = 0
  end

  def add(node : Ori::Node) : Nil
    @children << node
  end

  def attach(node : Ori::Node) : Ori::Node
    @children << node
    node
  end

  def content_height : Int32
    if @style.direction == :vertical
      @children.sum(&.content_height)
    else
      @children.empty? ? 0 : @children.map(&.content_height).max
    end
  end

  def content_width : Int32
    if @style.direction == :horizontal
      @children.sum(&.content_width)
    else
      @children.empty? ? 0 : @children.map(&.content_width).max
    end
  end

  def layout : Nil
    Ori::Layout.compute(self)
  end

  getter scroll_offset : Int32

  def scrollable? : Bool
    @style.scrollable
  end

  def focusable? : Bool
    @style.focusable
  end

  def on_key(key : Ori::Key) : Bool
    return false unless scrollable?
    case
    when key.text == "j" || key.code.down?
      scroll_by(1); true
    when key.text == "k" || key.code.up?
      scroll_by(-1); true
    when key.code.space? || key.text == "f"
      scroll_by(content_rect.h); true
    when key.text == "b"
      scroll_by(-content_rect.h); true
    when key.text == "g"
      @scroll_offset = 0; true
    when key.text == "G"
      @scroll_offset = max_scroll; true
    else
      false
    end
  end

  private def scroll_by(delta : Int32) : Nil
    @scroll_offset = (@scroll_offset + delta).clamp(0, max_scroll)
  end

  private def max_scroll : Int32
    return 0 if @children.empty?
    cr = content_rect
    last = @children.last
    bottom = last.rect.y + last.rect.h
    {bottom - (cr.y + cr.h), 0}.max
  end

  private def content_rect : Ori::Rect
    r = @rect
    s = @style
    bs = s.border_size
    Ori::Rect.new(
      r.x + s.padding_left + bs,
      r.y + s.padding_top + bs,
      {r.w - s.hpadding - bs * 2, 0}.max,
      {r.h - s.vpadding - bs * 2, 0}.max
    )
  end

  private def shift_subtree(node : Ori::Node, dy : Int32) : Nil
    node.rect = Ori::Rect.new(node.rect.x, node.rect.y + dy, node.rect.w, node.rect.h)
    if node.is_a?(Ori::Box)
      node.children.each { |c| shift_subtree(c, dy) }
    end
  end

  def render(io : IO) : Nil
    propagate_bg
    r = @rect
    bg = @style.bg
    bs = @style.border
    has_border = bs != :none

    if has_border
      fg = @style.border_fg || @style.fg
      fill_w = {r.w - 2, 0}.max
      c = Ori.border_chars(bs)
      h = c[:h].to_s
      top = Ori::Color.paint("#{c[:tl]}#{h * fill_w}#{c[:tr]}", fg, bg)
      bot = Ori::Color.paint("#{c[:bl]}#{h * fill_w}#{c[:br]}", fg, bg)
      lside = Ori::Color.paint("#{c[:v]}", fg, bg)
      rside = Ori::Color.paint("#{c[:v]}", fg, bg)
      fill = bg ? Ori::Color.paint(" " * fill_w, nil, bg) : " " * fill_w
      io << Ori::Term.move(r.x, r.y) << top
      (1...r.h - 1).each do |row|
        io << Ori::Term.move(r.x, r.y + row) << lside << fill << rside
      end
      io << Ori::Term.move(r.x, r.y + r.h - 1) << bot
    elsif b = bg
      r.h.times do |row|
        io << Ori::Term.move(r.x, r.y + row) << Ori::Color.bg(b, " " * r.w)
      end
    end
    @children.each do |child|
      child.render(io)
    end
  end

  protected def propagate_bg : Nil
    if bg = effective_bg
      @children.each do |child|
        child.inherited_bg = bg unless child.style.bg
        if child.is_a?(Ori::Box)
          child.propagate_bg
        end
      end
    end
  end

  def render_screen(screen : Ori::Screen) : Nil
    propagate_bg
    draw_frame_screen(screen)
    if scrollable?
      render_scrolled_children(screen)
    else
      @children.each do |child|
        child.render_screen(screen)
      end
    end
  end

  private def render_scrolled_children(screen : Ori::Screen) : Nil
    auto_scroll
    cr = content_rect
    screen.push_clip(cr.x, cr.y, cr.w, cr.h)
    @children.each do |child|
      shift_subtree(child, -@scroll_offset)
      child.render_screen(screen)
      shift_subtree(child, @scroll_offset)
    end
    screen.pop_clip
  end

  private def auto_scroll : Nil
    cr = content_rect
    target = find_focused_rect(self)
    return unless target
    ty = target.y
    th = target.h
    if ty < cr.y
      @scroll_offset -= cr.y - ty
    elsif ty + th > cr.y + cr.h
      @scroll_offset += (ty + th) - (cr.y + cr.h)
    end
    @scroll_offset = @scroll_offset.clamp(0, max_scroll)
  end

  private def find_focused_rect(node : Ori::Node) : Ori::Rect?
    if node.focused
      node.rect
    elsif node.is_a?(Ori::Box)
      node.children.each do |c|
        r = find_focused_rect(c)
        return r if r
      end
      nil
    else
      nil
    end
  end

  private def draw_frame_screen(screen : Ori::Screen) : Nil
    r = @rect
    bg = effective_bg
    bs = @style.border
    has_border = bs != :none
    fg = @style.border_fg || @style.fg

    if has_border
      c = Ori.border_chars(bs)
      fw = {r.w - 2, 0}.max

      screen.put(r.x, r.y, c[:tl], fg: fg, bg: bg)
      fw.times do |i|
        screen.put(r.x + 1 + i, r.y, c[:h], fg: fg, bg: bg)
      end
      screen.put(r.x + r.w - 1, r.y, c[:tr], fg: fg, bg: bg)

      (1...r.h - 1).each do |row|
        screen.put(r.x, r.y + row, c[:v], fg: fg, bg: bg)
        fw.times do |i|
          screen.put(r.x + 1 + i, r.y + row, ' ', bg: bg)
        end
        screen.put(r.x + r.w - 1, r.y + row, c[:v], fg: fg, bg: bg)
      end

      screen.put(r.x, r.y + r.h - 1, c[:bl], fg: fg, bg: bg)
      fw.times do |i|
        screen.put(r.x + 1 + i, r.y + r.h - 1, c[:h], fg: fg, bg: bg)
      end
      screen.put(r.x + r.w - 1, r.y + r.h - 1, c[:br], fg: fg, bg: bg)
    elsif b = bg
      r.h.times do |row|
        r.w.times do |col|
          screen.put(r.x + col, r.y + row, ' ', bg: b)
        end
      end
    end
  end

  def focusable_nodes : Array(Ori::Node)
    result = [] of Ori::Node
    result << self if focusable?
    @children.each do |child|
      if child.is_a?(Ori::Box)
        result.concat(child.focusable_nodes)
      elsif child.focusable?
        result << child
      end
    end
    result
  end

  def text(content : String, **opts) : Ori::TextNode
    cursor_col = opts[:cursor_col]?.as?(Int32)
    t = Ori::TextNode.new(content, cursor_col, Ori::DSL.extract_style(**opts))
    add(t)
    t
  end

  def box(**opts, &block) : Ori::Box
    children = [] of Ori::Node
    style = Ori::DSL.extract_style(**opts)
    b = Ori::Box.new(children, style)
    with b yield
    add(b)
    b
  end

  def input(**opts) : Ori::InputNode
    i = Ori::DSL.make_input(**opts)
    add(i)
    i
  end

  def area(**opts) : Ori::TextArea
    a = Ori::DSL.make_area(**opts)
    add(a)
    a
  end

  def text_area(**opts) : Ori::TextArea
    a = Ori::DSL.make_area(**opts)
    add(a)
    a
  end

  def progress_bar(**opts) : Ori::ProgressBar
    p = Ori::DSL.make_progress_bar(**opts)
    add(p)
    p
  end

  def spinner(**opts) : Ori::Spinner
    s = Ori::DSL.make_spinner(**opts)
    add(s)
    s
  end

  def table(**opts) : Ori::Table
    t = Ori::DSL.make_table(**opts)
    add(t)
    t
  end

  def list(**opts) : Ori::List
    l = Ori::DSL.make_list(**opts)
    add(l)
    l
  end

  def viewport(**opts) : Ori::Viewport
    v = Ori::DSL.make_viewport(**opts)
    add(v)
    v
  end

  def dropdown(**opts) : Ori::Select
    s = Ori::DSL.make_select(**opts)
    add(s)
    s
  end

  def date_picker(**opts) : Ori::DatePicker
    dp = Ori::DSL.make_date_picker(**opts)
    add(dp)
    dp
  end

  def datetime_picker(**opts) : Ori::DateTimePicker
    dtp = Ori::DSL.make_datetime_picker(**opts)
    add(dtp)
    dtp
  end

  def file_picker(**opts) : Ori::FilePicker
    fp = Ori::DSL.make_file_picker(**opts)
    add(fp)
    fp
  end

  def markdown(**opts) : Ori::MarkdownNode
    md = Ori::DSL.make_markdown(**opts)
    add(md)
    md
  end

  def sparkline(**opts) : Ori::Sparkline
    sl = Ori::DSL.make_sparkline(**opts)
    add(sl)
    sl
  end

  def tabs(**opts) : Ori::Tabs
    tb = Ori::DSL.make_tabs(**opts)
    add(tb)
    tb
  end

  def button(**opts) : Ori::Button
    btn = Ori::DSL.make_button(**opts)
    add(btn)
    btn
  end

  def checkbox(**opts) : Ori::Checkbox
    cb = Ori::DSL.make_checkbox(**opts)
    add(cb)
    cb
  end

  def tree(**opts) : Ori::Tree
    tr = Ori::DSL.make_tree(**opts)
    add(tr)
    tr
  end

  def slider(**opts) : Ori::Slider
    sl = Ori::DSL.make_slider(**opts)
    add(sl)
    sl
  end

  def radio(**opts) : Ori::Radio
    r = Ori::DSL.make_radio(**opts)
    add(r)
    r
  end

  def radio_group(**opts) : Ori::RadioGroup
    rg = Ori::DSL.make_radio_group(**opts)
    add(rg)
    rg
  end

  def toast(**opts) : Ori::Toast
    t = Ori::DSL.make_toast(**opts)
    add(t)
    t
  end

  def help(**opts) : Ori::Help
    h = Ori::DSL.make_help(**opts)
    add(h)
    h
  end
end
