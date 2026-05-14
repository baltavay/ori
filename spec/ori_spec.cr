require "spec"
require "../src/ori"

class CalendarHelperWrapper
  include Ori::CalendarHelper
end

describe Ori::Key do
  it "creates with text" do
    k = Ori::Key.new(text: "a")
    k.printable?.should be_true
    k.to_s.should eq("a")
  end

  it "creates ctrl key" do
    k = Ori::Key.new(text: "c", ctrl: true)
    k.printable?.should be_false
    k.to_s.should eq("ctrl+c")
  end
end

describe Ori::S do
  it "defaults" do
    s = Ori::S.new
    s.bold.should be_false
    s.border.should eq(:none)
    s.padding.should eq(0)
    s.direction.should eq(:vertical)
  end

  it "parses padding int" do
    s = Ori::S.new(padding: 2)
    s.padding_top.should eq(2)
    s.padding_left.should eq(2)
  end

  it "parses padding 4-tuple" do
    s = Ori::S.new(padding: {1, 2, 3, 4})
    s.padding_top.should eq(1)
    s.padding_right.should eq(2)
    s.padding_bottom.should eq(3)
    s.padding_left.should eq(4)
  end

  it "calculates frame sizes" do
    s = Ori::S.new(border: true, padding: 1)
    s.frame_h.should eq(4)
    s.frame_v.should eq(4)
  end
end

describe Ori::Rect do
  it "computes inner rect" do
    r = Ori::Rect.new(0, 0, 10, 10)
    s = Ori::S.new(border: true, padding: 1)
    inner = r.inner(s)
    inner.x.should eq(1)
    inner.y.should eq(1)
    inner.w.should eq(8)
    inner.h.should eq(8)
  end
end

describe Ori::InputParser do
  it "parses printable" do
    Ori::InputParser.new.parse('a'.ord.to_u8).not_nil!.text.should eq("a")
  end

  it "parses enter" do
    Ori::InputParser.new.parse(0x0d_u8).not_nil!.code.should eq(Ori::Key::Code::Enter)
  end

  it "parses arrow key" do
    p = Ori::InputParser.new
    p.parse(0x1b_u8).should be_nil
    p.parse(0x5b_u8).should be_nil
    p.parse('A'.ord.to_u8).not_nil!.code.should eq(Ori::Key::Code::Up)
  end
end

describe Ori::InputNode do
  it "handles typing" do
    i = Ori::InputNode.new
    i.rect = Ori::Rect.new(0, 0, 20, 1)
    i.on_key(Ori::Key.new(text: "a"))
    i.on_key(Ori::Key.new(text: "b"))
    i.value.should eq("ab")
  end

  it "handles backspace" do
    i = Ori::InputNode.new(value: "abc")
    i.rect = Ori::Rect.new(0, 0, 20, 1)
    i.on_key(Ori::Key.new(code: :backspace))
    i.value.should eq("ab")
  end
end

describe Ori::AreaNode do
  it "handles typing" do
    a = Ori::AreaNode.new
    a.rect = Ori::Rect.new(0, 0, 20, 5)
    a.on_key(Ori::Key.new(text: "a"))
    a.on_key(Ori::Key.new(code: :enter))
    a.on_key(Ori::Key.new(text: "b"))
    a.value.should eq("a\nb")
  end
end

describe "content_width" do
  it "TextNode returns max line width" do
    t = Ori::TextNode.new("hello\nworld!")
    t.content_width.should eq(6)
  end

  it "InputNode returns value size plus border" do
    i = Ori::InputNode.new(value: "hello", placeholder: "type here",
      style: Ori::S.new(border: true))
    i.content_width.should eq(10)
  end

  it "AreaNode returns max line width plus border" do
    a = Ori::AreaNode.new(value: "hi\nworld",
      style: Ori::S.new(border: true))
    a.content_width.should eq(6)
  end

  it "Box sums width in horizontal" do
    b = Ori::Box.new([
      Ori::TextNode.new("hi"),
      Ori::TextNode.new("world"),
    ] of Ori::Node, Ori::S.new(direction: :horizontal))
    b.content_width.should eq(7)
  end
end

describe Ori::Layout do
  it "layouts vertical children" do
    root = Ori::Box.new([
      Ori::TextNode.new("hello"),
      Ori::TextNode.new("world"),
    ] of Ori::Node)
    root.rect = Ori::Rect.new(0, 0, 40, 10)
    Ori::Layout.compute(root)
    root.children[0].rect.y.should eq(0)
    root.children[1].rect.y.should eq(1)
    root.children[0].rect.w.should eq(40)
  end

  it "layouts horizontal children" do
    left = Ori::TextNode.new("left")
    right = Ori::TextNode.new("right")
    root = Ori::Box.new([left, right] of Ori::Node, Ori::S.new(direction: :horizontal))
    root.rect = Ori::Rect.new(0, 0, 40, 10)
    Ori::Layout.compute(root)
    left.rect.x.should eq(0)
    right.rect.x.should eq(4)
    left.rect.h.should eq(10)
    right.rect.h.should eq(10)
  end

  it "respects fixed height" do
    child2 = Ori::TextNode.new("hi", Ori::S.new(height: 3))
    root2 = Ori::Box.new([child2] of Ori::Node)
    root2.rect = Ori::Rect.new(0, 0, 40, 10)
    Ori::Layout.compute(root2)
    child2.rect.h.should eq(3)
  end

  it "distributes flex" do
    a = Ori::Box.new([] of Ori::Node, Ori::S.new(flex: 1))
    b = Ori::Box.new([] of Ori::Node, Ori::S.new(flex: 1))
    root = Ori::Box.new([a, b] of Ori::Node)
    root.rect = Ori::Rect.new(0, 0, 40, 10)
    Ori::Layout.compute(root)
    a.rect.h.should eq(5)
    b.rect.h.should eq(5)
  end
end

describe Ori::DSL do
  it "builds style from kwargs" do
    s = Ori::DSL::StyleArgs.new(fg: "#fff", bold: true, padding: 2).to_s
    s.fg.should eq("#fff")
    s.bold.should be_true
    s.padding.should eq(2)
  end

  it "handles string width percentage" do
    s = Ori::DSL::StyleArgs.new(width: "50%").to_s
    s.width_pct.should eq(50.0)
    s.width.should be_nil
  end

  it "makes input with style" do
    i = Ori::DSL.make_input(value: "hello", focusable: true, fg: "#fff")
    i.value.should eq("hello")
    i.style.fg.should eq("#fff")
  end

  it "makes area with style" do
    a = Ori::DSL.make_area(value: "hello\nworld", focusable: true)
    a.value.should eq("hello\nworld")
    a.style.focusable.should be_true
  end

  it "makes progress_bar with style" do
    p = Ori::DSL.make_progress_bar(value: 0.5, bar_style: :blocks)
    p.value.should eq(0.5)
    p.style.bar_style.should eq(:blocks)
  end

  it "makes spinner with style" do
    s = Ori::DSL.make_spinner(type: :line)
    s.content_width.should eq(1)
    s.content_height.should eq(1)
  end
end

describe Ori::ProgressBar do
  it "clamps value on init" do
    p = Ori::ProgressBar.new(150.0)
    p.value.should eq(100.0)
    p = Ori::ProgressBar.new(-5.0)
    p.value.should eq(0.0)
  end

  it "clamps value on set" do
    p = Ori::ProgressBar.new(50.0)
    p.value = 200.0
    p.value.should eq(100.0)
    p.value = -10.0
    p.value.should eq(0.0)
  end

  it "defaults value to 0 and max to 100" do
    p = Ori::ProgressBar.new
    p.value.should eq(0.0)
    p.max.should eq(100.0)
  end

  it "defaults content_width to 10" do
    p = Ori::ProgressBar.new
    p.content_width.should eq(10)
  end

  it "respects explicit width" do
    p = Ori::ProgressBar.new(style: Ori::S.new(width: 20))
    p.content_width.should eq(20)
  end

  it "content_height is 1" do
    p = Ori::ProgressBar.new
    p.content_height.should eq(1)
  end

  it "parses hex color" do
    r, g, b = Ori::Color.hex_rgb("#7D56F4")
    r.should eq(125)
    g.should eq(86)
    b.should eq(244)
  end

  it "renders solid bar" do
    p = Ori::ProgressBar.new(50.0)
    p.rect = Ori::Rect.new(0, 0, 10, 1)
    io = IO::Memory.new
    p.render(io)
    out = io.to_s
    out.should contain("█████     ")
  end

  it "renders blocks bar" do
    p = Ori::ProgressBar.new(50.0, style: Ori::S.new(bar_style: :blocks))
    p.rect = Ori::Rect.new(0, 0, 10, 1)
    io = IO::Memory.new
    p.render(io)
    out = io.to_s
    out.should contain("█████░░░░░")
  end
end

describe Ori::Spinner do
  it "defaults content_width to 1" do
    s = Ori::Spinner.new
    s.content_width.should eq(1)
  end

  it "defaults content_height to 1" do
    s = Ori::Spinner.new
    s.content_height.should eq(1)
  end

  it "returns a frame string" do
    s = Ori::Spinner.new(type: :line)
    f = s.frame
    ["|", "/", "-", "\\"].should contain(f)
  end

  it "frame= resets to first frame" do
    s = Ori::Spinner.new(type: :line, interval: 0.1.seconds)
    s.frame = 0
    s.frame.should eq("-")
  end

  it "reset restarts" do
    s = Ori::Spinner.new(type: :line, interval: 0.1.seconds)
    s.frame = 2
    s.reset
    s.frame.should eq("-")
  end

  it "supports all frame types" do
    [:dots, :line, :arc, :circle, :pipe, :triangle, :bounce, :star].each do |type|
      s = Ori::Spinner.new(type: type)
      s.frame.should_not be_nil
      s.frame.size.should be > 0
    end
  end

  it "falls back to dots for unknown type" do
    s = Ori::Spinner.new(type: :unknown)
    Ori::Spinner::FRAMES[:dots].should contain(s.frame)
  end
end

describe Ori::Term do
  describe "cursor_shape" do
    it "returns block" do
      Ori::Term.cursor_shape(:block).should eq("\e[2 q")
    end

    it "returns block_blink" do
      Ori::Term.cursor_shape(:block_blink).should eq("\e[1 q")
    end

    it "returns underline" do
      Ori::Term.cursor_shape(:underline).should eq("\e[4 q")
    end

    it "returns underline_blink" do
      Ori::Term.cursor_shape(:underline_blink).should eq("\e[3 q")
    end

    it "returns bar" do
      Ori::Term.cursor_shape(:bar).should eq("\e[6 q")
    end

    it "returns bar_blink" do
      Ori::Term.cursor_shape(:bar_blink).should eq("\e[5 q")
    end

    it "defaults to block for unknown" do
      Ori::Term.cursor_shape(:unknown).should eq("\e[2 q")
    end
  end
end

describe Ori::Table do
  it "defaults content_height to 1" do
    t = Ori::Table.new
    t.content_height.should eq(1)
  end

  it "computes content_height with headers and border" do
    t = Ori::Table.new(
      headers: ["Name", "Age"],
      rows: [["Alice", "30"], ["Bob", "25"]],
      style: Ori::S.new(border: true),
    )
    t.content_height.should eq(6) # top + header + sep + 2 rows + bottom
  end

  it "computes content_height without border" do
    t = Ori::Table.new(
      headers: ["Name", "Age"],
      rows: [["Alice", "30"]],
    )
    t.content_height.should eq(2) # header + 1 row
  end

  it "computes content_width with border" do
    t = Ori::Table.new(
      headers: ["Name", "Age"],
      rows: [["Alice", "30"]],
      style: Ori::S.new(border: true),
    )
    # natural widths: max(4,5)=5, max(3,2)=3 => sum=8, + border overhead (n+1=3) = 11
    t.content_width.should eq(11)
  end

  it "moves selection" do
    t = Ori::Table.new(
      headers: ["Name"],
      rows: [["A"], ["B"], ["C"]],
    )
    t.selected_row.should eq(0)
    t.move_down
    t.selected_row.should eq(1)
    t.move_down
    t.selected_row.should eq(2)
    t.move_down
    t.selected_row.should eq(2) # clamped
    t.move_top
    t.selected_row.should eq(0)
    t.move_up
    t.selected_row.should eq(0) # clamped
    t.move_bottom
    t.selected_row.should eq(2)
  end

  it "clamps selected_row on rows=" do
    t = Ori::Table.new(
      rows: [["A"], ["B"], ["C"]],
      selected_row: 2,
    )
    t.selected_row.should eq(2)
    t.rows = [["X"]]
    t.selected_row.should eq(0)
  end

  it "returns selected_row_data" do
    t = Ori::Table.new(
      headers: ["Name", "Age"],
      rows: [["Alice", "30"], ["Bob", "25"]],
    )
    t.selected_row_data.should eq(["Alice", "30"])
    t.move_down
    t.selected_row_data.should eq(["Bob", "25"])
  end

  it "handles key navigation" do
    t = Ori::Table.new(
      rows: [["A"], ["B"], ["C"]],
      style: Ori::S.new(focusable: true),
    )
    t.on_key(Ori::Key.new(code: :down)).should be_true
    t.selected_row.should eq(1)
    t.on_key(Ori::Key.new(text: "k")).should be_true
    t.selected_row.should eq(0)
    t.on_key(Ori::Key.new(code: :end)).should be_true
    t.selected_row.should eq(2)
    t.on_key(Ori::Key.new(code: :home)).should be_true
    t.selected_row.should eq(0)
  end

  it "fires on_change when selection changes" do
    changed = [] of Int32
    t = Ori::Table.new(
      rows: [["A"], ["B"]],
      on_change: ->(row : Int32) { changed << row; nil },
    )
    t.on_key(Ori::Key.new(code: :down))
    changed.should eq([1])
  end

  it "does not fire on_change when selection stays same" do
    changed = [] of Int32
    t = Ori::Table.new(
      rows: [["A"]],
      on_change: ->(row : Int32) { changed << row; nil },
    )
    t.on_key(Ori::Key.new(code: :down))
    changed.should be_empty
  end

  it "fires on_select on enter" do
    selected = [] of Int32
    t = Ori::Table.new(
      rows: [["A"], ["B"]],
      selected_row: 1,
      on_select: ->(row : Int32) { selected << row; nil },
    )
    t.on_key(Ori::Key.new(code: :enter))
    selected.should eq([1])
  end

  it "is focusable when style says so" do
    t = Ori::Table.new(style: Ori::S.new(focusable: true))
    t.focusable?.should be_true
    t2 = Ori::Table.new
    t2.focusable?.should be_false
  end

  it "renders to screen" do
    t = Ori::Table.new(
      headers: ["Name", "Age"],
      rows: [["Alice", "30"]],
      style: Ori::S.new(border: true),
    )
    t.rect = Ori::Rect.new(0, 0, 15, 5)
    screen = Ori::Screen.new(15, 5)
    t.render_screen(screen)
    cell_top_left = screen.@back[0]
    cell_top_left.char.should eq('┌')
  end

  it "renders to IO" do
    t = Ori::Table.new(
      headers: ["Name"],
      rows: [["Alice"]],
      style: Ori::S.new(border: true),
    )
    t.rect = Ori::Rect.new(0, 0, 9, 5)
    io = IO::Memory.new
    t.render(io)
    out = io.to_s
    out.should contain("┌")
    out.should contain("Alice")
    out.should contain("└")
  end
end

describe "DSL table" do
  it "makes table via DSL" do
    t = Ori::DSL.make_table(
      headers: ["A", "B"],
      rows: [["1", "2"]],
      border: true,
      focusable: true,
    )
    t.should be_a(Ori::Table)
    t.headers.should eq(["A", "B"])
    t.rows.should eq([["1", "2"]])
    t.focusable?.should be_true
  end

  it "creates table inside box" do
    b = Ori::Box.new([] of Ori::Node)
    tbl = b.table(headers: ["X"], rows: [["1"]], border: true)
    tbl.should be_a(Ori::Table)
    b.children.should contain(tbl)
  end
end

describe Ori::Select do
  it "defaults content_height to 1" do
    s = Ori::Select.new
    s.content_height.should eq(1)
  end

  it "computes content_width from options" do
    s = Ori::Select.new(options: ["Red", "Green", "Blue"])
    s.content_width.should eq(9) # "Green" (5) + " ▾" (2) + "[]" (2) = 9
  end

  it "returns selected_value" do
    s = Ori::Select.new(options: ["A", "B", "C"], selected: 1)
    s.selected_value.should eq("B")
  end

  it "opens on enter" do
    s = Ori::Select.new(options: ["A", "B"], style: Ori::S.new(focusable: true))
    s.open.should be_false
    s.on_key(Ori::Key.new(code: :enter))
    s.open.should be_true
  end

  it "opens on space" do
    s = Ori::Select.new(options: ["A", "B"], style: Ori::S.new(focusable: true))
    s.on_key(Ori::Key.new(code: :space))
    s.open.should be_true
  end

  it "closes on escape when open" do
    s = Ori::Select.new(options: ["A", "B"], style: Ori::S.new(focusable: true))
    s.on_key(Ori::Key.new(code: :enter))
    s.open.should be_true
    s.on_key(Ori::Key.new(code: :escape))
    s.open.should be_false
  end

  it "selects highlighted on enter when open" do
    s = Ori::Select.new(options: ["A", "B", "C"], style: Ori::S.new(focusable: true))
    s.on_key(Ori::Key.new(code: :enter))
    s.on_key(Ori::Key.new(code: :down))
    s.highlighted.should eq(1)
    s.on_key(Ori::Key.new(code: :enter))
    s.selected.should eq(1)
    s.open.should be_false
  end

  it "navigates with j/k when open" do
    s = Ori::Select.new(options: ["A", "B", "C"], style: Ori::S.new(focusable: true))
    s.on_key(Ori::Key.new(code: :enter))
    s.on_key(Ori::Key.new(text: "j"))
    s.highlighted.should eq(1)
    s.on_key(Ori::Key.new(text: "k"))
    s.highlighted.should eq(0)
  end

  it "cycles selection with up/down when closed" do
    s = Ori::Select.new(options: ["A", "B", "C"], style: Ori::S.new(focusable: true))
    s.on_key(Ori::Key.new(code: :down))
    s.selected.should eq(1)
    s.on_key(Ori::Key.new(code: :up))
    s.selected.should eq(0)
  end

  it "clamps at boundaries" do
    s = Ori::Select.new(options: ["A", "B"], style: Ori::S.new(focusable: true))
    s.on_key(Ori::Key.new(code: :up))
    s.selected.should eq(0)
    s.on_key(Ori::Key.new(code: :down))
    s.on_key(Ori::Key.new(code: :down))
    s.selected.should eq(1)
  end

  it "fires on_change when selecting in dropdown" do
    changes = [] of Int32
    s = Ori::Select.new(
      options: ["A", "B", "C"],
      on_change: ->(idx : Int32) { changes << idx; nil },
      style: Ori::S.new(focusable: true),
    )
    s.on_key(Ori::Key.new(code: :enter))
    s.on_key(Ori::Key.new(code: :down))
    s.on_key(Ori::Key.new(code: :enter))
    changes.should eq([1])
  end

  it "fires on_toggle when opening/closing" do
    toggles = [] of Bool
    s = Ori::Select.new(
      options: ["A", "B"],
      on_toggle: ->(open : Bool) { toggles << open; nil },
      style: Ori::S.new(focusable: true),
    )
    s.on_key(Ori::Key.new(code: :enter))
    s.on_key(Ori::Key.new(code: :escape))
    toggles.should eq([true, false])
  end

  it "fires on_highlight when navigating dropdown" do
    highlights = [] of Int32
    s = Ori::Select.new(
      options: ["A", "B", "C"],
      on_highlight: ->(idx : Int32) { highlights << idx; nil },
      style: Ori::S.new(focusable: true),
    )
    s.on_key(Ori::Key.new(code: :enter))
    s.on_key(Ori::Key.new(code: :down))
    highlights.should eq([0, 1])
  end

  it "consumes all keys when open" do
    s = Ori::Select.new(options: ["A"], style: Ori::S.new(focusable: true))
    s.on_key(Ori::Key.new(code: :enter))
    s.on_key(Ori::Key.new(text: "z")).should be_true
  end

  it "renders trigger to screen" do
    s = Ori::Select.new(
      options: ["Red", "Green"],
      selected: 1,
      style: Ori::S.new(fg: "#fff"),
    )
    s.rect = Ori::Rect.new(0, 0, 10, 1)
    screen = Ori::Screen.new(10, 1)
    s.render_screen(screen)
    screen.@back[0].char.should eq('G')
  end

  it "renders dropdown overlay when open" do
    s = Ori::Select.new(
      options: ["A", "B"],
      selected: 0,
      style: Ori::S.new(fg: "#fff"),
    )
    s.on_key(Ori::Key.new(code: :enter))
    s.rect = Ori::Rect.new(0, 0, 5, 1)
    screen = Ori::Screen.new(10, 5)
    s.render_screen(screen)
    s.render_overlay(screen)
    screen.@back[10].char.should eq('┌')
  end
