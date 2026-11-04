require "../src/ori"

BG    = "#1e1e2e"; FG = "#cdd6f4"; DM = "#6c7086"
MAUVE = "#cba6f7"; GREEN = "#a6e3a1"; BLUE = "#89b4fa"
RED = "#f38ba8"; TEAL = "#94e2d5"; PINK = "#f5c2e7"; YELLOW = "#f9e2af"

class ProgressBarApp < Ori::App
  @pos = 0

  # The bars and labels are created once and `attach`ed each frame. Creating them
  # in `render` would hand back new objects on every rebuild, so anything set on
  # them once (the listing bar's max) would be lost to the next rebuild.
  @bar_solid : Ori::ProgressBar
  @bar_blocks : Ori::ProgressBar
  @bar_gradient : Ori::ProgressBar
  @bar_download : Ori::ProgressBar
  @bar_listing : Ori::ProgressBar
  @bar_indeterminate : Ori::ProgressBar
  @label_solid : Ori::TextNode
  @label_blocks : Ori::TextNode
  @label_gradient : Ori::TextNode
  @label_download : Ori::TextNode
  @label_listing : Ori::TextNode
  @label_indeterminate : Ori::TextNode

  def initialize
    @bar_solid = Ori::ProgressBar.new(style: Ori::S.new(fg: GREEN, bg: BG))
    @bar_blocks = Ori::ProgressBar.new(style: Ori::S.new(bar_style: :blocks, fg: BLUE, bg: BG))
    @bar_gradient = Ori::ProgressBar.new(style: Ori::S.new(bar_style: :gradient, fg: BLUE, bg: BG, gradient_to: PINK))
    @bar_download = Ori::ProgressBar.new(style: Ori::S.new(fg: TEAL, bg: BG))
    @bar_listing = Ori::ProgressBar.new(style: Ori::S.new(fg: YELLOW, bg: BG))
    @bar_indeterminate = Ori::ProgressBar.new(style: Ori::S.new(fg: RED, bg: BG, gradient_to: YELLOW))
    @label_solid = Ori::TextNode.new("")
    @label_blocks = Ori::TextNode.new("")
    @label_gradient = Ori::TextNode.new("")
    @label_download = Ori::TextNode.new("")
    @label_listing = Ori::TextNode.new("")
    @label_indeterminate = Ori::TextNode.new("")
  end

  def render : Ori::Box
    box bg: BG, padding: {1, 2} do
      text "ProgressBar Demo", fg: MAUVE, bold: true
      box padding: {1, 0} do
        text "Solid:", fg: DM
        attach @bar_solid
        attach @label_solid

        text "Blocks:", fg: DM
        attach @bar_blocks
        attach @label_blocks

        text "Gradient:", fg: DM
        attach @bar_gradient
        attach @label_gradient

        text "Download (known total):", fg: DM
        attach @bar_download
        attach @label_download

        text "Processing (list):", fg: DM
        attach @bar_listing
        attach @label_listing

        text "Indeterminate:", fg: DM
        attach @bar_indeterminate
        attach @label_indeterminate
      end
      text "q: quit", fg: DM
    end
  end

  def on_start : Nil
    @bar_listing.max = 1000_000_000
    spawn do
      (1..@bar_listing.max.to_i).each do
        @pos = @pos + 1
        Fiber.yield if @pos % 10_000 == 0
      end
    end

    spawn do
      while(@running)
        @bar_listing.value = @pos
        @label_listing.content = "#{@pos}"
        sleep 16.milliseconds
      end
    end

    start_tick(30.milliseconds) do
      bounce_demo
      download_demo
      indeterminate_demo
    end
  end

  @bounce_val = 0.0
  @bounce_dir = 1

  def bounce_demo
    @bounce_val += 1.0 * @bounce_dir
    if @bounce_val >= 100.0
      @bounce_val = 100.0
      @bounce_dir = -1
    elsif @bounce_val <= 0.0
      @bounce_val = 0.0
      @bounce_dir = 1
    end
    @bar_solid.value = @bounce_val
    @bar_blocks.value = @bounce_val
    @bar_gradient.value = @bounce_val
    @label_solid.content = "Solid #{@bounce_val.to_i}%"
    @label_blocks.content = "Blocks #{@bounce_val.to_i}%"
    @label_gradient.content = "Gradient #{@bounce_val.to_i}%"
  end

  @dl_total = 0.0
  @dl_downloaded = 0.0
  @dl_started = false

  def download_demo
    unless @dl_started
      @dl_total = 256.0
      @dl_downloaded = 0.0
      @dl_started = true
    end
    if @dl_downloaded < @dl_total
      @dl_downloaded = {@dl_downloaded + rand(1.0..8.0), @dl_total}.min
    end
    @bar_download.max = @dl_total
    @bar_download.value = @dl_downloaded
    mb = (@dl_downloaded / @dl_total * 100).to_i
    @label_download.content = "#{@dl_downloaded.to_i}/#{@dl_total.to_i} MB (#{mb}%)"
  end

  @indeterminate_t = 0.0

  def indeterminate_demo
    @indeterminate_t += 0.05
    v = (Math.sin(@indeterminate_t) * 50 + 50).clamp(0.0, 100.0)
    @bar_indeterminate.value = v
    @label_indeterminate.content = "#{v.to_i}%"
  end

  def on_key(key : Ori::Key) : Bool
    @running = false
    false
  end
end

ProgressBarApp.run
