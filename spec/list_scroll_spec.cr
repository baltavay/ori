require "./spec_helper"

describe "List scrolling" do
  it "keeps the viewport when rows are rebuilt" do
    items = (1..40).map { |i| Ori::List::Item.new("row #{i}") }
    list = Ori::List.new(items: items, style: Ori::S.new(focusable: true))
    list.rect = Ori::Rect.new(0, 0, 20, 10)
    25.times { list.on_key(Ori::Key.new(text: "j")) }
    offset = list.scroll_offset
    offset.should be > 0
    list.update(items, list.cursor)
    list.scroll_offset.should eq(offset)
    list.scroll_to(0)
    list.scroll_offset.should eq(0)
  end
end
