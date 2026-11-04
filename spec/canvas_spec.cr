require "./spec_helper"

describe Ori::Canvas do
  it "paints a half-covered cell as a half block" do
    canvas = Ori::Canvas.new(2, 1)
    canvas.clear("#000000")
    canvas.fill_rect(0.0, 0.0, 4.0, 1.0, "#ff0000") # top pixel row only
    screen = Ori::Screen.new(2, 1)
    canvas.blit(screen, 0, 0)

    cell = screen.back[0]
    cell.char.should eq('▀')
    cell.fg.should eq(0xff0000_u32)
    cell.bg.should eq(0x000000_u32)
  end

  it "resolves sub-cell positions that a one-glyph grid cannot express" do
    left = Ori::Canvas.new(1, 1)
    right = Ori::Canvas.new(1, 1)
    left.fill_rect(0.0, 0.0, 1.0, 2.0, "#ffffff")
    right.fill_rect(1.0, 0.0, 1.0, 2.0, "#ffffff")

    a = Ori::Screen.new(1, 1)
    b = Ori::Screen.new(1, 1)
    left.blit(a)
    right.blit(b)

    a.back[0].char.should eq('▌') # first pixel column
    b.back[0].char.should eq('▐') # second pixel column
  end

  it "collapses a fully covered cell to a blank with a background fill" do
    canvas = Ori::Canvas.new(1, 1)
    canvas.fill_rect(0.0, 0.0, 2.0, 2.0, "#00ff00")
    screen = Ori::Screen.new(1, 1)
    canvas.blit(screen)

    screen.back[0].char.should eq(' ')
    screen.back[0].bg.should eq(0x00ff00_u32)
  end

  it "leaves cells it never touched alone" do
    canvas = Ori::Canvas.new(2, 1)
    canvas.fill_rect(2.0, 0.0, 2.0, 2.0, "#ffffff")
    screen = Ori::Screen.new(2, 1)
    screen.put(0, 0, 'x', fg: "#123456")
    canvas.blit(screen)

    screen.back[0].char.should eq('x')
    screen.back[1].bg.should eq(0xffffff_u32)
  end

  it "paints every cell when cleared with a colour" do
    canvas = Ori::Canvas.new(3, 1)
    canvas.clear("#101010")
    screen = Ori::Screen.new(3, 1)
    canvas.blit(screen)

    screen.back.each { |c| c.bg.should eq(0x101010_u32) }
  end

  it "uses the fallback background for ink cells when transparent" do
    canvas = Ori::Canvas.new(1, 1)
    canvas.fill_rect(0.0, 0.0, 2.0, 1.0, "#ffffff")
    screen = Ori::Screen.new(1, 1)
    canvas.blit(screen, 0, 0, fallback_bg: "#202020")

    screen.back[0].char.should eq('▀')
    screen.back[0].bg.should eq(0x202020_u32)
  end

  it "keeps a mark drawn over a filled cell" do
    canvas = Ori::Canvas.new(1, 1)
    canvas.fill_rect(0.0, 0.0, 2.0, 2.0, "#ff0000") # whole cell
    canvas.plot(1, 0, "#0000ff")                    # one pixel on top
    screen = Ori::Screen.new(1, 1)
    canvas.blit(screen)

    screen.back[0].char.should eq('▝')
    screen.back[0].fg.should eq(0x0000ff_u32)
    screen.back[0].bg.should eq(0xff0000_u32)
  end

  it "supports half-block and plain grids" do
    half = Ori::Canvas.new(1, 1, 1, 2)
    half.fill_rect(0.0, 1.0, 1.0, 1.0, "#ffffff")
    plain = Ori::Canvas.new(1, 1, 1, 1)
    plain.fill_rect(0.0, 0.0, 1.0, 1.0, "#ffffff")
    screen = Ori::Screen.new(2, 1)

    half.blit(screen, 0, 0)
    plain.blit(screen, 1, 0)

    screen.back[0].char.should eq('▄')
    screen.back[1].char.should eq(' ')
    screen.back[1].bg.should eq(0xffffff_u32)
    half.subcell?.should be_true
  end

  it "draws a bitmap one character per sub-cell" do
    canvas = Ori::Canvas.new(1, 1)
    canvas.bitmap(0, 0, ["#.", ".#"], "#ffffff")
    screen = Ori::Screen.new(1, 1)
    canvas.blit(screen)

    screen.back[0].char.should eq('▚')
  end

  it "clips to the screen" do
    canvas = Ori::Canvas.new(4, 4)
    canvas.fill_rect(0.0, 0.0, 8.0, 8.0, "#ffffff")
    screen = Ori::Screen.new(2, 2)
    canvas.blit(screen, 1, 1)

    screen.back[0].bg.should eq(Ori::Screen::Cell::NO_COLOR)
    screen.back[3].bg.should eq(0xffffff_u32)
  end

  it "rejects a sub-cell grid it has no characters for" do
    expect_raises(ArgumentError) { Ori::Canvas.new(1, 1, 3, 2) }
  end
