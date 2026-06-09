require "spec"
require "../src/ori"

describe "FocusManager negative index bug" do
  it "handle_key with empty nodes does not dispatch to last" do
    fm = Ori::FocusManager.new
    root = Ori::Box.new
    fm.update(root)
    result = fm.handle_key(Ori::Key.new(text: "a"))
    result.should be_false
  end

  it "tab on empty tree returns false" do
    fm = Ori::FocusManager.new
    root = Ori::Box.new
    fm.update(root)
    fm.handle_key(Ori::Key.new(code: :tab)).should be_false
  end

  it "focus_first on empty tree does not set negative index" do
    fm = Ori::FocusManager.new
    root = Ori::Box.new
    fm.update(root)
    fm.focus_first
    fm.handle_key(Ori::Key.new(text: "x")).should be_false
  end
end

describe "Table empty rows edge cases" do
  it "empty rows does not crash on navigation" do
    t = Ori::Table.new(rows: [] of Array(String), selected_row: 0)
    t.on_key(Ori::Key.new(code: :down))
    t.on_key(Ori::Key.new(code: :up))
    t.on_key(Ori::Key.new(code: :home))
    t.on_key(Ori::Key.new(code: :end))
  end

  it "empty rows with headers does not crash" do
    t = Ori::Table.new(headers: ["A"], rows: [] of Array(String), selected_row: 0)
    t.on_key(Ori::Key.new(code: :down))
  end

  it "single row selection stays valid" do
    t = Ori::Table.new(rows: [["x"]], selected_row: 0)
    t.on_key(Ori::Key.new(code: :down))
    t.selected_row.should eq(0)
    t.on_key(Ori::Key.new(code: :up))
    t.selected_row.should eq(0)
  end

  it "move_top / move_bottom with no rows does not crash" do
    t = Ori::Table.new(rows: [] of Array(String))
    t.move_top
    t.move_bottom
  end
end

describe "List empty items edge cases" do
  it "navigation on empty list does not crash" do
    l = Ori::List.new(items: [] of Ori::List::Item, style: Ori::S.new(focusable: true))
    l.on_key(Ori::Key.new(code: :down))
    l.on_key(Ori::Key.new(code: :up))
    l.on_key(Ori::Key.new(text: "j"))
    l.on_key(Ori::Key.new(text: "k"))
    l.on_key(Ori::Key.new(code: :home))
    l.on_key(Ori::Key.new(code: :end))
    l.on_key(Ori::Key.new(code: :enter))
    l.on_key(Ori::Key.new(text: " "))
  end

  it "home/end on empty list does not crash" do
    l = Ori::List.new(items: [] of Ori::List::Item, style: Ori::S.new(focusable: true))
    l.on_key(Ori::Key.new(text: "g"))
    l.on_key(Ori::Key.new(text: "G"))
    l.cursor.should eq(0)
  end
end

describe "Viewport max_y_offset edge case" do
  it "zero-height viewport does not crash" do
    vp = Ori::Viewport.new(content: "line1\nline2")
    vp.rect = Ori::Rect.new(0, 0, 40, 0)
    vp.view_down
    vp.goto_bottom
    vp.y_offset.should be >= 0
  end

  it "very small viewport does not crash" do
    vp = Ori::Viewport.new(content: "hello\nworld\nfoo\nbar")
    vp.rect = Ori::Rect.new(0, 0, 40, 1)
    vp.view_down
    vp.goto_bottom
    vp.y_offset.should be >= 0
  end

  it "empty content zero height does not crash" do
    vp = Ori::Viewport.new(content: "")
    vp.rect = Ori::Rect.new(0, 0, 0, 0)
    vp.goto_bottom
    vp.view_down
  end
end

describe "Layout percentage truncation" do
  it "percentage children sum to available height" do
    a = Ori::Box.new([] of Ori::Node, Ori::S.new(height_pct: 33.0))
    b = Ori::Box.new([] of Ori::Node, Ori::S.new(height_pct: 33.0))
    c = Ori::Box.new([] of Ori::Node, Ori::S.new(height_pct: 34.0))
    root = Ori::Box.new([a, b, c] of Ori::Node)
    root.rect = Ori::Rect.new(0, 0, 40, 10)
    Ori::Layout.compute(root)
    total = a.rect.h + b.rect.h + c.rect.h
    total.should eq(10)
  end

  it "flex children fill remaining space" do
    a = Ori::Box.new([] of Ori::Node, Ori::S.new(height: 3))
    b = Ori::Box.new([] of Ori::Node, Ori::S.new(flex: 1))
    c = Ori::Box.new([] of Ori::Node, Ori::S.new(flex: 2))
    root = Ori::Box.new([a, b, c] of Ori::Node)
    root.rect = Ori::Rect.new(0, 0, 40, 10)
    Ori::Layout.compute(root)
    (b.rect.h + c.rect.h).should eq(7)
    b.rect.h.should be > 0
    c.rect.h.should be > 0
  end
end

describe "Screen wide char at edge" do
  it "wide char at last column renders without overflow" do
    screen = Ori::Screen.new(3, 3)
    screen.put(0, 0, 'A')
    screen.put(1, 0, 'B')
    screen.put(2, 0, '\u4e00')  # wide CJK at last column
  end

  it "wide char near edge does not leave orphan" do
    screen = Ori::Screen.new(3, 3)
    screen.put(2, 0, '\u4e00')
    screen.put(1, 0, '\u4e00')  # starts at col 1, needs cols 1-2
    screen.put(2, 0, ' ')  # should overwrite orphan
  end
end

describe "FilePicker" do
  it "creates without crash" do
    fp = Ori::FilePicker.new
    fp.files.is_a?(Array(Ori::FilePicker::Entry)).should be_true
  end

  it "navigates in current dir" do
    fp = Ori::FilePicker.new(current_dir: ".")
    entries_before = fp.files.size
    fp.on_key(Ori::Key.new(code: :down))
    fp.cursor.should eq({entries_before, 0}.max > 0 ? 1 : 0)
    fp.on_key(Ori::Key.new(code: :up))
    fp.cursor.should eq(0)
  end
end

describe "Paginator" do
  it "handles empty items" do
    pg = Ori::Paginator.new
    pg.set_total_pages(0)
    pg.total_pages.should eq(0)
  end

  it "handles single page" do
    pg = Ori::Paginator.new(per_page: 10)
    pg.set_total_pages(5)
    pg.total_pages.should eq(1)
  end

  it "navigates pages" do
    pg = Ori::Paginator.new(per_page: 10)
    pg.set_total_pages(50)
    pg.total_pages.should eq(5)
    pg.page.should eq(0)
    pg.next_page
    pg.page.should eq(1)
    pg.prev_page
    pg.page.should eq(0)
  end
end

describe "Help" do
  it "all render modes work" do
    bindings = [Ori::HelpBinding.new(["q"], "q", "quit")]
    h = Ori::Help.new(bindings: bindings, show_all: false)
    h.content_height.should be > 0
    h2 = Ori::Help.new(bindings: bindings, show_all: true)
    h2.content_height.should be > 0
  end

  it "HelpBinding enabled? works" do
    b = Ori::HelpBinding.new(["j"], "j", "down")
    b.enabled?.should be_true
    b = Ori::HelpBinding.new(["j"], "j", "down", disabled: true)
    b.enabled?.should be_false
  end
end