end

describe "DSL select" do
  it "makes select via DSL" do
    s = Ori::DSL.make_select(
      options: ["X", "Y"],
      selected: 1,
      focusable: true,
    )
    s.should be_a(Ori::Select)
    s.selected.should eq(1)
    s.focusable?.should be_true
  end

  it "creates select inside box" do
    b = Ori::Box.new([] of Ori::Node)
    sel = b.dropdown(options: ["A", "B"], focusable: true)
    sel.should be_a(Ori::Select)
    b.children.should contain(sel)
  end
end

describe Ori::DatePicker do
  it "defaults to today" do
    dp = Ori::DatePicker.new(style: Ori::S.new(focusable: true))
    now = Time.utc
    dp.year.should eq(now.year)
    dp.month.should eq(now.month)
    dp.cursor_day.should eq(now.day)
  end

  it "accepts explicit date" do
    dp = Ori::DatePicker.new(year: 2025, month: 6, day: 15, style: Ori::S.new(focusable: true))
    dp.year.should eq(2025)
    dp.month.should eq(6)
    dp.cursor_day.should eq(15)
  end

  it "returns date" do
    dp = Ori::DatePicker.new(year: 2025, month: 3, day: 10, style: Ori::S.new(focusable: true))
    dp.date.should eq(Time.utc(2025, 3, 10))
  end

  it "opens on enter/space" do
    dp = Ori::DatePicker.new(year: 2025, month: 6, day: 15, style: Ori::S.new(focusable: true))
    dp.open.should be_false
    dp.on_key(Ori::Key.new(code: :enter))
    dp.open.should be_true
  end

  it "closes on escape without changing selection" do
    dp = Ori::DatePicker.new(year: 2025, month: 6, day: 15, style: Ori::S.new(focusable: true))
    dp.on_key(Ori::Key.new(code: :enter))
    dp.on_key(Ori::Key.new(text: "l"))
    dp.on_key(Ori::Key.new(code: :escape))
    dp.open.should be_false
    dp.cursor_day.should eq(15)
  end

  it "confirms selection on enter in calendar" do
    dp = Ori::DatePicker.new(year: 2025, month: 6, day: 15, style: Ori::S.new(focusable: true))
    dp.on_key(Ori::Key.new(code: :enter))
    dp.on_key(Ori::Key.new(text: "l"))
    dp.on_key(Ori::Key.new(code: :enter))
    dp.open.should be_false
    dp.cursor_day.should eq(16)
  end

  it "navigates calendar with hjkl" do
    dp = Ori::DatePicker.new(year: 2025, month: 1, day: 15, style: Ori::S.new(focusable: true))
    dp.on_key(Ori::Key.new(code: :enter))
    dp.on_key(Ori::Key.new(text: "l"))
    dp.on_key(Ori::Key.new(code: :enter))
    dp.cursor_day.should eq(16)
  end

  it "wraps to prev/next month in calendar" do
    dp = Ori::DatePicker.new(year: 2025, month: 1, day: 1, style: Ori::S.new(focusable: true))
    dp.on_key(Ori::Key.new(code: :enter))
    dp.on_key(Ori::Key.new(text: "h"))
    dp.on_key(Ori::Key.new(code: :enter))
    dp.month.should eq(12)
    dp.year.should eq(2024)
    dp.cursor_day.should eq(31)
  end

  it "navigates months with H/L in calendar" do
    dp = Ori::DatePicker.new(year: 2025, month: 6, day: 15, style: Ori::S.new(focusable: true))
    dp.on_key(Ori::Key.new(code: :enter))
    dp.on_key(Ori::Key.new(text: "H"))
    dp.on_key(Ori::Key.new(code: :enter))
    dp.month.should eq(5)
  end

  it "navigates years with J/K in calendar" do
    dp = Ori::DatePicker.new(year: 2025, month: 6, day: 15, style: Ori::S.new(focusable: true))
    dp.on_key(Ori::Key.new(code: :enter))
    dp.on_key(Ori::Key.new(text: "K"))
    dp.on_key(Ori::Key.new(code: :enter))
    dp.year.should eq(2024)
  end

  it "jumps to today with t in calendar" do
    dp = Ori::DatePicker.new(year: 2020, month: 1, day: 1, style: Ori::S.new(focusable: true))
    dp.on_key(Ori::Key.new(code: :enter))
    dp.on_key(Ori::Key.new(text: "t"))
    dp.on_key(Ori::Key.new(code: :enter))
    now = Time.utc
    dp.year.should eq(now.year)
    dp.month.should eq(now.month)
  end

  it "fires on_change on confirm" do
    changes = [] of Time
    dp = Ori::DatePicker.new(
      year: 2025, month: 6, day: 15,
      on_change: ->(t : Time) { changes << t; nil },
      style: Ori::S.new(focusable: true),
    )
    dp.on_key(Ori::Key.new(code: :enter))
    dp.on_key(Ori::Key.new(text: "l"))
    dp.on_key(Ori::Key.new(code: :enter))
    changes.size.should eq(1)
    changes[0].day.should eq(16)
  end

  it "fires on_toggle on open/close" do
    toggles = [] of Bool
    dp = Ori::DatePicker.new(
      year: 2025, month: 6, day: 15,
      on_toggle: ->(open : Bool) { toggles << open; nil },
      style: Ori::S.new(focusable: true),
    )
    dp.on_key(Ori::Key.new(code: :enter))
    dp.on_key(Ori::Key.new(code: :escape))
    toggles.should eq([true, false])
  end

  it "does not fire on_change on cancel" do
    changes = [] of Time
    dp = Ori::DatePicker.new(
      year: 2025, month: 6, day: 15,
      on_change: ->(t : Time) { changes << t; nil },
      style: Ori::S.new(focusable: true),
    )
    dp.on_key(Ori::Key.new(code: :enter))
    dp.on_key(Ori::Key.new(code: :escape))
    changes.should be_empty
  end

  it "has correct content dimensions" do
    dp = Ori::DatePicker.new(style: Ori::S.new(focusable: true))
    dp.content_width.should eq(14)
    dp.content_height.should eq(1)
  end

  it "renders trigger to screen" do
    dp = Ori::DatePicker.new(year: 2025, month: 6, day: 15, style: Ori::S.new(fg: "#fff"))
    dp.rect = Ori::Rect.new(0, 0, 14, 1)
    screen = Ori::Screen.new(14, 1)
    dp.render_screen(screen)
    screen.@back[0].char.should eq('2')
    screen.@back[1].char.should eq('0')
  end

  it "renders calendar overlay when open" do
    dp = Ori::DatePicker.new(year: 2025, month: 6, day: 15, style: Ori::S.new(fg: "#fff", focusable: true))
    dp.on_key(Ori::Key.new(code: :enter))
    dp.rect = Ori::Rect.new(0, 0, 14, 1)
    screen = Ori::Screen.new(23, 12)
    dp.render_screen(screen)
    dp.render_overlay(screen)
    screen.@back[23].char.should eq('┌')
  end

  it "blurs by closing calendar" do
    dp = Ori::DatePicker.new(year: 2025, month: 6, day: 15, style: Ori::S.new(focusable: true))
    dp.on_key(Ori::Key.new(code: :enter))
    dp.open.should be_true
    dp.blur
    dp.open.should be_false
  end

  it "consumes all keys when open" do
    dp = Ori::DatePicker.new(year: 2025, month: 6, day: 15, style: Ori::S.new(focusable: true))
    dp.on_key(Ori::Key.new(code: :enter))
    dp.on_key(Ori::Key.new(text: "z")).should be_true
  end

  it "handles set_date" do
    dp = Ori::DatePicker.new(style: Ori::S.new(focusable: true))
    dp.set_date(2025, 12, 25)
    dp.year.should eq(2025)
    dp.month.should eq(12)
    dp.cursor_day.should eq(25)
  end
end

describe Ori::DateTimePicker do
  it "creates with defaults" do
    dtp = Ori::DateTimePicker.new(style: Ori::S.new(focusable: true))
    dtp.hour.should eq(0)
    dtp.minute.should eq(0)
  end

  it "accepts explicit time" do
    dtp = Ori::DateTimePicker.new(hour: 14, minute: 30, style: Ori::S.new(focusable: true))
    dtp.hour.should eq(14)
    dtp.minute.should eq(30)
  end

  it "returns combined datetime" do
    dtp = Ori::DateTimePicker.new(year: 2025, month: 6, day: 15, hour: 14, minute: 30, style: Ori::S.new(focusable: true))
    dtp.date_time.should eq(Time.utc(2025, 6, 15, 14, 30))
  end

  it "opens on enter and starts in date section" do
    dtp = Ori::DateTimePicker.new(style: Ori::S.new(focusable: true))
    dtp.on_key(Ori::Key.new(code: :enter))
    dtp.open.should be_true
    dtp.section.should eq(Ori::DateTimePicker::Section::Date)
  end

  it "tabs from date to time section" do
    dtp = Ori::DateTimePicker.new(style: Ori::S.new(focusable: true))
    dtp.on_key(Ori::Key.new(code: :enter))
    dtp.on_key(Ori::Key.new(code: :tab))
    dtp.section.should eq(Ori::DateTimePicker::Section::Time)
  end

  it "tabs from time back to date section" do
    dtp = Ori::DateTimePicker.new(style: Ori::S.new(focusable: true))
    dtp.on_key(Ori::Key.new(code: :enter))
    dtp.on_key(Ori::Key.new(code: :tab))
    dtp.on_key(Ori::Key.new(code: :tab))
    dtp.section.should eq(Ori::DateTimePicker::Section::Date)
  end

  it "adjusts time with j/k in time section" do
    dtp = Ori::DateTimePicker.new(hour: 12, style: Ori::S.new(focusable: true))
    dtp.on_key(Ori::Key.new(code: :enter))
    dtp.on_key(Ori::Key.new(code: :tab))
    dtp.on_key(Ori::Key.new(text: "j"))
    dtp.on_key(Ori::Key.new(code: :enter))
    dtp.hour.should eq(13)
  end

  it "wraps hour at boundaries" do
    dtp = Ori::DateTimePicker.new(hour: 23, style: Ori::S.new(focusable: true))
    dtp.on_key(Ori::Key.new(code: :enter))
    dtp.on_key(Ori::Key.new(code: :tab))
    dtp.on_key(Ori::Key.new(text: "j"))
    dtp.on_key(Ori::Key.new(code: :enter))
    dtp.hour.should eq(0)
  end

  it "switches time fields with h/l" do
    dtp = Ori::DateTimePicker.new(style: Ori::S.new(focusable: true))
    dtp.on_key(Ori::Key.new(code: :enter))
    dtp.on_key(Ori::Key.new(code: :tab))
    dtp.tfield.should eq(Ori::DateTimePicker::TField::Hour)
    dtp.on_key(Ori::Key.new(text: "l"))
    dtp.tfield.should eq(Ori::DateTimePicker::TField::Minute)
  end

  it "confirms both date and time on enter" do
    dtp = Ori::DateTimePicker.new(year: 2025, month: 6, day: 15, hour: 12, style: Ori::S.new(focusable: true))
    dtp.on_key(Ori::Key.new(code: :enter))
    dtp.on_key(Ori::Key.new(text: "l"))
    dtp.on_key(Ori::Key.new(code: :tab))
    dtp.on_key(Ori::Key.new(text: "j"))
    dtp.on_key(Ori::Key.new(code: :enter))
    dtp.cursor_day.should eq(16)
    dtp.hour.should eq(13)
  end

  it "cancels without changing on escape" do
    dtp = Ori::DateTimePicker.new(year: 2025, month: 6, day: 15, hour: 12, style: Ori::S.new(focusable: true))
    dtp.on_key(Ori::Key.new(code: :enter))
    dtp.on_key(Ori::Key.new(code: :tab))
    dtp.on_key(Ori::Key.new(text: "k"))
    dtp.on_key(Ori::Key.new(code: :escape))
    dtp.hour.should eq(12)
  end

  it "fires on_change on confirm" do
    changes = [] of Time
    dtp = Ori::DateTimePicker.new(
      year: 2025, month: 6, day: 15, hour: 12,
      on_change: ->(t : Time) { changes << t; nil },
      style: Ori::S.new(focusable: true),
    )
    dtp.on_key(Ori::Key.new(code: :enter))
    dtp.on_key(Ori::Key.new(code: :tab))
    dtp.on_key(Ori::Key.new(text: "j"))
    dtp.on_key(Ori::Key.new(code: :enter))
    changes.size.should eq(1)
    changes[0].hour.should eq(13)
  end

  it "fires on_toggle on open/close" do
    toggles = [] of Bool
    dtp = Ori::DateTimePicker.new(
      on_toggle: ->(open : Bool) { toggles << open; nil },
      style: Ori::S.new(focusable: true),
    )
    dtp.on_key(Ori::Key.new(code: :enter))
    dtp.on_key(Ori::Key.new(code: :escape))
    toggles.should eq([true, false])
  end

  it "has correct content dimensions" do
    dtp = Ori::DateTimePicker.new(style: Ori::S.new(focusable: true))
    dtp.content_width.should eq(20)
    dtp.content_height.should eq(1)
  end

  it "renders trigger to screen" do
    dtp = Ori::DateTimePicker.new(year: 2025, month: 6, day: 15, hour: 14, minute: 30, style: Ori::S.new(fg: "#fff"))
    dtp.rect = Ori::Rect.new(0, 0, 20, 1)
    screen = Ori::Screen.new(20, 1)
    dtp.render_screen(screen)
    screen.@back[0].char.should eq('2')
  end

  it "renders overlay with calendar and time when open" do
    dtp = Ori::DateTimePicker.new(year: 2025, month: 6, day: 15, hour: 14, minute: 30, style: Ori::S.new(fg: "#fff", focusable: true))
    dtp.on_key(Ori::Key.new(code: :enter))
    dtp.rect = Ori::Rect.new(0, 0, 20, 1)
    screen = Ori::Screen.new(23, 16)
    dtp.render_screen(screen)
    dtp.render_overlay(screen)
    screen.@back[23].char.should eq('┌')
  end

  it "handles set_datetime" do
    dtp = Ori::DateTimePicker.new(style: Ori::S.new(focusable: true))
    dtp.set_datetime(2025, 12, 25, 14, 30)
    dtp.year.should eq(2025)
    dtp.month.should eq(12)
    dtp.cursor_day.should eq(25)
    dtp.hour.should eq(14)
    dtp.minute.should eq(30)
  end

  it "blurs by closing" do
    dtp = Ori::DateTimePicker.new(style: Ori::S.new(focusable: true))
    dtp.on_key(Ori::Key.new(code: :enter))
    dtp.open.should be_true
    dtp.blur
    dtp.open.should be_false
  end
end

describe "DSL date_picker" do
  it "makes date_picker via DSL" do
    dp = Ori::DSL.make_date_picker(year: 2025, month: 6, day: 15, focusable: true)
    dp.should be_a(Ori::DatePicker)
    dp.year.should eq(2025)
    dp.focusable?.should be_true
  end

  it "creates date_picker inside box" do
    b = Ori::Box.new([] of Ori::Node)
    dp = b.date_picker(year: 2025, focusable: true)
    dp.should be_a(Ori::DatePicker)
    b.children.should contain(dp)
  end
end

describe "DSL datetime_picker" do
  it "makes datetime_picker via DSL" do
    dtp = Ori::DSL.make_datetime_picker(year: 2025, hour: 14, focusable: true)
    dtp.should be_a(Ori::DateTimePicker)
    dtp.hour.should eq(14)
  end

  it "creates datetime_picker inside box" do
    b = Ori::Box.new([] of Ori::Node)
    dtp = b.datetime_picker(year: 2025, focusable: true)
    dtp.should be_a(Ori::DateTimePicker)
    b.children.should contain(dtp)
  end
end

private def make_scroll_lines(n : Int32) : Array(Ori::Node)
  (1..n).map { |i| Ori::TextNode.new("line #{i}").as(Ori::Node) }
end