end

describe "canvas text layer" do
  it "draws characters over the pixels" do
    canvas = Ori::Canvas.new(4, 1)
    canvas.fill_rect(0.0, 0.0, 8.0, 2.0, "#101010")
    canvas.text(1, 0, "hi", "#ffffff")
    screen = Ori::Screen.new(4, 1)
    canvas.blit(screen)

    screen.back[1].char.should eq('h')
    screen.back[1].fg.should eq(0xffffff_u32)
    screen.back[2].char.should eq('i')
  end

  it "keeps the colour painted under a character" do
    canvas = Ori::Canvas.new(2, 1)
    canvas.fill_rect(0.0, 0.0, 4.0, 2.0, "#ff0000")
    canvas.text(0, 0, "X", "#ffffff")
    screen = Ori::Screen.new(2, 1)
    canvas.blit(screen)

    screen.back[0].char.should eq('X')
    screen.back[0].bg.should eq(0xff0000_u32)
  end

  it "drops characters on clear" do
    canvas = Ori::Canvas.new(2, 1)
    canvas.text(0, 0, "AB", "#ffffff")
    canvas.clear
    screen = Ori::Screen.new(2, 1)
    canvas.blit(screen)

    screen.back[0].char.should eq(' ')
  end

  it "carries bold through to the cell" do
    canvas = Ori::Canvas.new(2, 1)
    canvas.text(0, 0, "hi", "#ffffff", bold: true)
    screen = Ori::Screen.new(2, 1)
    canvas.blit(screen)

    screen.back[0].bold.should be_true
  end
end

describe Ori::CanvasNode do
  it "sizes the canvas to its rectangle and redraws it each frame" do
    node = Ori::CanvasNode.new(2, 2) do |c|
      c.fill_rect(0.0, 0.0, 4.0, 1.0, "#ff0000")
    end
    node.rect = Ori::Rect.new(1, 1, 3, 2)
    screen = Ori::Screen.new(6, 4)
    node.render_screen(screen)

    node.canvas.px_w.should eq(6)
    screen.back[1 * 6 + 1].char.should eq('▀')
    screen.back[1 * 6 + 1].fg.should eq(0xff0000_u32)
    screen.back[2 * 6 + 1].bg.should eq(Ori::Screen::Cell::NO_COLOR)
  end
end

describe "canvas inside a box tree" do
  it "is added as a child like any other widget" do
    node = Ori::Box.new
    added = node.canvas(width: 4, height: 2) { |c| c.clear(0x00ff00_u32) }
    node.children.should eq([added] of Ori::Node)

    node.rect = Ori::Rect.new(0, 0, 10, 5)
    node.layout
    screen = Ori::Screen.new(10, 5)
    node.render_screen(screen)

    added.rect.w.should eq(4)
    screen.back[0].bg.should eq(0x00ff00_u32)
  end
end
