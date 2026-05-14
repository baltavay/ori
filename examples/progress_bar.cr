require "../src/ori"

BG    = "#1e1e2e"; FG = "#cdd6f4"; DM = "#6c7086"
MAUVE = "#cba6f7"; GREEN = "#a6e3a1"; BLUE = "#89b4fa"
RED = "#f38ba8"; TEAL = "#94e2d5"; PINK = "#f5c2e7"; YELLOW = "#f9e2af"

class ProgressBarApp < Ori::App
  @bars = [] of Ori::ProgressBar
  @labels = [] of Ori::TextNode
  @pos = 0

  def render : Ori::Box
    @bars.clear
    @labels.clear
    box bg: BG, padding: {1, 2} do
      text "ProgressBar Demo", fg: MAUVE, bold: true
      box padding: {1, 0} do
        text "Solid:", fg: DM
        @bars << progress_bar(fg: GREEN, bg: BG)
        @labels << text ""

        text "Blocks:", fg: DM
        @bars << progress_bar(bar_style: :blocks, fg: BLUE, bg: BG)
        @labels << text ""

        text "Gradient:", fg: DM
        @bars << progress_bar(bar_style: :gradient, fg: BLUE, bg: BG, gradient_to: PINK)
        @labels << text ""

        text "Download (known total):", fg: DM
        @bars << progress_bar(fg: TEAL, bg: BG)
        @labels << text ""

        text "Processing (list):", fg: DM
        @bars << progress_bar(fg: YELLOW, bg: BG)
        @labels << text ""

        text "Indeterminate:", fg: DM
        @bars << progress_bar(fg: RED, bg: BG, gradient_to: YELLOW)
        @labels << text ""
      end
      text "q: quit", fg: DM
    end
  end

  def on_start : Nil
    @bars[4].max = 1000_000_000
    spawn do
      (1..@bars[4].max.to_i).each do
        @pos = @pos + 1
        Fiber.yield if @pos % 10_000 == 0
      end
    end

    spawn do
      while(@running)
        @bars[4].value = @pos 
        @labels[4].content = "#{@pos}"
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
    @bars[0].value = @bounce_val
    @bars[1].value = @bounce_val
    @bars[2].value = @bounce_val
    @labels[0].content = "Solid #{@bounce_val.to_i}%"
    @labels[1].content = "Blocks #{@bounce_val.to_i}%"
    @labels[2].content = "Gradient #{@bounce_val.to_i}%"
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
    @bars[3].max = @dl_total
    @bars[3].value = @dl_downloaded
    mb = (@dl_downloaded / @dl_total * 100).to_i
    @labels[3].content = "#{@dl_downloaded.to_i}/#{@dl_total.to_i} MB (#{mb}%)"
  end

  @proc_items = 0
  @proc_total = 500
  @proc_started = false

  @indeterminate_t = 0.0

  def indeterminate_demo
    @indeterminate_t += 0.05
    v = (Math.sin(@indeterminate_t) * 50 + 50).clamp(0.0, 100.0)
    @bars[5].value = v
    @labels[5].content = "#{v.to_i}%"
  end

  def handle_key(key : Ori::Key) : Bool
    @running = false
    false
  end
end

ProgressBarApp.run