describe "scrollable box" do

  it "is focusable when scrollable" do
    b = Ori::Box.new([] of Ori::Node, style: Ori::S.new(scrollable: true))
    b.focusable?.should be_true
  end

  it "is not focusable when not scrollable" do
    b = Ori::Box.new([] of Ori::Node, style: Ori::S.new)
    b.focusable?.should be_false
  end

  it "scrolls down with j" do
    b = Ori::Box.new(make_scroll_lines(10), style: Ori::S.new(scrollable: true, height: 4))
    b.rect = Ori::Rect.new(0, 0, 20, 4)
    b.layout
    b.scroll_offset.should eq(0)
    b.on_key(Ori::Key.new(text: "j"))
    b.scroll_offset.should eq(1)
  end

  it "scrolls up with k" do
    b = Ori::Box.new(make_scroll_lines(10), style: Ori::S.new(scrollable: true, height: 4))
    b.rect = Ori::Rect.new(0, 0, 20, 4)
    b.layout
    b.on_key(Ori::Key.new(text: "j"))
    b.on_key(Ori::Key.new(text: "j"))
    b.scroll_offset.should eq(2)
    b.on_key(Ori::Key.new(text: "k"))
    b.scroll_offset.should eq(1)
  end

  it "does not scroll below max" do
    b = Ori::Box.new(make_scroll_lines(5), style: Ori::S.new(scrollable: true, height: 4))
    b.rect = Ori::Rect.new(0, 0, 20, 4)
    b.layout
    10.times { b.on_key(Ori::Key.new(text: "j")) }
    b.scroll_offset.should eq(1)
  end

  it "does not scroll above 0" do
    b = Ori::Box.new(make_scroll_lines(5), style: Ori::S.new(scrollable: true, height: 4))
    b.rect = Ori::Rect.new(0, 0, 20, 4)
    b.layout
    b.on_key(Ori::Key.new(text: "k"))
    b.scroll_offset.should eq(0)
  end

  it "scrolls page down with f" do
    b = Ori::Box.new(make_scroll_lines(20), style: Ori::S.new(scrollable: true, height: 5))
    b.rect = Ori::Rect.new(0, 0, 20, 5)
    b.layout
    b.on_key(Ori::Key.new(text: "f"))
    b.scroll_offset.should eq(5)
  end

  it "scrolls page up with b" do
    b = Ori::Box.new(make_scroll_lines(20), style: Ori::S.new(scrollable: true, height: 5))
    b.rect = Ori::Rect.new(0, 0, 20, 5)
    b.layout
    b.on_key(Ori::Key.new(text: "f"))
    b.scroll_offset.should eq(5)
    b.on_key(Ori::Key.new(text: "b"))
    b.scroll_offset.should eq(0)
  end

  it "scrolls to top with g" do
    b = Ori::Box.new(make_scroll_lines(10), style: Ori::S.new(scrollable: true, height: 4))
    b.rect = Ori::Rect.new(0, 0, 20, 4)
    b.layout
    b.on_key(Ori::Key.new(text: "j"))
    b.on_key(Ori::Key.new(text: "j"))
    b.on_key(Ori::Key.new(text: "g"))
    b.scroll_offset.should eq(0)
  end

  it "scrolls to bottom with G" do
    b = Ori::Box.new(make_scroll_lines(10), style: Ori::S.new(scrollable: true, height: 4))
    b.rect = Ori::Rect.new(0, 0, 20, 4)
    b.layout
    b.on_key(Ori::Key.new(text: "G"))
    b.scroll_offset.should eq(6)
  end

  it "returns false for keys when not scrollable" do
    b = Ori::Box.new([] of Ori::Node, style: Ori::S.new)
    b.on_key(Ori::Key.new(text: "j")).should be_false
  end

  it "clips children when scrolled" do
    b = Ori::Box.new(make_scroll_lines(5), style: Ori::S.new(scrollable: true, height: 3))
    b.rect = Ori::Rect.new(0, 0, 20, 3)
    b.layout
    b.on_key(Ori::Key.new(text: "j"))
    screen = Ori::Screen.new(20, 10)
    b.render_screen(screen)
    screen.back[0].char.should eq('l')
    screen.back[0 * 20 + 5].char.should eq('2')
    screen.back[3 * 20].char.should eq(' ')
  end
end

describe "Screen clip" do
  it "push_clip and pop_clip restrict put" do
    screen = Ori::Screen.new(10, 10)
    screen.push_clip(2, 2, 3, 3)
    screen.put(1, 2, 'a')
    screen.put(2, 2, 'b')
    screen.put(4, 2, 'c')
    screen.put(5, 2, 'd')
    screen.pop_clip
    back = screen.back
    back[2 * 10 + 1].char.should eq(' ')
    back[2 * 10 + 2].char.should eq('b')
    back[2 * 10 + 4].char.should eq('c')
    back[2 * 10 + 5].char.should eq(' ')
  end

  it "nested clips" do
    screen = Ori::Screen.new(10, 10)
    screen.push_clip(0, 0, 10, 10)
    screen.push_clip(2, 2, 3, 3)
    screen.put(1, 2, 'a')
    screen.put(2, 2, 'b')
    screen.pop_clip
    screen.put(1, 2, 'c')
    screen.pop_clip
    back = screen.back
    back[2 * 10 + 1].char.should eq('c')
    back[2 * 10 + 2].char.should eq('b')
  end
end

describe Ori::Viewport do
  it "initializes with content" do
    vp = Ori::Viewport.new(content: "hello\nworld")
    vp.total_lines.should eq(2)
    vp.content.should eq("hello\nworld")
  end

  it "scrolls down and up" do
    lines = (1..50).map(&.to_s).join('\n')
    vp = Ori::Viewport.new(content: lines)
    vp.y_offset.should eq(0)
    vp.view_down(5)
    vp.y_offset.should eq(5)
    vp.view_up(3)
    vp.y_offset.should eq(2)
  end

  it "clamps scroll to bounds" do
    lines = (1..100).map(&.to_s).join('\n')
    vp = Ori::Viewport.new(content: lines)
    vp.goto_top
    vp.at_top?.should be_true
    vp.view_up(10)
    vp.y_offset.should eq(0)
  end

  it "handles goto_top and goto_bottom" do
    lines = (1..100).map(&.to_s).join('\n')
    vp = Ori::Viewport.new(content: lines)
    vp.goto_bottom
    vp.at_bottom?.should be_true
    vp.goto_top
    vp.at_top?.should be_true
  end

  it "updates content" do
    vp = Ori::Viewport.new(content: "a")
    vp.total_lines.should eq(1)
    vp.content = "a\nb\nc"
    vp.total_lines.should eq(3)
  end

  it "handles empty content" do
    vp = Ori::Viewport.new(content: "")
    vp.total_lines.should eq(1)
  end

  it "handles key input" do
    lines = (1..50).map(&.to_s).join('\n')
    vp = Ori::Viewport.new(content: lines)
    vp.on_key(Ori::Key.new(text: "j")).should be_true
    vp.y_offset.should eq(1)
    vp.on_key(Ori::Key.new(text: "k")).should be_true
    vp.y_offset.should eq(0)
    vp.on_key(Ori::Key.new(text: "q")).should be_false
  end

  it "accepts initial y_offset" do
    lines = (1..100).map(&.to_s).join('\n')
    vp = Ori::Viewport.new(content: lines, y_offset: 10)
    vp.y_offset.should eq(10)
  end

  it "fires on_scroll callback" do
    scrolled = 0
    callback = Proc(Int32, Nil).new { |y| scrolled = y }
    lines = (1..50).map(&.to_s).join('\n')
    vp = Ori::Viewport.new(content: lines, on_scroll: callback)
    vp.view_down(3)
    scrolled.should eq(3)
    vp.view_up(1)
    scrolled.should eq(2)
  end
end

describe "Box DSL methods" do
  it "adds text via box block" do
    b = Ori::Box.new([] of Ori::Node)
    t = b.text("hello", bold: true)
    t.should be_a(Ori::TextNode)
    b.children.should contain(t)
  end

  it "creates nested box" do
    outer = Ori::Box.new([] of Ori::Node)
    inner = outer.box(padding: 2) do
      text("nested")
    end
    inner.should be_a(Ori::Box)
    outer.children.should contain(inner)
    inner.children.size.should eq(1)
  end

  it "adds input to box" do
    b = Ori::Box.new([] of Ori::Node)
    i = b.input(placeholder: "name")
    i.should be_a(Ori::InputNode)
    b.children.should contain(i)
  end

  it "adds table to box" do
    b = Ori::Box.new([] of Ori::Node)
    tbl = b.table(headers: ["X"], rows: [["1"]], border: true)
    tbl.should be_a(Ori::Table)
    b.children.should contain(tbl)
  end

  it "adds list to box" do
    b = Ori::Box.new([] of Ori::Node)
    l = b.list(items: [Ori::List::Item.new("a"), Ori::List::Item.new("b")])
    l.should be_a(Ori::List)
    b.children.should contain(l)
  end

  it "handles bad hex gracefully" do
    r, g, b = Ori::Color.hex_rgb("zz")
    r.should eq(0)
    g.should eq(0)
    b.should eq(0)
  end

  it "handles empty hex" do
    r, g, b = Ori::Color.hex_rgb("")
    r.should eq(0)
    g.should eq(0)
    b.should eq(0)
  end

  it "handles valid 3-char hex" do
    r, g, b = Ori::Color.hex_rgb("#abc")
    r.should eq(170)
    g.should eq(187)
    b.should eq(204)
  end

  it "paint handles nil fg/bg" do
    result = Ori::Color.paint("hello", fg: nil, bg: nil)
    result.should contain("hello")
  end
end

describe "Error handling" do
  it "Box.add appends children" do
    b = Ori::Box.new([] of Ori::Node)
    t = Ori::TextNode.new("x")
    b.add(t)
    b.children.size.should eq(1)
    b.children.should contain(t)
  end

  it "Screen.put ignores out of bounds" do
    s = Ori::Screen.new(5, 5)
    s.put(-1, 0, 'a')
    s.put(0, -1, 'a')
    s.put(5, 0, 'a')
    s.put(0, 5, 'a')
    back = s.back
    back.all? { |c| c.char == ' ' }.should be_true
  end

  it "Screen.write handles multiline" do
    s = Ori::Screen.new(10, 5)
    s.write(0, 0, "ab\ncd")
    s.back[0].char.should eq('a')
    s.back[1].char.should eq('b')
    s.back[10].char.should eq('c')
    s.back[11].char.should eq('d')
  end

  it "Term.window_size returns fallback on failure" do
    w, h = Ori::Term.window_size
    w.should be > 0
    h.should be > 0
  end

  it "Viewport rebuilds on content change" do
    vp = Ori::Viewport.new(content: "a")
    vp.total_lines.should eq(1)
    vp.content = "a\nb\nc\nd\ne"
    vp.total_lines.should eq(5)
    vp.goto_bottom
    vp.at_bottom?.should be_true
    vp.content = "x"
    vp.total_lines.should eq(1)
    vp.y_offset.should eq(0)
  end
end

describe "AreaNode word navigation" do
  it "word_left skips whitespace then word chars" do
    a = Ori::AreaNode.new(value: "hello world")
    11.times { a.on_key(Ori::Key.new(code: Ori::Key::Code::Right)) }
    a.word_left
    a.cursor_col.should eq(6)
    a.word_left
    a.cursor_col.should eq(0)
  end

  it "word_right skips word then whitespace" do
    a = Ori::AreaNode.new(value: "hello world")
    a.on_key(Ori::Key.new(code: Ori::Key::Code::Home))
    a.cursor_col.should eq(0)
    a.word_right
    a.cursor_col.should eq(6)
    a.word_right
    a.cursor_col.should eq(11)
  end

  it "word_left crosses line boundary" do
    a = Ori::AreaNode.new(value: "hello\nworld")
    a.on_key(Ori::Key.new(code: Ori::Key::Code::Down))
    a.on_key(Ori::Key.new(code: Ori::Key::Code::Home))
    a.cursor_row.should eq(1)
    a.cursor_col.should eq(0)
    a.word_left
    a.cursor_row.should eq(0)
    a.cursor_col.should eq(5)
  end

  it "word_right crosses line boundary" do
    a = Ori::AreaNode.new(value: "hello\nworld")
    a.on_key(Ori::Key.new(code: Ori::Key::Code::End))
    a.word_right
    a.cursor_row.should eq(1)
    a.cursor_col.should eq(0)
  end

  it "delete_word_backward" do
    a = Ori::AreaNode.new(value: "hello world")
    a.on_key(Ori::Key.new(code: Ori::Key::Code::End))
    a.delete_word_backward
    a.value.should eq("hello ")
    a.cursor_col.should eq(6)
  end

  it "delete_word_forward" do
    a = Ori::AreaNode.new(value: "hello world")
    a.on_key(Ori::Key.new(code: Ori::Key::Code::Home))
    a.delete_word_forward
    a.value.should eq("world")
    a.cursor_col.should eq(0)
  end

  it "kill_to_end" do
    a = Ori::AreaNode.new(value: "hello world")
    a.on_key(Ori::Key.new(code: Ori::Key::Code::Home))
    5.times { a.on_key(Ori::Key.new(code: Ori::Key::Code::Right)) }
    a.kill_to_end
    a.value.should eq("hello")
  end

  it "kill_to_start" do
    a = Ori::AreaNode.new(value: "hello world")
    a.on_key(Ori::Key.new(code: Ori::Key::Code::Home))
    5.times { a.on_key(Ori::Key.new(code: Ori::Key::Code::Right)) }
    a.kill_to_start
    a.value.should eq(" world")
    a.cursor_col.should eq(0)
  end

  it "page_up and page_down" do
    lines = (1..100).map(&.to_s).join('\n')
    a = Ori::AreaNode.new(value: lines)
    a.cursor_row.should eq(0)
    a.page_down
    a.cursor_row.should be > 0
    a.page_up
    a.cursor_row.should eq(0)
  end

  it "respects char_limit" do
    a = Ori::AreaNode.new(value: "ab", char_limit: 3)
    a.on_key(Ori::Key.new(text: "c"))
    a.value.should eq("abc")
    a.on_key(Ori::Key.new(text: "d"))
    a.value.should eq("abc")
  end

  it "exposes cursor_row and cursor_col" do
    a = Ori::AreaNode.new(value: "hello\nworld")
    a.cursor_row.should eq(0)
    a.cursor_col.should eq(5)
    a.on_key(Ori::Key.new(code: Ori::Key::Code::Down))
    a.cursor_row.should eq(1)
    a.on_key(Ori::Key.new(code: Ori::Key::Code::Home))
    a.cursor_col.should eq(0)
    a.line(0).should eq("hello")
    a.line(1).should eq("world")
    a.line_count.should eq(2)
  end
end

describe Ori::FilePicker do
  it "initializes with current dir" do
    fp = Ori::FilePicker.new
    fp.current_dir.should eq(Dir.current)
    fp.selected_file.should be_nil
    fp.did_select?.should be_false
  end

  it "scans directory and lists files" do
    fp = Ori::FilePicker.new(current_dir: "/tmp")
    fp.files.should_not be_empty
    fp.files.any?(&.directory).should be_true
  end

  it "navigates up with k" do
    fp = Ori::FilePicker.new(current_dir: "/tmp")
    next if fp.files.size < 2
    fp.on_key(Ori::Key.new(text: "j"))
    fp.cursor.should eq(1)
    fp.on_key(Ori::Key.new(text: "k"))
    fp.cursor.should eq(0)
  end

  it "goes to top with g" do
    fp = Ori::FilePicker.new(current_dir: "/tmp")
    fp.on_key(Ori::Key.new(text: "j"))
    fp.on_key(Ori::Key.new(text: "g"))
    fp.cursor.should eq(0)
  end

  it "goes up directory with backspace" do
    fp = Ori::FilePicker.new(current_dir: "/tmp")
    original = fp.current_dir
    fp.on_key(Ori::Key.new(code: Ori::Key::Code::Backspace))
    fp.current_dir.should_not eq(original)
  end

  it "filters by allowed types" do
    Dir.mkdir_p("/tmp/ori_test_fp")
    File.write("/tmp/ori_test_fp/a.cr", "x")
    File.write("/tmp/ori_test_fp/b.txt", "y")
    fp = Ori::FilePicker.new(current_dir: "/tmp/ori_test_fp", allowed_types: [".cr"])
    fp.files.any?(&.name.ends_with?(".cr")).should be_true
    fp.files.any?(&.name.ends_with?(".txt")).should be_false
  ensure
    `rm -rf /tmp/ori_test_fp`
  end

  it "content_height and content_width are positive" do
    fp = Ori::FilePicker.new
    fp.content_height.should be >= 1
    fp.content_width.should be >= 1
  end

  it "is focusable" do
    fp = Ori::FilePicker.new
    fp.focusable?.should be_true
  end
end

describe Ori::Paginator do
  it "computes total pages" do
    p = Ori::Paginator.new(per_page: 10)
    p.set_total_pages(45)
    p.total_pages.should eq(5)
  end

  it "handles zero items" do
    p = Ori::Paginator.new(per_page: 10)
    p.set_total_pages(0)
    p.total_pages.should eq(0)
  end

  it "handles exact pages" do
    p = Ori::Paginator.new(per_page: 10)
    p.set_total_pages(30)
    p.total_pages.should eq(3)
  end

  it "slice_bounds returns correct range" do
    p = Ori::Paginator.new(per_page: 10)
    p.set_total_pages(25)
    s, e = p.slice_bounds(25)
    s.should eq(0)
    e.should eq(10)
    p.next_page
    s, e = p.slice_bounds(25)
    s.should eq(10)
    e.should eq(20)
  end

  it "items_on_page" do
    p = Ori::Paginator.new(per_page: 10)
    p.set_total_pages(25)
    p.items_on_page(25).should eq(10)
    p.next_page
    p.next_page
    p.items_on_page(25).should eq(5)
  end

  it "prev_page and next_page" do
    p = Ori::Paginator.new(per_page: 10)
    p.set_total_pages(30)
    p.on_first_page?.should be_true
    p.next_page
    p.page.should eq(1)
    p.on_last_page?.should be_false
    p.next_page
    p.on_last_page?.should be_true
    p.next_page
    p.page.should eq(2)
    p.prev_page
    p.page.should eq(1)
  end

  it "clamps page on set_total_pages" do
    p = Ori::Paginator.new(per_page: 10)
    p.set_total_pages(50)
    p.next_page
    p.next_page
    p.page.should eq(2)
    p.set_total_pages(1)
    p.page.should eq(0)
  end

  it "arabic view" do
    p = Ori::Paginator.new(per_page: 10, type: Ori::Paginator::Type::Arabic)
    p.set_total_pages(30)
    p.view.should eq("1/3")
  end

  it "dots view" do
    p = Ori::Paginator.new(per_page: 10, type: Ori::Paginator::Type::Dots)
    p.set_total_pages(30)
    p.view.should eq("• ○ ○")
    p.next_page
    p.view.should eq("○ • ○")
  end
