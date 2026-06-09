require "../src/ori"

BG = "#1e1e2e"; FG = "#cdd6f4"; DM = "#6c7086"; MAUVE = "#cba6f7"
GREEN = "#a6e3a1"; RED = "#f38ba8"; YELLOW = "#f9e2af"; BLUE = "#89b4fa"
TEAL = "#94e2d5"

class StopwatchApp < Ori::App
  @time_display : Ori::TextNode
  @status : Ori::TextNode
  @laps : Array(String)
  @lap_list : Ori::TextNode
  @elapsed = 0.0
  @running_sw = false
  @last_tick : Time::Instant?
  @lap_count = 0
  @last_lap = 0.0

  def initialize
    @laps = [] of String
    @time_display = Ori::TextNode.new("00:00.00", style: Ori::S.new(fg: FG, bold: true, align: :center))
    @status = Ori::TextNode.new("press s to start", style: Ori::S.new(fg: DM, align: :center))
    @lap_list = Ori::TextNode.new("", style: Ori::S.new(fg: DM))
  end

  def render : Ori::Box
    box bg: BG, padding: {2, 4}, direction: :vertical do
      text "Stopwatch", fg: MAUVE, bold: true, align: :center
      text ""
      text "───────────────────", fg: DM, align: :center
      text ""
      add @time_display
      add @status
      text ""
      text "───────────────────", fg: DM, align: :center
      text ""
      text "s:start/stop  l:lap  r:reset  q:quit", fg: DM, align: :center
      text ""
      add @lap_list
    end
  end

  def on_start
    start_tick(30.milliseconds) do
      if @running_sw
        now = Time.instant
        if last = @last_tick
          @elapsed += (now - last).total_seconds
        end
        @last_tick = now
      end
      @time_display.content = format_time(@elapsed)
    end
  end

  def on_key(key : Ori::Key) : Bool
    case key.text
    when "q"
      @running = false
    when "s"
      if @running_sw
        @running_sw = false
        @last_tick = nil
        @status.content = "  stopped at #{format_time(@elapsed)}  "
      else
        @running_sw = true
        @last_tick = Time.instant
        @status.content = "  running  "
      end
    when "l"
      if @running_sw
        @lap_count += 1
        lap_time = @elapsed - @last_lap
        @laps.unshift("lap #{@lap_count}: #{format_time(lap_time)} (total: #{format_time(@elapsed)})")
        @last_lap = @elapsed
        @lap_list.content = @laps.first(8).join("\n")
      end
    when "r"
      @running_sw = false
      @last_tick = nil
      @elapsed = 0.0
      @lap_count = 0
      @last_lap = 0.0
      @laps.clear
      @lap_list.content = ""
      @status.content = "  reset  "
    end
    true
  end

  private def format_time(seconds : Float64) : String
    s = seconds.clamp(0.0, 999999.0)
    m = (s / 60).to_i
    sec = (s % 60)
    sprintf("%02d:%05.2f", m, sec)
  end
end

StopwatchApp.run
