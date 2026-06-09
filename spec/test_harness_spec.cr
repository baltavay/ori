require "spec"
require "../src/ori"

describe Ori::TestHarness do
  describe "build and render" do
    it "renders text" do
      h = Ori::TestHarness.new(40, 5)
      h.build do
        text "Hello World"
      end
      h.frame
      h.line(0).should eq("Hello World                             ")
    end

    it "renders multiple lines of text" do
      h = Ori::TestHarness.new(40, 5)
      h.build do
        text "line1\nline2\nline3"
      end
      h.frame
      h.line(0).should eq("line1                                   ")
      h.line(1).should eq("line2                                   ")
      h.line(2).should eq("line3                                   ")
    end

    it "renders input with prefix" do
      h = Ori::TestHarness.new(40, 5)
      h.build do
        input focusable: true, value: "Ada"
      end
      h.frame
      h.line(0).should eq("▌Ada                                    ")
    end

    it "renders empty screen when no widgets" do
      h = Ori::TestHarness.new(10, 3)
      h.frame
      h.line(0).should eq("          ")
      h.line(1).should eq("          ")
      h.line(2).should eq("          ")
    end
  end

  describe "keyboard input" do
    it "types into input" do
      h = Ori::TestHarness.new(40, 5)
      h.build do
        input focusable: true
      end
      h.focus_first
      h.frame
      h.type("hi")
      h.frame
      h.line(0).should eq("▌hi                                     ")
    end

    it "backspace in input" do
      h = Ori::TestHarness.new(40, 5)
      h.build do
        input focusable: true, value: "hello"
      end
      h.focus_first
      h.frame
      3.times { h.key(:backspace) }
      h.frame
      h.line(0).should eq("▌he                                     ")
    end
  end

  describe "focus management" do
    it "tabs between inputs" do
      h = Ori::TestHarness.new(40, 5)
      first : Ori::InputNode? = nil
      second : Ori::InputNode? = nil
      h.build do
        first = input focusable: true, value: "first"
        second = input focusable: true, value: "second"
      end
      h.focus_first
      h.frame
      first.not_nil!.focused.should be_true
      second.not_nil!.focused.should be_false

      h.tab
      h.frame
      first.not_nil!.focused.should be_false
      second.not_nil!.focused.should be_true
    end

    it "tab wraps around" do
      h = Ori::TestHarness.new(40, 5)
      first : Ori::InputNode? = nil
      h.build do
        first = input focusable: true, value: "a"
        input focusable: true, value: "b"
      end
      h.focus_first
      h.tab
      h.tab
      h.frame
      first.not_nil!.focused.should be_true
    end

    it "types into the focused input" do
      h = Ori::TestHarness.new(40, 5)
      first : Ori::InputNode? = nil
      second : Ori::InputNode? = nil
      h.build do
        first = input focusable: true, value: "first"
        second = input focusable: true, value: "second"
      end
      h.focus_first
      h.tab
      h.type("X")
      h.frame
      first.not_nil!.value.should eq("first")
      second.not_nil!.value.should eq("secondX")
    end
  end

  describe "select dropdown" do
    it "opens and renders dropdown overlay" do
      h = Ori::TestHarness.new(40, 10)
      h.build do
        dropdown options: ["Red", "Green", "Blue"], focusable: true
      end
      h.focus_first
      h.frame
      h.key(:enter)
      h.frame
      h.include?("┌").should be_true
      h.include?("Red").should be_true
      h.include?("Green").should be_true
      h.include?("Blue").should be_true
      h.include?("└").should be_true
    end

    it "selects item from dropdown" do
      sel : Ori::Select? = nil
      h = Ori::TestHarness.new(40, 10)
      h.build do
        sel = dropdown options: ["A", "B", "C"], focusable: true
      end
      s = sel.not_nil!
      s.selected.should eq(0)
      h.focus_first
      h.key(:enter)
      h.key(:down)
      h.key(:down)
      h.key(:enter)
      h.frame
      s.open.should be_false
      s.selected.should eq(2)
    end

    it "fires on_change when selecting" do
      changes = [] of Int32
      h = Ori::TestHarness.new(40, 10)
      h.build do
        dropdown options: ["X", "Y", "Z"], focusable: true,
          on_change: ->(idx : Int32) { changes << idx; nil }
      end
      h.focus_first
      h.key(:enter)
      h.key(:down)
      h.key(:down)
      h.key(:enter)
      changes.should eq([2])
    end
  end

  describe "screen inspection" do
    it "char_at returns character at position" do
      h = Ori::TestHarness.new(40, 5)
      h.build do
        text "Hello"
      end
      h.frame
      h.char_at(0, 0).should eq('H')
      h.char_at(4, 0).should eq('o')
      h.char_at(5, 0).should eq(' ')
    end

    it "char_at returns space for out of bounds" do
      h = Ori::TestHarness.new(10, 3)
      h.char_at(-1, 0).should eq(' ')
      h.char_at(0, -1).should eq(' ')
      h.char_at(99, 0).should eq(' ')
    end

    it "text_at returns substring at position" do
      h = Ori::TestHarness.new(40, 5)
      h.build do
        text "Hello World"
      end
      h.frame
      h.text_at(0, 0, 5).should eq("Hello")
      h.text_at(6, 0, 5).should eq("World")
    end

    it "include? checks screen content" do
      h = Ori::TestHarness.new(40, 5)
      h.build do
        text "Hello World"
      end
      h.frame
      h.include?("Hello").should be_true
      h.include?("World").should be_true
      h.include?("Nope").should be_false
    end

    it "to_s returns full screen" do
      h = Ori::TestHarness.new(4, 2)
      h.build do
        text "ab\ncd"
      end
      h.frame
      h.text.should eq("ab  \ncd  ")
    end
  end

  describe "custom tree" do
    it "accepts pre-built widget tree" do
      h = Ori::TestHarness.new(40, 5)
      input = Ori::InputNode.new(value: "custom", style: Ori::S.new(focusable: true, border: true))
      input.rect = Ori::Rect.new(0, 0, 40, 1)
      h.root.add(input)
      h.layout
      h.focus_first
      h.frame
      h.line(0).should eq("▌custom                                 ")
      input.focused.should be_true
    end
  end
end