end

describe Ori::MarkdownNode do
  it "parses headings" do
    md = Ori::MarkdownNode.new(content: "# Hello\n## World\n### Foo")
    md.content_height.should be > 0
  end

  it "parses lists" do
    md = Ori::MarkdownNode.new(content: "- item1\n- item2")
    md.content_height.should be > 0
  end

  it "parses blockquotes" do
    md = Ori::MarkdownNode.new(content: "> quote")
    md.content_height.should be > 0
  end

  it "parses horizontal rules" do
    md = Ori::MarkdownNode.new(content: "---")
    md.content_height.should be > 0
  end

  it "parses code blocks" do
    md = Ori::MarkdownNode.new(content: "```\ncode\n```")
    md.content_height.should be > 0
  end

  it "parses numbered lists" do
    md = Ori::MarkdownNode.new(content: "1. first\n2. second")
    md.content_height.should be > 0
  end

  it "handles empty content" do
    md = Ori::MarkdownNode.new(content: "")
    md.content_height.should be >= 1
  end

  it "updates content" do
    md = Ori::MarkdownNode.new(content: "old")
    md.content = "# new"
    md.content.should eq("# new")
  end
end

describe Ori::Sparkline do
  it "initializes with data" do
    sl = Ori::Sparkline.new(data: [1.0, 2.0, 3.0])
    sl.data.should eq([1.0, 2.0, 3.0])
    sl.max.should eq(3.0)
  end

  it "pushes values" do
    sl = Ori::Sparkline.new
    sl.push(5.0)
    sl.push(10.0)
    sl.data.size.should eq(2)
    sl.max.should eq(10.0)
  end

  it "push_all" do
    sl = Ori::Sparkline.new
    sl.push_all([1.0, 2.0, 3.0])
    sl.data.size.should eq(3)
  end

  it "respects manual max" do
    sl = Ori::Sparkline.new(data: [1.0, 2.0, 3.0], max: 10.0, auto_max: false)
    sl.max.should eq(10.0)
    sl.push(15.0)
    sl.max.should eq(10.0)
  end

  it "content dimensions" do
    sl = Ori::Sparkline.new(data: [1.0, 2.0, 3.0])
    sl.content_width.should eq(3)
    sl.content_height.should be >= 1
  end

  it "not focusable" do
    sl = Ori::Sparkline.new
    sl.focusable?.should be_false
  end
end

describe Ori::Help do
  it "renders short help" do
    bindings = [
      Ori::HelpBinding.new(["j", "down"], "j/k", "navigate"),
      Ori::HelpBinding.new(["q"], "q", "quit"),
    ]
    h = Ori::Help.new(bindings: bindings)
    h.content_height.should eq(1)
    h.show_all.should be_false
  end

  it "renders full help" do
    bindings = [
      Ori::HelpBinding.new(["j"], "j", "down"),
      Ori::HelpBinding.new(["q"], "q", "quit"),
      Ori::HelpBinding.new(["enter"], "enter", "select"),
    ]
    h = Ori::Help.new(bindings: bindings, show_all: true)
    h.content_height.should eq(3)
  end

  it "skips disabled bindings" do
    bindings = [
      Ori::HelpBinding.new(["j"], "j", "down"),
      Ori::HelpBinding.new(["q"], "q", "quit", disabled: true),
    ]
    h = Ori::Help.new(bindings: bindings)
    h.bindings.count(&.enabled?).should eq(1)
  end

  it "HelpBinding enabled?" do
    b = Ori::HelpBinding.new(["j"], "j", "down")
    b.enabled?.should be_true
    b = Ori::HelpBinding.new(["j"], "j", "down", disabled: true)
    b.enabled?.should be_false
    b = Ori::HelpBinding.new([] of String, "", "")
    b.enabled?.should be_false
  end
end

describe "Box DSL new widgets" do
  it "adds file_picker to box" do
    b = Ori::Box.new([] of Ori::Node)
    fp = b.file_picker
    fp.should be_a(Ori::FilePicker)
    b.children.should contain(fp)
  end

  it "adds sparkline to box" do
    b = Ori::Box.new([] of Ori::Node)
    sl = b.sparkline(data: [1.0, 2.0])
    sl.should be_a(Ori::Sparkline)
    b.children.should contain(sl)
  end

  it "adds markdown to box" do
    b = Ori::Box.new([] of Ori::Node)
    md = b.markdown(content: "# Hello")
    md.should be_a(Ori::MarkdownNode)
    b.children.should contain(md)
  end

  it "adds help to box" do
    b = Ori::Box.new([] of Ori::Node)
    h = b.help(bindings: [Ori::HelpBinding.new(["q"], "q", "quit")])
    h.should be_a(Ori::Help)
    b.children.should contain(h)
  end
end

describe "Ori::Key extended" do
  it "creates with all modifiers" do
    k = Ori::Key.new(text: "a", ctrl: true, alt: true, shift: true)
    k.ctrl.should be_true
    k.alt.should be_true
    k.shift.should be_true
  end

  it "non-printable with ctrl" do
    k = Ori::Key.new(text: "c", ctrl: true)
    k.printable?.should be_false
  end

  it "non-printable with alt" do
    k = Ori::Key.new(text: "a", alt: true)
    k.printable?.should be_false
  end

  it "printable plain text" do
    k = Ori::Key.new(text: "x")
    k.printable?.should be_true
  end

  it "empty text not printable" do
    k = Ori::Key.new(text: "")
    k.printable?.should be_false
  end

  it "to_s with code" do
    k = Ori::Key.new(code: Ori::Key::Code::Up)
    k.to_s.should eq("up")
  end

  it "to_s with ctrl" do
    k = Ori::Key.new(text: "c", ctrl: true)
    k.to_s.should eq("ctrl+c")
  end

  it "to_s with alt" do
    k = Ori::Key.new(text: "a", alt: true)
    k.to_s.should eq("alt+a")
  end

  it "to_s plain text" do
    k = Ori::Key.new(text: "z")
    k.to_s.should eq("z")
  end
end

describe "Ori::S extended" do
  it "parses 4-tuple padding" do
    s = Ori::S.new(padding: {1, 2, 3, 4})
    s.padding_top.should eq(1)
    s.padding_right.should eq(2)
    s.padding_bottom.should eq(3)
    s.padding_left.should eq(4)
  end

  it "border_size single" do
    s = Ori::S.new(border: :single)
    s.border_size.should eq(1)
  end

  it "border_size none" do
    s = Ori::S.new(border: :none)
    s.border_size.should eq(0)
  end

  it "hpadding and vpadding" do
    s = Ori::S.new(padding: 3)
    s.hpadding.should eq(6)
    s.vpadding.should eq(6)
  end

  it "defaults all fields" do
    s = Ori::S.new
    s.bold.should be_false
    s.dim.should be_false
    s.underline.should be_false
    s.strikethrough.should be_false
    s.border.should eq(:none)
    s.flex.should eq(0)
    s.direction.should eq(:vertical)
    s.align.should eq(:left)
    s.focusable.should be_false
    s.scrollable.should be_false
  end
end

describe "Ori::Rect extended" do
  it "contains point inside" do
    r = Ori::Rect.new(2, 3, 10, 5)
    r.contains?(5, 5).should be_true
  end

  it "does not contain point outside" do
    r = Ori::Rect.new(2, 3, 10, 5)
    r.contains?(0, 0).should be_false
  end

  it "does not contain point on right/bottom edge" do
    r = Ori::Rect.new(0, 0, 5, 5)
    r.contains?(5, 0).should be_false
    r.contains?(0, 5).should be_false
  end

  it "contains point on left/top edge" do
    r = Ori::Rect.new(0, 0, 5, 5)
    r.contains?(0, 0).should be_true
  end

  it "inner with padding" do
    r = Ori::Rect.new(0, 0, 20, 10)
    s = Ori::S.new(padding: 2)
    inner = r.inner(s)
    inner.x.should eq(2)
    inner.y.should eq(2)
    inner.w.should eq(16)
    inner.h.should eq(6)
  end

  it "inner clamps to zero" do
    r = Ori::Rect.new(0, 0, 2, 2)
    s = Ori::S.new(padding: 5)
    inner = r.inner(s)
    inner.w.should eq(0)
    inner.h.should eq(0)
  end
end

describe "Ori::Screen extended" do
  it "resize resets buffers" do
    s = Ori::Screen.new(5, 5)
    s.put(0, 0, 'X')
    s.back[0].char.should eq('X')
    s.resize(3, 3)
    s.w.should eq(3)
    s.h.should eq(3)
    s.back.size.should eq(9)
  end

  it "clear resets all cells" do
    s = Ori::Screen.new(5, 5)
    s.put(0, 0, 'A')
    s.put(4, 4, 'B')
    s.clear
    s.back.all? { |c| c.char == ' ' }.should be_true
  end

  it "write handles multiple newlines" do
    s = Ori::Screen.new(10, 10)
    s.write(0, 0, "ab\n\ncd")
    s.back[0].char.should eq('a')
    s.back[1].char.should eq('b')
    s.back[10].char.should eq(' ')
    s.back[20].char.should eq('c')
    s.back[21].char.should eq('d')
  end

  it "flush outputs changed cells" do
    s = Ori::Screen.new(5, 1)
    io = IO::Memory.new
    s.put(0, 0, 'H')
    s.flush(io)
    io.to_s.should contain("H")
  end

  it "flush writes all cells every frame" do
    s = Ori::Screen.new(5, 1)
    io1 = IO::Memory.new
    s.put(0, 0, 'H')
    s.flush(io1)
    io1.to_s.should contain("H")
    io2 = IO::Memory.new
    s.flush(io2)
    io2.to_s.size.should eq(io1.to_s.size)
  end

  it "nested clips restrict writes" do
    s = Ori::Screen.new(10, 10)
    s.push_clip(2, 2, 3, 3)
    s.put(1, 2, 'a')
    s.put(2, 2, 'b')
    s.put(5, 2, 'c')
    s.pop_clip
    s.back[2 * 10 + 1].char.should eq(' ')
    s.back[2 * 10 + 2].char.should eq('b')
    s.back[2 * 10 + 5].char.should eq(' ')
  end

  it "put with style" do
    s = Ori::Screen.new(5, 5)
    s.put(0, 0, 'X', fg: "#ff0000", bg: "#00ff00", bold: true, dim: true)
    cell = s.back[0]
    cell.char.should eq('X')
    cell.fg.should eq("#ff0000")
    cell.bg.should eq("#00ff00")
    cell.bold.should be_true
    cell.dim.should be_true
  end
end

describe "Ori::Color extended" do
  it "apply with nil fg returns text" do
    Ori::Color.apply(nil, "hello").should eq("hello")
  end

  it "apply_bg with nil bg returns text" do
    Ori::Color.apply_bg(nil, "hello").should eq("hello")
  end

  it "fg is alias for apply" do
    result = Ori::Color.fg("#ff0000", "test")
    result.should contain("test")
    result.should contain("\e[")
  end

  it "bg is alias for apply_bg" do
    result = Ori::Color.bg("#00ff00", "test")
    result.should contain("test")
  end

  it "inverse wraps with reverse" do
    result = Ori::Color.inverse("test")
    result.should contain("\e[7m")
    result.should contain("test")
  end

  it "dim wraps with dim code" do
    result = Ori::Color.dim("test")
    result.should contain("\e[2m")
  end

  it "bold wraps with bold code" do
    result = Ori::Color.bold("test")
    result.should contain("\e[1m")
  end

  it "paint with fg and bg" do
    result = Ori::Color.paint("hi", fg: "#ff0000", bg: "#0000ff", bold: true)
    result.should contain("hi")
    result.should contain("\e[1m")
  end
end

describe "Ori::InputNode extended" do
  it "initializes with value and cursor at end" do
    i = Ori::InputNode.new(value: "hello")
    i.value.should eq("hello")
    i.content_height.should eq(1)
    i.focusable?.should be_true
  end

  it "types characters" do
    i = Ori::InputNode.new
    i.on_key(Ori::Key.new(text: "a"))
    i.on_key(Ori::Key.new(text: "b"))
    i.on_key(Ori::Key.new(text: "c"))
    i.value.should eq("abc")
  end

  it "backspace removes char" do
    i = Ori::InputNode.new(value: "abc")
    i.on_key(Ori::Key.new(code: Ori::Key::Code::End))
    i.on_key(Ori::Key.new(code: Ori::Key::Code::Backspace))
    i.value.should eq("ab")
  end

  it "delete removes char at cursor" do
    i = Ori::InputNode.new(value: "abc")
    i.on_key(Ori::Key.new(code: Ori::Key::Code::Home))
    i.on_key(Ori::Key.new(code: Ori::Key::Code::Delete))
    i.value.should eq("bc")
  end

  it "left/right moves cursor" do
    i = Ori::InputNode.new(value: "abc")
    i.on_key(Ori::Key.new(code: Ori::Key::Code::Home))
    i.on_key(Ori::Key.new(code: Ori::Key::Code::Right))
    i.on_key(Ori::Key.new(code: Ori::Key::Code::Delete))
    i.value.should eq("ac")
  end

  it "home and end" do
    i = Ori::InputNode.new(value: "abc")
    i.on_key(Ori::Key.new(code: Ori::Key::Code::Home))
    i.on_key(Ori::Key.new(text: "X"))
    i.value.should eq("Xabc")
    i.on_key(Ori::Key.new(code: Ori::Key::Code::End))
    i.on_key(Ori::Key.new(text: "Y"))
    i.value.should eq("XabcY")
  end

  it "fire_change on type" do
    changed = ""
    i = Ori::InputNode.new(on_change: Proc(String, Nil).new { |v| changed = v })
    i.on_key(Ori::Key.new(text: "z"))
    changed.should eq("z")
  end

  it "fire_submit on enter" do
    submitted = false
    i = Ori::InputNode.new(on_submit: Proc(Nil).new { submitted = true })
    i.on_key(Ori::Key.new(code: Ori::Key::Code::Enter))
    submitted.should be_true
  end

  it "value= clamps cursor" do
    i = Ori::InputNode.new(value: "hello")
    i.value = "hi"
    i.value.should eq("hi")
  end

  it "content_width includes prefix" do
    i = Ori::InputNode.new(value: "hello", style: Ori::S.new(border: :single))
    i.content_width.should be >= 5
  end
end

describe "Ori::ProgressBar extended" do
  it "clamps value to max" do
    p = Ori::ProgressBar.new(value: 150.0, max: 100.0)
    p.value.should eq(100.0)
  end

  it "clamps value to 0" do
    p = Ori::ProgressBar.new(value: -10.0, max: 100.0)
    p.value.should eq(0.0)
  end

  it "value= clamps" do
    p = Ori::ProgressBar.new(value: 50.0, max: 100.0)
    p.value = 200.0
    p.value.should eq(100.0)
    p.value = -5.0
    p.value.should eq(0.0)
  end

  it "max= reclamps value" do
    p = Ori::ProgressBar.new(value: 80.0, max: 100.0)
    p.max = 50.0
    p.max.should eq(50.0)
    p.value.should eq(50.0)
  end

  it "content_height is 1" do
    p = Ori::ProgressBar.new
    p.content_height.should eq(1)
  end

  it "content_width defaults to 10" do
    p = Ori::ProgressBar.new
    p.content_width.should eq(10)
  end

  it "render_screen solid" do
    p = Ori::ProgressBar.new(value: 50.0, max: 100.0, style: Ori::S.new(width: 10))
    p.rect = Ori::Rect.new(0, 0, 10, 1)
    screen = Ori::Screen.new(10, 1)
    p.render_screen(screen)
    screen.back[0].char.should eq('█')
    screen.back[9].char.should eq(' ')
  end

  it "render_screen blocks" do
    p = Ori::ProgressBar.new(value: 0.0, max: 100.0, style: Ori::S.new(width: 10, bar_style: :blocks))
    p.rect = Ori::Rect.new(0, 0, 10, 1)
    screen = Ori::Screen.new(10, 1)
    p.render_screen(screen)
    screen.back[0].char.should eq('░')
  end

  it "render_screen gradient" do
    p = Ori::ProgressBar.new(value: 50.0, max: 100.0, style: Ori::S.new(width: 10, bar_style: :gradient, fg: "#ff0000", gradient_to: "#0000ff"))
    p.rect = Ori::Rect.new(0, 0, 10, 1)
    screen = Ori::Screen.new(10, 1)
    p.render_screen(screen)
    screen.back[0].char.should eq('▌')
  end
end

describe "Ori::Spinner extended" do
  it "initializes with default dots" do
    s = Ori::Spinner.new
    s.content_height.should eq(1)
    s.content_width.should eq(1)
    f = s.frame
    f.should be_a(String)
    f.size.should be > 0
  end

  it "initializes with different types" do
    Ori::Spinner::FRAMES.each do |type, frames|
      s = Ori::Spinner.new(type: type)
      s.frame.should be_a(String)
    end
  end

  it "frame= sets frame index" do
    s = Ori::Spinner.new(type: :line)
    s.frame = 2
    s.frame.should eq(Ori::Spinner::FRAMES[:line][2])
  end

  it "reset restarts animation" do
    s = Ori::Spinner.new
    f1 = s.frame
    s.frame = 5
    s.reset
    s.frame.should_not eq(Ori::Spinner::FRAMES[:dots][5])
  end

  it "render_screen puts frame char" do
    s = Ori::Spinner.new(type: :line)
    s.rect = Ori::Rect.new(0, 0, 1, 1)
    screen = Ori::Screen.new(5, 1)
    s.render_screen(screen)
    screen.back[0].char.should_not eq(' ')
  end
end

