require "./spec_helper"

# The image layer: fitting a picture into a cell box, the placement a node records,
# and the repaint sixel needs because it has no delete escape.
describe Ori::Graphics do
  describe "#cell_box" do
    it "fills the width for a wide image" do
      graphics = Ori::Graphics.new(IO::Memory.new)
      graphics.configure({8, 16}, nil)
      graphics.cell_box(1600, 900, 40, 20).should eq({40, 11})
    end

    it "fills the height for a tall image" do
      graphics = Ori::Graphics.new(IO::Memory.new)
      graphics.configure({8, 16}, nil)
      graphics.cell_box(900, 1600, 40, 10).should eq({11, 10})
    end

    it "never returns a zero-sized box" do
      graphics = Ori::Graphics.new(IO::Memory.new)
      graphics.configure({8, 16}, nil)
      graphics.cell_box(0, 0, 10, 10).should eq({1, 1})
      graphics.cell_box(100, 100, 0, 10).should eq({1, 1})
    end

    it "respects a cell that is not 1:2" do
      graphics = Ori::Graphics.new(IO::Memory.new)
      graphics.configure({10, 20}, nil)
      cols, rows = graphics.cell_box(1000, 500, 30, 30)
      # 30 cols wide, cells are 10x20 px => 30*10 / (rows*20) == 1000/500
      (cols * 10.0 / (rows * 20.0)).should be_close(2.0, 0.35)
    end
  end

  it "has no backend without a probe or an override" do
    previous = ENV["ORI_IMAGES"]?
    ENV.delete("ORI_IMAGES")
    begin
      graphics = Ori::Graphics.new(IO::Memory.new)
      graphics.configure({8, 16}, nil)
      graphics.backend.none?.should be_true
    ensure
      ENV["ORI_IMAGES"] = previous if previous
    end
  end
end

describe Ori::Screen do
  it "records the images a frame wants placed, and forgets them on clear" do
    screen = Ori::Screen.new(20, 10)
    screen.clear
    screen.place_image(2, 3, 8, 4, "/tmp/a.png", 300, 200)
    screen.images.size.should eq(1)
    placement = screen.images.first
    placement.x.should eq(2)
    placement.y.should eq(3)
    placement.cols.should eq(8)
    placement.width.should eq(300)
    screen.clear
    screen.images.should be_empty
  end

  it "repaints a rectangle from the cells on screen" do
    screen = Ori::Screen.new(6, 3)
    screen.clear
    screen.write(1, 1, "ab", fg: "#ffffff", bg: "#000000")
    io = IO::Memory.new
    screen.repaint_rect(io, 1, 1, 2, 1)
    output = io.to_s
    # One cell per write (the SGR changes between them), so both cursor moves are
    # the assertion.
    output.should contain("\e[2;2H")
    output.should contain("\e[2;3H")
    output.should contain("a")
  end
end

describe Ori::ImageNode do
  it "paints its box and registers the picture" do
    path = File.join(Dir.tempdir, "ori-image-#{Process.pid}.png")
    # 4x2 PNG header is all the node reads.
    header = Bytes[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 13] + "IHDR".to_slice +
             Bytes[0, 0, 0, 4, 0, 0, 0, 2] + Bytes.new(4)
    File.write(path, header)
    begin
      screen = Ori::Screen.new(20, 10)
      screen.clear
      node = Ori::ImageNode.new(path, Ori::S.new(bg: "#101010", width: 8, height: 4))
      node.rect = Ori::Rect.new(1, 2, 8, 4)
      node.render_screen(screen)
      screen.images.size.should eq(1)
      screen.images.first.width.should eq(4)
      screen.images.first.height.should eq(2)
      screen.images.first.x.should eq(1)
    ensure
      File.delete(path) if File.exists?(path)
    end
  end
end