describe "Ori::FocusManager" do
  it "manages focus ring" do
    fm = Ori::FocusManager.new
    i1 = Ori::InputNode.new(style: Ori::S.new(focusable: true))
    i2 = Ori::InputNode.new(style: Ori::S.new(focusable: true))
    box = Ori::Box.new([i1, i2] of Ori::Node)
    fm.update(box)
    i1.focused.should be_true
    i2.focused.should be_false
  end

  it "tab cycles focus" do
    fm = Ori::FocusManager.new
    i1 = Ori::InputNode.new(style: Ori::S.new(focusable: true))
    i2 = Ori::InputNode.new(style: Ori::S.new(focusable: true))
    box = Ori::Box.new([i1, i2] of Ori::Node)
    fm.update(box)
    fm.handle_key(Ori::Key.new(code: Ori::Key::Code::Tab))
    i1.focused.should be_false
    i2.focused.should be_true
  end

  it "shift+tab cycles backward" do
    fm = Ori::FocusManager.new
    i1 = Ori::InputNode.new(style: Ori::S.new(focusable: true))
    i2 = Ori::InputNode.new(style: Ori::S.new(focusable: true))
    box = Ori::Box.new([i1, i2] of Ori::Node)
    fm.update(box)
    fm.handle_key(Ori::Key.new(code: Ori::Key::Code::Tab, shift: true))
    i1.focused.should be_false
    i2.focused.should be_true
  end

  it "dispatches key to focused node" do
    fm = Ori::FocusManager.new
    i = Ori::InputNode.new(value: "", style: Ori::S.new(focusable: true))
    box = Ori::Box.new([i] of Ori::Node)
    fm.update(box)
    fm.handle_key(Ori::Key.new(text: "x"))
    i.value.should eq("x")
  end

  it "handles empty tree" do
    fm = Ori::FocusManager.new
    box = Ori::Box.new([] of Ori::Node)
    fm.update(box)
    fm.handle_key(Ori::Key.new(code: Ori::Key::Code::Tab)).should be_false
  end

  it "focus_first resets to first" do
    fm = Ori::FocusManager.new
    i1 = Ori::InputNode.new(style: Ori::S.new(focusable: true))
    i2 = Ori::InputNode.new(style: Ori::S.new(focusable: true))
    box = Ori::Box.new([i1, i2] of Ori::Node)
    fm.update(box)
    fm.handle_key(Ori::Key.new(code: Ori::Key::Code::Tab))
    i2.focused.should be_true
    fm.focus_first
    i1.focused.should be_true
  end

  it "skips non-focusable nodes" do
    fm = Ori::FocusManager.new
    t = Ori::TextNode.new("label")
    i = Ori::InputNode.new(style: Ori::S.new(focusable: true))
    box = Ori::Box.new([t, i] of Ori::Node)
    fm.update(box)
    t.focused.should be_false
    i.focused.should be_true
  end
end

describe "Ori::Node base" do
  it "defaults rect to 0,0,0,0" do
    t = Ori::TextNode.new("x")
    t.rect.x.should eq(0)
    t.rect.y.should eq(0)
    t.rect.w.should eq(0)
    t.rect.h.should eq(0)
  end

  it "defaults not focused" do
    t = Ori::TextNode.new("x")
    t.focused.should be_false
  end

  it "effective_bg uses style bg" do
    t = Ori::TextNode.new("x", style: Ori::S.new(bg: "#111111"))
    t.effective_bg.should eq("#111111")
  end

  it "effective_bg falls back to inherited" do
    t = Ori::TextNode.new("x")
    t.inherited_bg = "#222222"
    t.effective_bg.should eq("#222222")
  end

  it "on_key returns false by default" do
    t = Ori::TextNode.new("x")
    t.on_key(Ori::Key.new(text: "a")).should be_false
  end

  it "on_mouse returns false by default" do
    t = Ori::TextNode.new("x")
    mouse = Ori::Mouse.new(0, 0, Ori::Mouse::Button.new(0), Ori::Mouse::Action::Press)
    t.on_mouse(mouse).should be_false
  end
end

describe "Ori::Mouse" do
  it "in? returns true inside rect" do
    mouse = Ori::Mouse.new(5, 5, Ori::Mouse::Button.new(0), Ori::Mouse::Action::Press)
    rect = Ori::Rect.new(0, 0, 10, 10)
    mouse.in?(rect).should be_true
  end

  it "in? returns false outside rect" do
    mouse = Ori::Mouse.new(15, 5, Ori::Mouse::Button.new(0), Ori::Mouse::Action::Press)
    rect = Ori::Rect.new(0, 0, 10, 10)
    mouse.in?(rect).should be_false
  end

  it "wheel_up and wheel_down" do
    Ori::Mouse::Button::WheelUp.wheel_up?.should be_true
    Ori::Mouse::Button::WheelDown.wheel_down?.should be_true
    Ori::Mouse::Button::Left.wheel_up?.should be_false
  end
end

describe "Ori::Term" do
  it "move generates escape sequence" do
    result = Ori::Term.move(5, 3)
    result.should contain("\e[")
    result.should contain("4")
    result.should contain("6")
  end

  it "clear_screen generates escape" do
    Ori::Term.clear_screen.should contain("\e[2J")
  end

  it "hide_cursor generates escape" do
    Ori::Term.hide_cursor.should contain("\e[?25l")
  end

  it "show_cursor generates escape" do
    Ori::Term.show_cursor.should contain("\e[?25h")
  end

  it "enter_alt generates escape" do
    Ori::Term.enter_alt.should contain("\e[?1049h")
  end

  it "exit_alt generates escape" do
    Ori::Term.exit_alt.should contain("\e[?1049l")
  end

  it "cursor_shape for each shape" do
    {:block, :block_blink, :underline, :underline_blink, :bar, :bar_blink, :unknown}.each do |s|
      result = Ori::Term.cursor_shape(s)
      result.should contain("\e[")
    end
  end

  it "window_size returns positive values" do
    w, h = Ori::Term.window_size
    w.should be > 0
    h.should be > 0
  end
end

describe "Ori::InputParser" do
  it "parses 'q' as key" do
    parser = Ori::InputParser.new
    result = parser.parse_full('q'.ord.to_u8)
    result.should_not be_nil
    if r = result
      r.key.should_not be_nil
      r.mouse.should be_nil
      k = r.key.not_nil!
      k.text.should eq("q")
    end
  end

  it "parses escape sequence for up" do
    parser = Ori::InputParser.new
    esc = "\e[A".bytes
    result = nil
    esc.each do |b|
      result = parser.parse_full(b)
    end
    result.should_not be_nil
    if r = result
      k = r.key
      k.should_not be_nil
      k.not_nil!.code.should eq(Ori::Key::Code::Up)
    end
  end

  it "parses escape sequence for down" do
    parser = Ori::InputParser.new
    esc = "\e[B".bytes
    result = nil
    esc.each do |b|
      result = parser.parse_full(b)
    end
    result.should_not be_nil
    if r = result
      k = r.key
      k.should_not be_nil
      k.not_nil!.code.should eq(Ori::Key::Code::Down)
    end
  end

  it "parses escape sequence for right" do
    parser = Ori::InputParser.new
    esc = "\e[C".bytes
    result = nil
    esc.each do |b|
      result = parser.parse_full(b)
    end
    result.should_not be_nil
    if r = result
      k = r.key
      k.should_not be_nil
      k.not_nil!.code.should eq(Ori::Key::Code::Right)
    end
  end

  it "parses escape sequence for left" do
    parser = Ori::InputParser.new
    esc = "\e[D".bytes
    result = nil
    esc.each do |b|
      result = parser.parse_full(b)
    end
    result.should_not be_nil
    if r = result
      k = r.key
      k.should_not be_nil
      k.not_nil!.code.should eq(Ori::Key::Code::Left)
    end
  end

  it "in_escape_state after ESC byte" do
    parser = Ori::InputParser.new
    parser.parse_full(0x1B_u8)
    parser.in_escape_state?.should be_true
  end
end

describe "Ori::Box layout" do
  it "vertical layout stacks children" do
    c1 = Ori::TextNode.new("a", style: Ori::S.new(height: 3))
    c2 = Ori::TextNode.new("b", style: Ori::S.new(height: 5))
    box = Ori::Box.new([c1, c2] of Ori::Node)
    box.rect = Ori::Rect.new(0, 0, 40, 20)
    box.layout
    c1.rect.y.should eq(0)
    c2.rect.y.should eq(3)
  end

  it "horizontal layout places children side by side" do
    c1 = Ori::TextNode.new("a", style: Ori::S.new(width: 10, height: 1))
    c2 = Ori::TextNode.new("b", style: Ori::S.new(width: 15, height: 1))
    box = Ori::Box.new([c1, c2] of Ori::Node, style: Ori::S.new(direction: :horizontal))
    box.rect = Ori::Rect.new(0, 0, 40, 1)
    box.layout
    c1.rect.x.should eq(0)
    c2.rect.x.should eq(10)
  end

  it "flex distributes remaining space" do
    c1 = Ori::TextNode.new("a", style: Ori::S.new(height: 2))
    c2 = Ori::TextNode.new("b", style: Ori::S.new(flex: 1))
    box = Ori::Box.new([c1, c2] of Ori::Node)
    box.rect = Ori::Rect.new(0, 0, 40, 12)
    box.layout
    c1.rect.h.should eq(2)
    c2.rect.h.should eq(10)
  end

  it "padding adds offset" do
    c = Ori::TextNode.new("x", style: Ori::S.new(height: 6))
    box = Ori::Box.new([c] of Ori::Node, style: Ori::S.new(padding: 2))
    box.rect = Ori::Rect.new(0, 0, 20, 10)
    box.layout
    c.rect.x.should eq(2)
    c.rect.y.should eq(2)
  end

  it "focusable_nodes collects from tree" do
    i1 = Ori::InputNode.new(style: Ori::S.new(focusable: true))
    i2 = Ori::InputNode.new(style: Ori::S.new(focusable: true))
    inner = Ori::Box.new([i2] of Ori::Node)
    outer = Ori::Box.new([i1, inner] of Ori::Node)
    nodes = outer.focusable_nodes
    nodes.size.should eq(2)
    nodes.should contain(i1)
    nodes.should contain(i2)
  end

  it "add appends children" do
    b = Ori::Box.new([] of Ori::Node)
    b.children.size.should eq(0)
    t = Ori::TextNode.new("x")
    b.add(t)
    b.children.size.should eq(1)
    b.add(Ori::TextNode.new("y"))
    b.children.size.should eq(2)
  end
end

describe "Ori::Table extended" do
  it "navigates rows" do
    t = Ori::Table.new(headers: ["A", "B"], rows: [["1", "2"], ["3", "4"], ["5", "6"]])
    t.content_height.should be > 0
    t.content_width.should be > 0
  end

  it "handles single row" do
    t = Ori::Table.new(headers: ["X"], rows: [["1"]])
    t.content_height.should be > 0
  end

  it "handles empty rows" do
    t = Ori::Table.new(headers: ["X"], rows: [] of Array(String))
    t.content_height.should be > 0
  end
end

describe "Ori::List extended" do
  it "navigates items" do
    items = (1..5).map { |i| Ori::List::Item.new("item #{i}") }
    l = Ori::List.new(items: items)
    l.content_height.should eq(5)
    l.focusable?.should be_false
  end

  it "checkable list" do
    items = [Ori::List::Item.new("a"), Ori::List::Item.new("b")]
    l = Ori::List.new(items: items, checkable: true)
    l.content_height.should eq(2)
  end
end

describe "DSL extract_style" do
  it "extracts style from opts" do
    s = Ori::DSL.extract_style(fg: "#ff0000", bg: "#00ff00", bold: true, flex: 2)
    s.fg.should eq("#ff0000")
    s.bg.should eq("#00ff00")
    s.bold.should be_true
    s.flex.should eq(2)
  end

  it "defaults all fields" do
    s = Ori::DSL.extract_style
    s.fg.should be_nil
    s.bg.should be_nil
    s.bold.should be_false
    s.dim.should be_false
    s.underline.should be_false
    s.strikethrough.should be_false
    s.flex.should eq(0)
    s.focusable.should be_false
  end

  it "extracts border and padding" do
    s = Ori::DSL.extract_style(border: :rounded, padding: 3)
    s.border.should eq(:rounded)
    s.padding_top.should eq(3)
  end
end

describe "Ori::TextNode" do
  it "content_height single line" do
    t = Ori::TextNode.new("hello")
    t.content_height.should eq(1)
  end

  it "content_height multi line" do
    t = Ori::TextNode.new("hello\nworld\nfoo")
    t.content_height.should eq(3)
  end

  it "content_width" do
    t = Ori::TextNode.new("hi\nworld")
    t.content_width.should eq(5)
  end

  it "content_width single char" do
    t = Ori::TextNode.new("x")
    t.content_width.should eq(1)
  end

  it "content_width empty" do
    t = Ori::TextNode.new("")
    t.content_width.should eq(0)
  end

  it "setter updates content" do
    t = Ori::TextNode.new("old")
    t.content = "new"
    t.content.should eq("new")
  end

  it "render_screen writes to screen" do
    t = Ori::TextNode.new("hi")
    t.rect = Ori::Rect.new(0, 0, 10, 1)
    scr = Ori::Screen.new(10, 1)
    t.render_screen(scr)
  end

  it "render_screen multi-line clips" do
    t = Ori::TextNode.new("a\nb\nc\nd")
    t.rect = Ori::Rect.new(0, 0, 5, 2)
    scr = Ori::Screen.new(5, 2)
    t.render_screen(scr)
  end

  it "render to IO" do
    t = Ori::TextNode.new("x")
    t.rect = Ori::Rect.new(0, 0, 5, 1)
    io = IO::Memory.new
    t.render(io)
    io.to_s.should contain("x")
  end

  it "center alignment" do
    t = Ori::TextNode.new("hi", style: Ori::S.new(align: :center))
    t.rect = Ori::Rect.new(0, 0, 10, 1)
    scr = Ori::Screen.new(10, 1)
    t.render_screen(scr)
  end

  it "right alignment" do
    t = Ori::TextNode.new("hi", style: Ori::S.new(align: :right))
    t.rect = Ori::Rect.new(0, 0, 10, 1)
    scr = Ori::Screen.new(10, 1)
    t.render_screen(scr)
  end

  it "bold style renders" do
    t = Ori::TextNode.new("bold", style: Ori::S.new(bold: true))
    t.rect = Ori::Rect.new(0, 0, 10, 1)
    io = IO::Memory.new
    t.render(io)
    io.to_s.should contain("\e[1m")
  end

  it "dim style renders" do
    t = Ori::TextNode.new("dim", style: Ori::S.new(dim: true))
    t.rect = Ori::Rect.new(0, 0, 10, 1)
    io = IO::Memory.new
    t.render(io)
    io.to_s.should contain("\e[2m")
  end

  it "underline style renders" do
    t = Ori::TextNode.new("ul", style: Ori::S.new(underline: true))
    t.rect = Ori::Rect.new(0, 0, 10, 1)
    io = IO::Memory.new
    t.render(io)
    io.to_s.should contain("\e[4m")
  end

  it "strikethrough style renders" do
    t = Ori::TextNode.new("st", style: Ori::S.new(strikethrough: true))
    t.rect = Ori::Rect.new(0, 0, 10, 1)
    io = IO::Memory.new
    t.render(io)
    io.to_s.should contain("\e[9m")
  end

  it "fg color applies" do
    t = Ori::TextNode.new("x", style: Ori::S.new(fg: "#ff0000"))
    t.rect = Ori::Rect.new(0, 0, 5, 1)
    io = IO::Memory.new
    t.render(io)
    io.to_s.should contain("\e[38;2;")
  end

  it "bg color applies" do
    t = Ori::TextNode.new("x", style: Ori::S.new(bg: "#0000ff"))
    t.rect = Ori::Rect.new(0, 0, 5, 1)
    io = IO::Memory.new
    t.render(io)
    io.to_s.should contain("\e[48;2;")
  end

  it "empty content renders" do
    t = Ori::TextNode.new("")
    t.rect = Ori::Rect.new(0, 0, 5, 1)
    scr = Ori::Screen.new(5, 1)
    t.render_screen(scr)
  end
end

describe "Ori::Color extended" do
  it "hex_rgb full" do
    r, g, b = Ori::Color.hex_rgb("#ff8040")
    r.should eq(255)
    g.should eq(128)
    b.should eq(64)
  end

  it "hex_rgb without hash" do
    r, g, b = Ori::Color.hex_rgb("ff8040")
    r.should eq(255)
    g.should eq(128)
    b.should eq(64)
  end

  it "hex_rgb 3-char shorthand" do
    r, g, b = Ori::Color.hex_rgb("#f80")
    r.should eq(255)
    g.should eq(136)
    b.should eq(0)
  end

  it "hex_rgb invalid returns zeros" do
    r, g, b = Ori::Color.hex_rgb("xyz")
    r.should eq(0)
    g.should eq(0)
    b.should eq(0)
  end

  it "hex_rgb empty returns zeros" do
    r, g, b = Ori::Color.hex_rgb("#")
    r.should eq(0)
    g.should eq(0)
    b.should eq(0)
  end

  it "apply wraps with fg escape" do
    result = Ori::Color.apply("#ff0000", "hello")
    result.should contain("hello")
    result.should contain("\e[38;2;255;0;0m")
  end

  it "apply nil returns text" do
    Ori::Color.apply(nil, "hello").should eq("hello")
  end

  it "apply_bg wraps with bg escape" do
    result = Ori::Color.apply_bg("#00ff00", "hi")
    result.should contain("\e[48;2;0;255;0m")
  end

  it "apply_bg nil returns text" do
    Ori::Color.apply_bg(nil, "hi").should eq("hi")
  end

  it "fg alias" do
    Ori::Color.fg("#ff0000", "x").should eq(Ori::Color.apply("#ff0000", "x"))
  end

  it "bg alias" do
    Ori::Color.bg("#00ff00", "x").should eq(Ori::Color.apply_bg("#00ff00", "x"))
  end

  it "inverse wraps" do
    Ori::Color.inverse("hi").should eq("\e[7mhi\e[0m")
  end

  it "dim wraps" do
    Ori::Color.dim("x").should eq("\e[2mx\e[0m")
  end

  it "bold wraps" do
    Ori::Color.bold("x").should eq("\e[1mx\e[0m")
  end

  it "paint fg only" do
    result = Ori::Color.paint("x", fg: "#ff0000")
    result.should contain("\e[38;2;255;0;0m")
    result.should contain("x")
  end

  it "paint bg only" do
    result = Ori::Color.paint("x", bg: "#00ff00")
    result.should contain("\e[48;2;0;255;0m")
  end

  it "paint bold" do
    result = Ori::Color.paint("x", bold: true)
    result.should contain("\e[1m")
  end

  it "paint all combined" do
    result = Ori::Color.paint("x", fg: "#ff0000", bg: "#00ff00", bold: true)
    result.should contain("\e[48;2;0;255;0m")
    result.should contain("\e[38;2;255;0;0m")
    result.should contain("\e[1m")
  end

  it "paint no styles returns plain" do
    result = Ori::Color.paint("x")
    result.should contain("x\e[0m")
  end
end

describe "Ori::CalendarHelper" do
  it "days_in_month january" do
    cal = CalendarHelperWrapper.new
    cal.days_in_month(2024, 1).should eq(31)
  end

  it "days_in_month february leap year" do
    cal = CalendarHelperWrapper.new
    cal.days_in_month(2024, 2).should eq(29)
  end

  it "days_in_month february non-leap" do
    cal = CalendarHelperWrapper.new
    cal.days_in_month(2023, 2).should eq(28)
  end

  it "days_in_month april" do
    cal = CalendarHelperWrapper.new
    cal.days_in_month(2024, 4).should eq(30)
  end

  it "prev_month_dim" do
    cal = CalendarHelperWrapper.new
    cal.prev_month_dim(2024, 3).should eq(29)
  end

  it "prev_month_dim january" do
    cal = CalendarHelperWrapper.new
    cal.prev_month_dim(2024, 1).should eq(31)
  end

  it "start_wday sunday first" do
    cal = CalendarHelperWrapper.new
    w = cal.start_wday(2024, 1, false)
    w.should be >= 0
    w.should be < 7
  end

  it "start_wday monday first" do
    cal = CalendarHelperWrapper.new
    w = cal.start_wday(2024, 1, true)
    w.should be >= 0
    w.should be < 7
  end

  it "prev_month wraps year" do
    cal = CalendarHelperWrapper.new
    cal.prev_month(2024, 1).should eq({2023, 12})
  end

  it "prev_month normal" do
    cal = CalendarHelperWrapper.new
    cal.prev_month(2024, 6).should eq({2024, 5})
  end

  it "next_month wraps year" do
    cal = CalendarHelperWrapper.new
    cal.next_month(2024, 12).should eq({2025, 1})
  end

  it "next_month normal" do
    cal = CalendarHelperWrapper.new
    cal.next_month(2024, 5).should eq({2024, 6})
  end

  it "cal_col returns valid column" do
    cal = CalendarHelperWrapper.new
    col = cal.cal_col(2024, 1, 1, false)
    col.should be >= 0
    col.should be < 7
  end

  it "draw_title writes to screen" do
    cal = CalendarHelperWrapper.new
    scr = Ori::Screen.new(30, 3)
    cal.draw_title(scr, 0, 0, 30, 1, 2024, nil, nil)
  end

  it "draw_day_names sunday first" do
    cal = CalendarHelperWrapper.new
    scr = Ori::Screen.new(21, 1)
    cal.draw_day_names(scr, 0, 0, false, nil, nil)
  end

  it "draw_day_names monday first" do
    cal = CalendarHelperWrapper.new
    scr = Ori::Screen.new(21, 1)
    cal.draw_day_names(scr, 0, 0, true, nil, nil)
  end

  it "draw_grid renders" do
    cal = CalendarHelperWrapper.new
    scr = Ori::Screen.new(21, 8)
    cal.draw_grid(scr, 0, 0, 21, 8, 2024, 1, 15, false, "#cdd6f4", nil, "#cba6f7", "#45475a", "#89b4fa", "#1e1e2e", "#6c7086")
  end

  it "MONTH_NAMES has 12 entries" do
    Ori::CalendarHelper::MONTH_NAMES.size.should eq(12)
  end

  it "DAY_NAMES_SUN has 7 entries" do
    Ori::CalendarHelper::DAY_NAMES_SUN.size.should eq(7)
  end

  it "DAY_NAMES_MON has 7 entries" do
    Ori::CalendarHelper::DAY_NAMES_MON.size.should eq(7)
  end
end

describe "Ori::MarkdownNode extended" do
  it "parses bold text" do
    md = Ori::MarkdownNode.new(content: "this is **bold** text")
    md.content_height.should be > 0
  end

  it "parses italic text" do
    md = Ori::MarkdownNode.new(content: "this is *italic* text")
    md.content_height.should be > 0
  end

  it "parses inline code" do
    md = Ori::MarkdownNode.new(content: "use `crystal run`")
    md.content_height.should be > 0
  end

  it "mixed formatting" do
    md = Ori::MarkdownNode.new(content: "# Title\n**bold** and *italic* and `code`")
    md.content_height.should be > 0
  end

  it "total_lines" do
    md = Ori::MarkdownNode.new(content: "line1\nline2\nline3")
    md.total_lines.should be > 0
  end

  it "at_top? initially" do
    md = Ori::MarkdownNode.new(content: "hello")
    md.at_top?.should be_true
  end

  it "view_down changes offset" do
    md = Ori::MarkdownNode.new(content: (1..50).map(&.to_s).join('\n'))
    md.rect = Ori::Rect.new(0, 0, 40, 5)
    md.view_down
    md.y_offset.should be > 0
  end

  it "view_up from top stays at 0" do
    md = Ori::MarkdownNode.new(content: "hello")
    md.rect = Ori::Rect.new(0, 0, 40, 5)
    md.view_up
    md.y_offset.should eq(0)
  end

  it "goto_top resets offset" do
    md = Ori::MarkdownNode.new(content: (1..50).map(&.to_s).join('\n'))
    md.rect = Ori::Rect.new(0, 0, 40, 5)
    md.view_down(10)
    md.goto_top
    md.y_offset.should eq(0)
  end

  it "goto_bottom" do
    md = Ori::MarkdownNode.new(content: (1..50).map(&.to_s).join('\n'))
    md.rect = Ori::Rect.new(0, 0, 40, 5)
    md.goto_bottom
    md.at_bottom?.should be_true
  end

  it "on_key handles up" do
    md = Ori::MarkdownNode.new(content: (1..20).map(&.to_s).join('\n'))
    md.rect = Ori::Rect.new(0, 0, 40, 5)
    md.view_down
    md.on_key(Ori::Key.new(code: :up)).should be_true
  end

  it "on_key handles down" do
    md = Ori::MarkdownNode.new(content: (1..20).map(&.to_s).join('\n'))
    md.rect = Ori::Rect.new(0, 0, 40, 5)
    md.on_key(Ori::Key.new(code: :down)).should be_true
  end

  it "on_key handles j/k" do
    md = Ori::MarkdownNode.new(content: (1..20).map(&.to_s).join('\n'))
    md.rect = Ori::Rect.new(0, 0, 40, 5)
    md.on_key(Ori::Key.new(text: "j")).should be_true
    md.on_key(Ori::Key.new(text: "k")).should be_true
  end

  it "on_key handles unknown" do
    md = Ori::MarkdownNode.new(content: "hello")
    md.on_key(Ori::Key.new(text: "x")).should be_false
  end

  it "on_mouse wheel up" do
    md = Ori::MarkdownNode.new(content: (1..20).map(&.to_s).join('\n'))
    md.rect = Ori::Rect.new(0, 0, 40, 5)
    md.view_down(5)
    md.on_mouse(Ori::Mouse.new(action: Ori::Mouse::Action::Wheel, button: Ori::Mouse::Button::WheelUp, x: 0, y: 0)).should be_true
  end

  it "on_mouse wheel down" do
    md = Ori::MarkdownNode.new(content: (1..20).map(&.to_s).join('\n'))
    md.rect = Ori::Rect.new(0, 0, 40, 5)
    md.on_mouse(Ori::Mouse.new(action: Ori::Mouse::Action::Wheel, button: Ori::Mouse::Button::WheelDown, x: 0, y: 0)).should be_true
  end

  it "on_mouse non-wheel returns false" do
    md = Ori::MarkdownNode.new(content: "hello")
    md.on_mouse(Ori::Mouse.new(action: Ori::Mouse::Action::Press, button: Ori::Mouse::Button::Left, x: 0, y: 0)).should be_false
  end

  it "renders code blocks" do
    md = Ori::MarkdownNode.new(content: "```crystal\nputs \"hi\"\n```")
    md.content_height.should be >= 1
  end

  it "renders numbered lists" do
    md = Ori::MarkdownNode.new(content: "1. first\n2. second\n3. third")
    md.content_height.should be >= 3
  end

  it "render_screen with content" do
    md = Ori::MarkdownNode.new(content: "# Hello\nWorld")
    md.rect = Ori::Rect.new(0, 0, 20, 5)
    scr = Ori::Screen.new(20, 5)
    md.render_screen(scr)
  end

  it "content_width" do
    md = Ori::MarkdownNode.new(content: "short\nvery long line here")
    md.content_width.should be > 0
  end
end

describe "DSL make_input" do
  it "creates input with defaults" do
    i = Ori::DSL.make_input
    i.should be_a(Ori::InputNode)
    i.value.should eq("")
  end

  it "creates input with value" do
    i = Ori::DSL.make_input(value: "hello")
    i.value.should eq("hello")
  end

  it "creates input with placeholder" do
    i = Ori::DSL.make_input(placeholder: "type here")
    i.should be_a(Ori::InputNode)
  end

  it "creates input with style opts" do
    i = Ori::DSL.make_input(fg: "#ff0000", bold: true, border: :rounded)
    i.should be_a(Ori::InputNode)
  end

  it "creates input with callbacks" do
    changed = false
    i = Ori::DSL.make_input(on_change: ->(v : String) { changed = true; nil })
    i.should be_a(Ori::InputNode)
  end
end

describe "DSL make_area" do
  it "creates area with defaults" do
    a = Ori::DSL.make_area
    a.should be_a(Ori::AreaNode)
    a.value.should eq("")
  end

  it "creates area with value" do
    a = Ori::DSL.make_area(value: "hello\nworld")
    a.value.should eq("hello\nworld")
  end

  it "creates area with cursor_row" do
    a = Ori::DSL.make_area(value: "line1\nline2\nline3", cursor_row: 1)
    a.cursor_row.should eq(1)
  end

  it "creates area with line numbers" do
    a = Ori::DSL.make_area(show_line_numbers: true)
    a.should be_a(Ori::AreaNode)
  end

  it "creates area with 3-arg on_change" do
    a = Ori::DSL.make_area(on_change: ->(v : String, r : Int32, c : Int32) { nil })
    a.should be_a(Ori::AreaNode)
  end

  it "creates area with highlights" do
    a = Ori::DSL.make_area(highlights: [{0, 0, 5}] of Tuple(Int32, Int32, Int32))
    a.should be_a(Ori::AreaNode)
  end

  it "creates area with char_limit" do
    a = Ori::DSL.make_area(char_limit: 100)
    a.should be_a(Ori::AreaNode)
  end
end

describe "DSL make_viewport" do
  it "creates viewport with content" do
    v = Ori::DSL.make_viewport(content: "hello\nworld")
    v.should be_a(Ori::Viewport)
  end

  it "creates viewport with soft_wrap false" do
    v = Ori::DSL.make_viewport(content: "long line", soft_wrap: false)
    v.should be_a(Ori::Viewport)
  end

  it "creates viewport with y_offset" do
    v = Ori::DSL.make_viewport(content: "hello", y_offset: 5)
    v.should be_a(Ori::Viewport)
  end
end

describe "DSL make_table" do
  it "creates table with headers and rows" do
    t = Ori::DSL.make_table(headers: ["A", "B"], rows: [["1", "2"]])
    t.should be_a(Ori::Table)
  end

  it "creates table empty" do
    t = Ori::DSL.make_table
    t.should be_a(Ori::Table)
  end

  it "creates table with selected_row" do
    t = Ori::DSL.make_table(headers: ["X"], rows: [["1"], ["2"]], selected_row: 1)
    t.should be_a(Ori::Table)
  end
end

describe "DSL make_list" do
  it "creates list with items" do
    items = [Ori::List::Item.new("a"), Ori::List::Item.new("b")]
    l = Ori::DSL.make_list(items: items)
    l.should be_a(Ori::List)
  end

  it "creates list checkable" do
    items = [Ori::List::Item.new("a")]
    l = Ori::DSL.make_list(items: items, checkable: true)
    l.should be_a(Ori::List)
  end

  it "creates list with custom prefixes" do
    items = [Ori::List::Item.new("a")]
    l = Ori::DSL.make_list(items: items, selected_prefix: "> ", normal_prefix: "  ")
    l.should be_a(Ori::List)
  end
end

describe "DSL make_select" do
  it "creates select with options" do
    s = Ori::DSL.make_select(options: ["a", "b", "c"])
    s.should be_a(Ori::Select)
  end

  it "creates select with selected" do
    s = Ori::DSL.make_select(options: ["a", "b"], selected: 1)
    s.should be_a(Ori::Select)
  end

  it "creates select with callbacks" do
    s = Ori::DSL.make_select(
      options: ["x"],
      on_change: ->(i : Int32) { nil },
      on_toggle: ->(b : Bool) { nil },
      on_highlight: ->(i : Int32) { nil },
    )
    s.should be_a(Ori::Select)
  end
end

describe "DSL make_spinner" do
  it "creates with default type" do
    s = Ori::DSL.make_spinner
    s.should be_a(Ori::Spinner)
  end

  it "creates with type" do
    s = Ori::DSL.make_spinner(type: :line)
    s.should be_a(Ori::Spinner)
  end
end

describe "DSL make_progress_bar" do
  it "creates with defaults" do
    p = Ori::DSL.make_progress_bar
    p.should be_a(Ori::ProgressBar)
  end

  it "creates with value and max" do
    p = Ori::DSL.make_progress_bar(value: 50.0, max: 200.0)
    p.should be_a(Ori::ProgressBar)
  end
end

describe "DSL make_date_picker" do
  it "creates with defaults" do
    d = Ori::DSL.make_date_picker
    d.should be_a(Ori::DatePicker)
  end

  it "creates with year/month/day" do
    d = Ori::DSL.make_date_picker(year: 2024, month: 6, day: 15)
    d.should be_a(Ori::DatePicker)
  end

  it "creates with monday_first" do
    d = Ori::DSL.make_date_picker(monday_first: true)
    d.should be_a(Ori::DatePicker)
  end

  it "creates with colors" do
    d = Ori::DSL.make_date_picker(
      header_fg: "#ff0000", selected_fg: "#00ff00", selected_bg: "#0000ff",
      today_fg: "#ffffff", today_bg: "#000000", day_fg: "#cccccc", other_month_fg: "#666666",
    )
    d.should be_a(Ori::DatePicker)
  end
end

describe "DSL make_datetime_picker" do
  it "creates with defaults" do
    d = Ori::DSL.make_datetime_picker
    d.should be_a(Ori::DateTimePicker)
  end

  it "creates with time" do
    d = Ori::DSL.make_datetime_picker(hour: 14, minute: 30)
    d.should be_a(Ori::DateTimePicker)
  end

  it "creates with all options" do
    d = Ori::DSL.make_datetime_picker(
      year: 2024, month: 1, day: 1, hour: 12, minute: 0,
      time_fg: "#fff", active_fg: "#000", active_bg: "#fff",
    )
    d.should be_a(Ori::DateTimePicker)
  end
end

describe "DSL make_file_picker" do
  it "creates with defaults" do
    f = Ori::DSL.make_file_picker
    f.should be_a(Ori::FilePicker)
  end

  it "creates with current_dir" do
    f = Ori::DSL.make_file_picker(current_dir: "/tmp")
    f.should be_a(Ori::FilePicker)
  end

  it "creates with allowed_types" do
    f = Ori::DSL.make_file_picker(allowed_types: [".cr", ".txt"])
    f.should be_a(Ori::FilePicker)
  end

  it "creates with show_hidden" do
    f = Ori::DSL.make_file_picker(show_hidden: true)
    f.should be_a(Ori::FilePicker)
  end
end

describe "DSL make_markdown" do
  it "creates with content" do
    m = Ori::DSL.make_markdown(content: "# Hello")
    m.should be_a(Ori::MarkdownNode)
  end

  it "creates with y_offset" do
    m = Ori::DSL.make_markdown(content: "text", y_offset: 3)
    m.should be_a(Ori::MarkdownNode)
  end
end

describe "DSL make_sparkline" do
  it "creates with data" do
    s = Ori::DSL.make_sparkline(data: [1.0, 2.0, 3.0])
    s.should be_a(Ori::Sparkline)
  end

  it "creates with manual max" do
    s = Ori::DSL.make_sparkline(data: [1.0], max: 10.0, auto_max: false)
    s.should be_a(Ori::Sparkline)
  end
end

describe "DSL make_help" do
  it "creates with bindings" do
    h = Ori::DSL.make_help(bindings: [Ori::HelpBinding.new(["q"], "q", "quit")])
    h.should be_a(Ori::Help)
  end

  it "creates with show_all" do
    h = Ori::DSL.make_help(bindings: [] of Ori::HelpBinding, show_all: true)
    h.should be_a(Ori::Help)
  end
end

describe "Ori::AreaNode extended" do
  it "cursor_position returns nil when not focused" do
    a = Ori::AreaNode.new(value: "hello")
    a.rect = Ori::Rect.new(0, 0, 20, 5)
    a.cursor_position.should be_nil
  end

  it "cursor_position returns pos when focused" do
    a = Ori::AreaNode.new(value: "hello")
    a.rect = Ori::Rect.new(0, 0, 20, 5)
    a.focused = true
    a.cursor_position.should_not be_nil
  end

  it "value= resets lines" do
    a = Ori::AreaNode.new(value: "old")
    a.value = "new\nline"
    a.value.should eq("new\nline")
  end

  it "line_count returns number of lines" do
    a = Ori::AreaNode.new(value: "a\nb\nc")
    a.line_count.should eq(3)
  end

  it "line returns specific line" do
    a = Ori::AreaNode.new(value: "a\nb\nc")
    a.line(0).should eq("a")
    a.line(1).should eq("b")
    a.line(2).should eq("c")
  end

  it "line out of bounds returns empty" do
    a = Ori::AreaNode.new(value: "hello")
    a.line(99).should eq("")
  end

  it "cursor_row and cursor_col" do
    a = Ori::AreaNode.new(value: "hello", cursor_row: 0)
    a.cursor_row.should eq(0)
    a.cursor_col.should eq(5)
  end

  it "handle ctrl+a (home)" do
    a = Ori::AreaNode.new(value: "hello")
    a.rect = Ori::Rect.new(0, 0, 20, 5)
    a.on_key(Ori::Key.new(text: "a", ctrl: true))
    a.cursor_col.should eq(0)
  end

  it "handle ctrl+e (end)" do
    a = Ori::AreaNode.new(value: "hello")
    a.rect = Ori::Rect.new(0, 0, 20, 5)
    a.on_key(Ori::Key.new(text: "a", ctrl: true))
    a.on_key(Ori::Key.new(text: "e", ctrl: true))
    a.cursor_col.should eq(5)
  end

  it "handle ctrl+k (kill to end)" do
    a = Ori::AreaNode.new(value: "hello")
    a.rect = Ori::Rect.new(0, 0, 20, 5)
    a.on_key(Ori::Key.new(text: "a", ctrl: true))
    a.on_key(Ori::Key.new(code: :right))
    a.on_key(Ori::Key.new(text: "k", ctrl: true))
    a.value.should eq("h")
  end

  it "handle ctrl+u (kill to start)" do
    a = Ori::AreaNode.new(value: "hello")
    a.rect = Ori::Rect.new(0, 0, 20, 5)
    a.on_key(Ori::Key.new(code: :left))
    a.on_key(Ori::Key.new(code: :left))
    a.on_key(Ori::Key.new(text: "u", ctrl: true))
    a.value.should eq("lo")
  end

  it "handle page up" do
    a = Ori::AreaNode.new(value: (1..20).map { |i| "line #{i}" }.join('\n'))
    a.rect = Ori::Rect.new(0, 0, 20, 5)
    a.on_key(Ori::Key.new(code: :down))
    a.on_key(Ori::Key.new(code: :pg_up))
    a.cursor_row.should eq(0)
  end

  it "handle page down" do
    a = Ori::AreaNode.new(value: (1..20).map { |i| "line #{i}" }.join('\n'))
    a.rect = Ori::Rect.new(0, 0, 20, 5)
    a.on_key(Ori::Key.new(code: :pg_down))
    a.cursor_row.should be > 0
  end

  it "word left moves to previous word" do
    a = Ori::AreaNode.new(value: "hello world")
    a.rect = Ori::Rect.new(0, 0, 20, 5)
    a.on_key(Ori::Key.new(alt: true, text: "b"))
    a.cursor_col.should eq(6)
  end

  it "word right at start moves to next word" do
    a = Ori::AreaNode.new(value: "hello world")
    a.rect = Ori::Rect.new(0, 0, 20, 5)
    a.on_key(Ori::Key.new(text: "a", ctrl: true))
    a.on_key(Ori::Key.new(alt: true, text: "f"))
    a.cursor_col.should eq(6)
  end

  it "delete word backward" do
    a = Ori::AreaNode.new(value: "hello world")
    a.rect = Ori::Rect.new(0, 0, 20, 5)
    a.on_key(Ori::Key.new(alt: true, code: :backspace))
    a.value.should eq("hello ")
  end

  it "delete word forward" do
    a = Ori::AreaNode.new(value: "hello world")
    a.rect = Ori::Rect.new(0, 0, 20, 5)
    a.on_key(Ori::Key.new(text: "a", ctrl: true))
    a.on_key(Ori::Key.new(alt: true, text: "d"))
    a.value.should eq("world")
  end

  it "char_limit blocks typing" do
    a = Ori::AreaNode.new(value: "12345", char_limit: 5)
    a.rect = Ori::Rect.new(0, 0, 20, 5)
    a.on_key(Ori::Key.new(text: "x")).should be_false
  end

  it "content_height respects min" do
    a = Ori::AreaNode.new(value: "hello")
    a.content_height.should be >= 1
  end

  it "content_width includes prefix" do
    a = Ori::AreaNode.new(value: "hi", style: Ori::S.new(border: :single))
    cw = a.content_width
    cw.should be > 2
  end

  it "render_screen with border" do
    a = Ori::AreaNode.new(value: "hello", style: Ori::S.new(border: :single))
    a.rect = Ori::Rect.new(0, 0, 20, 3)
    scr = Ori::Screen.new(20, 3)
    a.render_screen(scr)
  end

  it "fire_change callback" do
    changed = false
    a = Ori::AreaNode.new(value: "", on_change: ->(v : String, r : Int32, c : Int32) { changed = true; nil })
    a.rect = Ori::Rect.new(0, 0, 20, 5)
    a.on_key(Ori::Key.new(text: "x"))
    changed.should be_true
  end

  it "fire_cursor callback" do
    cursor = nil
    a = Ori::AreaNode.new(value: "hello", on_cursor: ->(r : Int32, c : Int32) { cursor = {r, c}; nil })
    a.rect = Ori::Rect.new(0, 0, 20, 5)
    a.on_key(Ori::Key.new(code: :left))
    cursor.should eq({0, 4})
  end
end

describe "Ori::Viewport extended" do
  it "scroll up at top" do
    v = Ori::Viewport.new(content: "hello")
    v.rect = Ori::Rect.new(0, 0, 20, 5)
    v.view_up
    v.y_offset.should eq(0)
  end

  it "scroll down" do
    content = (1..50).map(&.to_s).join('\n')
    v = Ori::Viewport.new(content: content)
    v.rect = Ori::Rect.new(0, 0, 20, 5)
    v.view_down
    v.y_offset.should be > 0
  end

  it "goto_top" do
    content = (1..50).map(&.to_s).join('\n')
    v = Ori::Viewport.new(content: content)
    v.rect = Ori::Rect.new(0, 0, 20, 5)
    v.view_down(10)
    v.goto_top
    v.y_offset.should eq(0)
  end

  it "goto_bottom" do
    content = (1..50).map(&.to_s).join('\n')
    v = Ori::Viewport.new(content: content)
    v.rect = Ori::Rect.new(0, 0, 20, 5)
    v.goto_bottom
    v.at_bottom?.should be_true
  end

  it "on_key page up" do
    content = (1..50).map(&.to_s).join('\n')
    v = Ori::Viewport.new(content: content)
    v.rect = Ori::Rect.new(0, 0, 20, 5)
    v.view_down(10)
    offset_before = v.y_offset
    v.on_key(Ori::Key.new(code: :pg_up))
    v.y_offset.should be < offset_before
  end

  it "on_mouse wheel" do
    content = (1..50).map(&.to_s).join('\n')
    v = Ori::Viewport.new(content: content)
    v.rect = Ori::Rect.new(0, 0, 20, 5)
    v.on_mouse(Ori::Mouse.new(action: Ori::Mouse::Action::Wheel, button: Ori::Mouse::Button::WheelDown, x: 0, y: 0))
    v.y_offset.should be > 0
  end

  it "on_scroll callback" do
    offset = 0
    content = (1..50).map(&.to_s).join('\n')
    v = Ori::Viewport.new(content: content, on_scroll: ->(o : Int32) { offset = o; nil })
    v.rect = Ori::Rect.new(0, 0, 20, 5)
    v.view_down
    offset.should be > 0
  end

  it "content_height with soft wrap" do
    content = "a very long line that should wrap"
    v = Ori::Viewport.new(content: content, soft_wrap: true)
    v.rect = Ori::Rect.new(0, 0, 10, 5)
    v.content_height.should be > 0
  end

  it "content_height without soft wrap" do
    content = "a very long line that should not wrap"
    v = Ori::Viewport.new(content: content, soft_wrap: false)
    v.rect = Ori::Rect.new(0, 0, 10, 5)
    v.content_height.should be >= 1
  end

  it "render_screen" do
    v = Ori::Viewport.new(content: "hello\nworld")
    v.rect = Ori::Rect.new(0, 0, 20, 5)
    scr = Ori::Screen.new(20, 5)
    v.render_screen(scr)
  end
end

describe "Ori::InputNode extended" do
  it "cursor_position when focused" do
    i = Ori::InputNode.new(value: "abc")
    i.rect = Ori::Rect.new(0, 0, 20, 1)
    i.focused = true
    pos = i.cursor_position
    pos.should_not be_nil
  end

  it "cursor_position when not focused" do
    i = Ori::InputNode.new(value: "abc")
    i.rect = Ori::Rect.new(0, 0, 20, 1)
    i.cursor_position.should be_nil
  end

  it "handles delete" do
    i = Ori::InputNode.new(value: "abc")
    i.rect = Ori::Rect.new(0, 0, 20, 1)
    i.on_key(Ori::Key.new(code: :left))
    i.on_key(Ori::Key.new(code: :delete))
    i.value.should eq("ab")
  end

  it "handles home" do
    i = Ori::InputNode.new(value: "abc")
    i.rect = Ori::Rect.new(0, 0, 20, 1)
    i.on_key(Ori::Key.new(code: :home))
    i.on_key(Ori::Key.new(text: "x"))
    i.value.should eq("xabc")
  end

  it "handles end" do
    i = Ori::InputNode.new(value: "abc")
    i.rect = Ori::Rect.new(0, 0, 20, 1)
    i.on_key(Ori::Key.new(code: :home))
    i.on_key(Ori::Key.new(code: :end))
    i.on_key(Ori::Key.new(text: "x"))
    i.value.should eq("abcx")
  end

  it "handles left arrow at start" do
    i = Ori::InputNode.new(value: "abc")
    i.rect = Ori::Rect.new(0, 0, 20, 1)
    i.on_key(Ori::Key.new(code: :home))
    i.on_key(Ori::Key.new(code: :left))
  end

  it "handles right arrow at end" do
    i = Ori::InputNode.new(value: "abc")
    i.rect = Ori::Rect.new(0, 0, 20, 1)
    i.on_key(Ori::Key.new(code: :right))
  end

  it "on_change callback fires" do
    changed = false
    i = Ori::InputNode.new(on_change: ->(v : String) { changed = true; nil })
    i.rect = Ori::Rect.new(0, 0, 20, 1)
    i.on_key(Ori::Key.new(text: "a"))
    changed.should be_true
  end

  it "on_submit callback fires" do
    submitted = false
    i = Ori::InputNode.new(on_submit: -> { submitted = true; nil })
    i.rect = Ori::Rect.new(0, 0, 20, 1)
    i.on_key(Ori::Key.new(code: :enter))
    submitted.should be_true
  end

  it "ignores ctrl keys" do
    i = Ori::InputNode.new(value: "abc")
    i.rect = Ori::Rect.new(0, 0, 20, 1)
    i.on_key(Ori::Key.new(text: "c", ctrl: true)).should be_false
    i.value.should eq("abc")
  end

  it "content_width returns value size" do
    i = Ori::InputNode.new(value: "hello")
    i.content_width.should eq(5)
  end

  it "content_height returns 1" do
    i = Ori::InputNode.new
    i.content_height.should eq(1)
  end
end

describe "Ori::Node base" do
  it "defaults rect to zero" do
    t = Ori::TextNode.new("x")
    t.rect.x.should eq(0)
    t.rect.y.should eq(0)
    t.rect.w.should eq(0)
    t.rect.h.should eq(0)
  end

  it "defaults not focused" do
    t = Ori::TextNode.new("x")
    t.focused.should be_false
  end

  it "sets focused" do
    t = Ori::TextNode.new("x")
    t.focused = true
    t.focused.should be_true
  end

  it "effective_bg returns style bg" do
    t = Ori::TextNode.new("x", style: Ori::S.new(bg: "#000000"))
    t.effective_bg.should eq("#000000")
  end

  it "effective_bg falls back to inherited" do
    t = Ori::TextNode.new("x")
    t.inherited_bg = "#111111"
    t.effective_bg.should eq("#111111")
  end

  it "effective_bg prefers style over inherited" do
    t = Ori::TextNode.new("x", style: Ori::S.new(bg: "#000000"))
    t.inherited_bg = "#111111"
    t.effective_bg.should eq("#000000")
  end

  it "on_key returns false" do
    t = Ori::TextNode.new("x")
    t.on_key(Ori::Key.new(text: "a")).should be_false
  end

  it "on_mouse returns false" do
    t = Ori::TextNode.new("x")
    t.on_mouse(Ori::Mouse.new(action: Ori::Mouse::Action::Press, button: Ori::Mouse::Button::Left, x: 0, y: 0)).should be_false
  end

  it "render_screen is no-op" do
    t = Ori::TextNode.new("x")
    scr = Ori::Screen.new(10, 5)
    t.render_screen(scr)
  end

  it "render_overlay is no-op" do
    t = Ori::TextNode.new("x")
    scr = Ori::Screen.new(10, 5)
    t.render_overlay(scr)
  end

  it "blur is no-op" do
    t = Ori::TextNode.new("x")
    t.blur
  end

  it "focusable defaults to false" do
    t = Ori::TextNode.new("x")
    t.focusable?.should be_false
  end

  it "focusable true when set" do
    t = Ori::TextNode.new("x", style: Ori::S.new(focusable: true))
    t.focusable?.should be_true
  end
end

describe "Ori::Mouse" do
  it "creates with action and button" do
    m = Ori::Mouse.new(action: Ori::Mouse::Action::Press, button: Ori::Mouse::Button::Left, x: 5, y: 10)
    m.x.should eq(5)
    m.y.should eq(10)
  end

  it "Action has Press" do
    Ori::Mouse::Action::Press.should be_a(Ori::Mouse::Action)
  end

  it "Action has Wheel" do
    Ori::Mouse::Action::Wheel.should be_a(Ori::Mouse::Action)
  end

  it "Button has Left" do
    Ori::Mouse::Button::Left.should be_a(Ori::Mouse::Button)
  end

  it "Button has Right" do
    Ori::Mouse::Button::Right.should be_a(Ori::Mouse::Button)
  end

  it "Button has Middle" do
    Ori::Mouse::Button::Middle.should be_a(Ori::Mouse::Button)
  end

  it "Button has WheelUp" do
    Ori::Mouse::Button::WheelUp.should be_a(Ori::Mouse::Button)
  end

  it "Button has WheelDown" do
    Ori::Mouse::Button::WheelDown.should be_a(Ori::Mouse::Button)
  end

  it "Button has None" do
    Ori::Mouse::Button::None.should be_a(Ori::Mouse::Button)
  end
end

describe "Ori::Screen extended" do
  it "resize changes dimensions" do
    s = Ori::Screen.new(10, 5)
    s.resize(20, 10)
  end

  it "clear resets buffer" do
    s = Ori::Screen.new(10, 5)
    s.put(0, 0, 'x')
    s.clear
  end

  it "write sets string" do
    s = Ori::Screen.new(20, 5)
    s.write(0, 0, "hello", fg: "#ffffff")
  end

  it "put at valid coords" do
    s = Ori::Screen.new(10, 5)
    s.put(5, 3, 'A', fg: "#ff0000")
  end

  it "put at out-of-bounds does not crash" do
    s = Ori::Screen.new(10, 5)
    s.put(100, 100, 'x')
  end

  it "flush to IO" do
    s = Ori::Screen.new(10, 1)
    s.put(0, 0, 'X')
    io = IO::Memory.new
    s.flush(io)
  end
end

describe "Ori::FocusManager" do
  it "handles empty tree" do
    fm = Ori::FocusManager.new
    fm.update(Ori::Box.new([] of Ori::Node))
  end

  it "handles tree with one focusable" do
    i = Ori::InputNode.new(style: Ori::S.new(focusable: true))
    b = Ori::Box.new([i] of Ori::Node)
    fm = Ori::FocusManager.new
    fm.update(b)
    i.focused.should be_true
  end

  it "tab cycles focus" do
    i1 = Ori::InputNode.new(style: Ori::S.new(focusable: true))
    i2 = Ori::InputNode.new(style: Ori::S.new(focusable: true))
    b = Ori::Box.new([i1, i2] of Ori::Node)
    fm = Ori::FocusManager.new
    fm.update(b)
    i1.focused.should be_true
    fm.handle_key(Ori::Key.new(code: :tab))
    i1.focused.should be_false
    i2.focused.should be_true
  end

  it "shift-tab cycles backwards" do
    i1 = Ori::InputNode.new(style: Ori::S.new(focusable: true))
    i2 = Ori::InputNode.new(style: Ori::S.new(focusable: true))
    b = Ori::Box.new([i1, i2] of Ori::Node)
    fm = Ori::FocusManager.new
    fm.update(b)
    fm.handle_key(Ori::Key.new(code: :tab))
    fm.handle_key(Ori::Key.new(code: :tab, shift: true))
    i1.focused.should be_true
  end

  it "dispatches key to focused node" do
    i = Ori::InputNode.new(style: Ori::S.new(focusable: true))
    b = Ori::Box.new([i] of Ori::Node)
    fm = Ori::FocusManager.new
    fm.update(b)
    fm.handle_key(Ori::Key.new(text: "a"))
    i.value.should eq("a")
  end

  it "handles no focusable nodes" do
    t = Ori::TextNode.new("x")
    b = Ori::Box.new([t] of Ori::Node)
    fm = Ori::FocusManager.new
    fm.update(b)
  end
end

describe "Ori::ProgressBar extended" do
  it "content_height returns 1" do
    p = Ori::ProgressBar.new
    p.content_height.should eq(1)
  end

  it "content_width returns 10" do
    p = Ori::ProgressBar.new
    p.content_width.should eq(10)
  end

  it "not focusable" do
    p = Ori::ProgressBar.new
    p.focusable?.should be_false
  end

  it "render to IO" do
    p = Ori::ProgressBar.new(value: 50.0, max: 100.0)
    p.rect = Ori::Rect.new(0, 0, 20, 1)
    io = IO::Memory.new
    p.render(io)
  end

  it "render_screen" do
    p = Ori::ProgressBar.new(value: 75.0, max: 100.0)
    p.rect = Ori::Rect.new(0, 0, 20, 1)
    scr = Ori::Screen.new(20, 1)
    p.render_screen(scr)
  end

  it "full progress" do
    p = Ori::ProgressBar.new(value: 100.0, max: 100.0)
    p.rect = Ori::Rect.new(0, 0, 20, 1)
    scr = Ori::Screen.new(20, 1)
    p.render_screen(scr)
  end

  it "zero progress" do
    p = Ori::ProgressBar.new(value: 0.0, max: 100.0)
    p.rect = Ori::Rect.new(0, 0, 20, 1)
    scr = Ori::Screen.new(20, 1)
    p.render_screen(scr)
  end
end

describe "Ori::Spinner extended" do
  it "content_height returns 1" do
    s = Ori::Spinner.new
    s.content_height.should eq(1)
  end

  it "content_width returns 1" do
    s = Ori::Spinner.new
    s.content_width.should eq(1)
  end

  it "not focusable" do
    s = Ori::Spinner.new
    s.focusable?.should be_false
  end

  it "frame advances" do
    s = Ori::Spinner.new
    s.frame.should_not be_empty
  end

  it "reset restarts animation" do
    s = Ori::Spinner.new
    s.reset
    s.frame.should_not be_empty
  end

  it "frame= sets index" do
    s = Ori::Spinner.new
    s.frame = 3
    s.frame.should_not be_empty
  end

  it "render to IO" do
    s = Ori::Spinner.new
    s.rect = Ori::Rect.new(0, 0, 5, 1)
    io = IO::Memory.new
    s.render(io)
  end
end

describe "Ori::Table extended" do
  it "handles many rows" do
    rows = (1..100).map { |i| ["row #{i}"] }
    t = Ori::Table.new(headers: ["Col"], rows: rows)
    t.content_height.should be > 0
  end

  it "handles empty headers" do
    t = Ori::Table.new(headers: [] of String, rows: [["1"]])
    t.content_height.should be > 0
  end

  it "content_width sums column widths" do
    t = Ori::Table.new(headers: ["A", "BB"], rows: [["1", "22"]])
    t.content_width.should be > 0
  end

  it "render_screen" do
    t = Ori::Table.new(headers: ["A", "B"], rows: [["1", "2"]])
    t.rect = Ori::Rect.new(0, 0, 20, 5)
    scr = Ori::Screen.new(20, 5)
    t.render_screen(scr)
  end
end

describe "Ori::List extended" do
  it "on_key up/down navigates" do
    items = (1..5).map { |i| Ori::List::Item.new("item #{i}") }
    l = Ori::List.new(items: items)
    l.on_key(Ori::Key.new(code: :down))
  end

  it "on_key enter" do
    items = [Ori::List::Item.new("a")]
    l = Ori::List.new(items: items)
    l.on_key(Ori::Key.new(code: :enter))
  end

  it "render_screen" do
    items = [Ori::List::Item.new("a"), Ori::List::Item.new("b")]
    l = Ori::List.new(items: items)
    l.rect = Ori::Rect.new(0, 0, 20, 5)
    scr = Ori::Screen.new(20, 5)
    l.render_screen(scr)
  end
end

describe "Ori::Rect extended further" do
  it "inner with no frame" do
    r = Ori::Rect.new(0, 0, 20, 10)
    s = Ori::S.new
    inner = r.inner(s)
    inner.x.should eq(0)
    inner.y.should eq(0)
    inner.w.should eq(20)
    inner.h.should eq(10)
  end

  it "inner with border" do
    r = Ori::Rect.new(0, 0, 20, 10)
    s = Ori::S.new(border: true)
    inner = r.inner(s)
    inner.x.should eq(0)
    inner.y.should eq(0)
    inner.w.should eq(20)
    inner.h.should eq(10)
  end

  it "inner with border and padding" do
    r = Ori::Rect.new(0, 0, 30, 20)
    s = Ori::S.new(border: true, padding: 2)
    inner = r.inner(s)
    inner.x.should eq(2)
    inner.y.should eq(2)
    inner.w.should eq(26)
    inner.h.should eq(16)
  end

  it "contains all edges" do
    r = Ori::Rect.new(5, 5, 10, 10)
    r.contains?(5, 5).should be_true
    r.contains?(14, 14).should be_true
    r.contains?(15, 5).should be_false
    r.contains?(5, 15).should be_false
    r.contains?(10, 10).should be_true
  end
end

describe "Ori::S extended further" do
  it "2-tuple padding" do
    s = Ori::S.new(padding: {2, 4})
    s.padding_top.should eq(2)
    s.padding_bottom.should eq(2)
    s.padding_left.should eq(4)
    s.padding_right.should eq(4)
  end

  it "scrollable" do
    s = Ori::S.new(scrollable: true)
    s.scrollable.should be_true
  end

  it "bar_style" do
    s = Ori::S.new(bar_style: :solid)
    s.bar_style.should eq(:solid)
  end

  it "gradient_to" do
    s = Ori::S.new(gradient_to: "#ff0000")
    s.gradient_to.should eq("#ff0000")
  end

  it "width_pct" do
    s = Ori::S.new(width_pct: 50.0)
    s.width_pct.should eq(50.0)
  end

  it "height_pct" do
    s = Ori::S.new(height_pct: 75.0)
    s.height_pct.should eq(75.0)
  end

  it "width_val" do
    s = Ori::S.new(width: 40)
    s.width.should eq(40)
  end

  it "height_val" do
    s = Ori::S.new(height: 10)
    s.height.should eq(10)
  end

  it "border_size rounded" do
    s = Ori::S.new(border: :rounded)
    s.border_size.should eq(1)
  end

  it "border_size double" do
    s = Ori::S.new(border: :double)
    s.border_size.should eq(1)
  end

  it "border_size true" do
    s = Ori::S.new(border: true)
    s.border_size.should eq(1)
  end

  it "frame_h with border and padding" do
    s = Ori::S.new(border: true, padding: 3)
    s.frame_h.should eq(8)
  end

  it "frame_v with border and padding" do
    s = Ori::S.new(border: true, padding: 2)
    s.frame_v.should eq(6)
  end

  it "hpadding with border and padding" do
    s = Ori::S.new(border: true, padding: 1)
    s.hpadding.should eq(2)
  end

  it "vpadding with border and padding" do
    s = Ori::S.new(border: true, padding: 1)
    s.vpadding.should eq(2)
  end
end

describe "DSL extract_style extended" do
  it "extracts width as int" do
    s = Ori::DSL.extract_style(width: 40)
    s.width.should eq(40)
  end

  it "extracts width as percent" do
    s = Ori::DSL.extract_style(width: "50%")
    s.width_pct.should eq(50.0)
  end

  it "extracts height as int" do
    s = Ori::DSL.extract_style(height: 10)
    s.height.should eq(10)
  end

  it "extracts height as percent" do
    s = Ori::DSL.extract_style(height: "75%")
    s.height_pct.should eq(75.0)
  end

  it "extracts direction" do
    s = Ori::DSL.extract_style(direction: :horizontal)
    s.direction.should eq(:horizontal)
  end

  it "extracts align center" do
    s = Ori::DSL.extract_style(align: :center)
    s.align.should eq(:center)
  end

  it "extracts focusable" do
    s = Ori::DSL.extract_style(focusable: true)
    s.focusable.should be_true
  end

  it "extracts scrollable" do
    s = Ori::DSL.extract_style(scrollable: true)
    s.scrollable.should be_true
  end

  it "extracts gradient_to" do
    s = Ori::DSL.extract_style(gradient_to: "#ff0000")
    s.gradient_to.should eq("#ff0000")
  end

  it "extracts bar_style" do
    s = Ori::DSL.extract_style(bar_style: :gradient)
    s.bar_style.should eq(:gradient)
  end

  it "extracts underline" do
    s = Ori::DSL.extract_style(underline: true)
    s.underline.should be_true
  end

  it "extracts strikethrough" do
    s = Ori::DSL.extract_style(strikethrough: true)
    s.strikethrough.should be_true
  end

  it "extracts border_fg" do
    s = Ori::DSL.extract_style(border_fg: "#ff0000")
    s.border_fg.should eq("#ff0000")
  end

  it "extracts dim" do
    s = Ori::DSL.extract_style(dim: true)
    s.dim.should be_true
  end
end

describe "Ori::Key extended further" do
  it "Key::Code has Enter" do
    Ori::Key::Code::Enter.should be_a(Ori::Key::Code)
  end

  it "Key::Code has Escape" do
    Ori::Key::Code::Escape.should be_a(Ori::Key::Code)
  end

  it "Key::Code has Tab" do
    Ori::Key::Code::Tab.should be_a(Ori::Key::Code)
  end

  it "Key::Code has Backspace" do
    Ori::Key::Code::Backspace.should be_a(Ori::Key::Code)
  end

  it "Key::Code has Delete" do
    Ori::Key::Code::Delete.should be_a(Ori::Key::Code)
  end

  it "Key::Code has Home" do
    Ori::Key::Code::Home.should be_a(Ori::Key::Code)
  end

  it "Key::Code has End" do
    Ori::Key::Code::End.should be_a(Ori::Key::Code)
  end

  it "Key::Code has PgUp" do
    Ori::Key::Code::PgUp.should be_a(Ori::Key::Code)
  end

  it "Key::Code has PgDown" do
    Ori::Key::Code::PgDown.should be_a(Ori::Key::Code)
  end

  it "Key::Code has Space" do
    Ori::Key::Code::Space.should be_a(Ori::Key::Code)
  end

  it "code predicates" do
    k = Ori::Key.new(code: :up)
    k.code.up?.should be_true
    k.code.down?.should be_false
  end

  it "shift+text still printable" do
    k = Ori::Key.new(text: "A", shift: true)
    k.shift.should be_true
    k.text.should eq("A")
  end
end

describe "Ori::InputParser extended" do
  it "parses escape key" do
    p = Ori::InputParser.new
    result = nil
    result = p.parse_full(0x1b_u8)
    result.should be_nil
  end

  it "parses tab" do
    p = Ori::InputParser.new
    result = p.parse_full('\t'.ord.to_u8)
    result.should_not be_nil
    if r = result
      r.key.should_not be_nil
      r.key.not_nil!.code.should eq(Ori::Key::Code::Tab)
    end
  end

  it "parses backspace" do
    p = Ori::InputParser.new
    result = p.parse_full(0x7f_u8)
    result.should_not be_nil
    if r = result
      r.key.should_not be_nil
      r.key.not_nil!.code.should eq(Ori::Key::Code::Backspace)
    end
  end

  it "parses escape sequence for home" do
    parser = Ori::InputParser.new
    esc = "\e[H".bytes
    result = nil
    esc.each do |b|
      result = parser.parse_full(b)
    end
    result.should_not be_nil
    if r = result
      k = r.key
      k.should_not be_nil
      k.not_nil!.code.should eq(Ori::Key::Code::Home)
    end
  end

  it "parses escape sequence for end" do
    parser = Ori::InputParser.new
    esc = "\e[F".bytes
    result = nil
    esc.each do |b|
      result = parser.parse_full(b)
    end
    result.should_not be_nil
    if r = result
      k = r.key
      k.should_not be_nil
      k.not_nil!.code.should eq(Ori::Key::Code::End)
    end
  end

  it "parses escape sequence for delete" do
    parser = Ori::InputParser.new
    esc = "\e[3~".bytes
    result = nil
    esc.each do |b|
      result = parser.parse_full(b)
    end
    result.should_not be_nil
    if r = result
      k = r.key
      k.should_not be_nil
      k.not_nil!.code.should eq(Ori::Key::Code::Delete)
    end
  end

  it "parses escape sequence for pgup" do
    parser = Ori::InputParser.new
    esc = "\e[5~".bytes
    result = nil
    esc.each do |b|
      result = parser.parse_full(b)
    end
    result.should_not be_nil
    if r = result
      k = r.key
      k.should_not be_nil
      k.not_nil!.code.should eq(Ori::Key::Code::PgUp)
    end
  end

  it "parses escape sequence for pgdown" do
    parser = Ori::InputParser.new
    esc = "\e[6~".bytes
    result = nil
    esc.each do |b|
      result = parser.parse_full(b)
    end
    result.should_not be_nil
    if r = result
      k = r.key
      k.should_not be_nil
      k.not_nil!.code.should eq(Ori::Key::Code::PgDown)
    end
  end

  it "not in escape state initially" do
    p = Ori::InputParser.new
    p.in_escape_state?.should be_false
  end
end

describe "Ori::Box layout extended" do
  it "multiple flex children share space" do
    c1 = Ori::TextNode.new("a", style: Ori::S.new(flex: 1))
    c2 = Ori::TextNode.new("b", style: Ori::S.new(flex: 1))
    box = Ori::Box.new([c1, c2] of Ori::Node)
    box.rect = Ori::Rect.new(0, 0, 40, 10)
    box.layout
    c1.rect.h.should eq(5)
    c2.rect.h.should eq(5)
  end

  it "mixed fixed and flex" do
    c1 = Ori::TextNode.new("a", style: Ori::S.new(height: 2))
    c2 = Ori::TextNode.new("b", style: Ori::S.new(flex: 2))
    c3 = Ori::TextNode.new("c", style: Ori::S.new(flex: 1))
    box = Ori::Box.new([c1, c2, c3] of Ori::Node)
    box.rect = Ori::Rect.new(0, 0, 40, 14)
    box.layout
    c1.rect.h.should eq(2)
    c2.rect.h.should eq(8)
    c3.rect.h.should eq(4)
  end

  it "horizontal with flex" do
    c1 = Ori::TextNode.new("a", style: Ori::S.new(flex: 1, height: 1))
    c2 = Ori::TextNode.new("b", style: Ori::S.new(flex: 3, height: 1))
    box = Ori::Box.new([c1, c2] of Ori::Node, style: Ori::S.new(direction: :horizontal))
    box.rect = Ori::Rect.new(0, 0, 40, 1)
    box.layout
    c1.rect.w.should eq(10)
    c2.rect.w.should eq(30)
  end

  it "border offsets children" do
    c = Ori::TextNode.new("x", style: Ori::S.new(height: 4))
    box = Ori::Box.new([c] of Ori::Node, style: Ori::S.new(border: :single))
    box.rect = Ori::Rect.new(0, 0, 20, 10)
    box.layout
    c.rect.x.should eq(0)
    c.rect.y.should eq(0)
    c.rect.w.should eq(20)
    c.rect.h.should eq(4)
  end

  it "render_screen draws border" do
    c = Ori::TextNode.new("hi", style: Ori::S.new(height: 1))
    box = Ori::Box.new([c] of Ori::Node, style: Ori::S.new(border: :rounded))
    box.rect = Ori::Rect.new(0, 0, 10, 3)
    box.layout
    scr = Ori::Screen.new(10, 3)
    box.render_screen(scr)
  end

  it "empty box renders" do
    box = Ori::Box.new([] of Ori::Node)
    box.rect = Ori::Rect.new(0, 0, 10, 5)
    scr = Ori::Screen.new(10, 5)
    box.render_screen(scr)
  end

  it "deeply nested layout" do
    inner = Ori::Box.new([Ori::TextNode.new("x", style: Ori::S.new(height: 1))] of Ori::Node)
    outer = Ori::Box.new([inner] of Ori::Node)
    outer.rect = Ori::Rect.new(0, 0, 20, 10)
    outer.layout
    inner.rect.w.should be > 0
    inner.rect.h.should be > 0
  end
end

describe "Ori::Paginator extended" do
  it "total_pages with zero items" do
    p = Ori::Paginator.new(per_page: 10)
    p.set_total_pages(0)
    p.total_pages.should eq(0)
  end

  it "next_page wraps" do
    p = Ori::Paginator.new(per_page: 10)
    p.set_total_pages(15)
    p.next_page
    p.page.should eq(1)
    p.next_page
    p.page.should eq(1)
  end

  it "prev_page wraps" do
    p = Ori::Paginator.new(per_page: 10)
    p.set_total_pages(15)
    p.prev_page
    p.page.should eq(0)
  end

  it "total_pages with zero items" do
    p = Ori::Paginator.new(per_page: 10)
    p.set_total_pages(0)
    p.total_pages.should eq(0)
  end

  it "next_page wraps" do
    p = Ori::Paginator.new(per_page: 10)
    p.set_total_pages(15)
    p.next_page
    p.page.should eq(1)
    p.next_page
    p.page.should eq(1)
  end

  it "prev_page wraps" do
    p = Ori::Paginator.new(per_page: 10)
    p.set_total_pages(15)
    p.prev_page
    p.page.should eq(0)
  end

  it "slice_bounds" do
    p = Ori::Paginator.new(per_page: 10)
    p.set_total_pages(25)
    p.slice_bounds(25).should eq({0, 10})
    p.next_page
    p.slice_bounds(25).should eq({10, 20})
  end

  it "items_on_page" do
    p = Ori::Paginator.new(per_page: 10)
    p.set_total_pages(15)
    p.items_on_page(15).should eq(10)
    p.next_page
    p.items_on_page(15).should eq(5)
  end

  it "on_first_page" do
    p = Ori::Paginator.new(per_page: 10)
    p.set_total_pages(25)
    p.on_first_page?.should be_true
  end

  it "on_last_page" do
    p = Ori::Paginator.new(per_page: 10)
    p.set_total_pages(15)
    p.next_page
    p.on_last_page?.should be_true
  end

  it "dots view single page" do
    p = Ori::Paginator.new(per_page: 10, type: Ori::Paginator::Type::Dots)
    p.set_total_pages(5)
    p.view.should eq("•")
  end

  it "arabic view single page" do
    p = Ori::Paginator.new(per_page: 10, type: Ori::Paginator::Type::Arabic)
    p.set_total_pages(5)
    p.view.should eq("1/1")
  end

  it "per_page accessor" do
    p = Ori::Paginator.new(per_page: 5)
    p.per_page.should eq(5)
  end
end

describe "Ori::FilePicker extended" do
  it "content_height" do
    f = Ori::FilePicker.new(current_dir: "/tmp")
    f.content_height.should be >= 1
  end

  it "content_width" do
    f = Ori::FilePicker.new(current_dir: "/tmp")
    f.content_width.should be >= 1
  end

  it "focusable" do
    f = Ori::FilePicker.new(current_dir: "/tmp")
    f.focusable?.should be_true
  end
end

describe "Ori::Sparkline extended" do
  it "content_height with data" do
    sl = Ori::Sparkline.new(data: [1.0, 5.0, 3.0, 8.0])
    sl.content_height.should be >= 1
  end

  it "clear data" do
    sl = Ori::Sparkline.new(data: [1.0, 2.0])
    sl.data.size.should eq(2)
  end

  it "render_screen" do
    sl = Ori::Sparkline.new(data: [1.0, 5.0, 3.0])
    sl.rect = Ori::Rect.new(0, 0, 10, 5)
    scr = Ori::Screen.new(10, 5)
    sl.render_screen(scr)
  end

  it "auto_max updates on push" do
    sl = Ori::Sparkline.new(data: [1.0, 2.0])
    sl.max.should eq(2.0)
    sl.push(10.0)
    sl.max.should eq(10.0)
  end
end

describe "Ori::Help extended" do
  it "render_screen short mode" do
    bindings = [Ori::HelpBinding.new(["j"], "j", "down"), Ori::HelpBinding.new(["q"], "q", "quit")]
    h = Ori::Help.new(bindings: bindings)
    h.rect = Ori::Rect.new(0, 0, 40, 1)
    scr = Ori::Screen.new(40, 1)
    h.render_screen(scr)
  end

  it "render_screen full mode" do
    bindings = [Ori::HelpBinding.new(["j"], "j", "down"), Ori::HelpBinding.new(["q"], "q", "quit")]
    h = Ori::Help.new(bindings: bindings, show_all: true)
    h.rect = Ori::Rect.new(0, 0, 40, 5)
    scr = Ori::Screen.new(40, 5)
    h.render_screen(scr)
  end

  it "content_width" do
    bindings = [Ori::HelpBinding.new(["j", "k"], "j/k", "navigate")]
    h = Ori::Help.new(bindings: bindings)
    h.content_width.should be > 0
  end

  it "HelpBinding fields" do
    b = Ori::HelpBinding.new(["ctrl+c"], "ctrl+c", "quit")
    b.keys.should eq(["ctrl+c"])
    b.help_key.should eq("ctrl+c")
    b.help_desc.should eq("quit")
  end
end
