require "../src/ori"

BG = "#1e1e2e"; FG = "#cdd6f4"; DM = "#6c7086"; MAUVE = "#cba6f7"
GREEN = "#a6e3a1"; RED = "#f38ba8"; YELLOW = "#f9e2af"; BLUE = "#89b4fa"

class TimerApp < Ori::App
  @time_display : Ori::TextNode
  @status : Ori::TextNode
  @mode : Symbol = :timer
  @total = 300.0
  @remaining = 300.0
  @running_timer = false
  @last_tick : Time::Instant?
  @done = false

  def initialize
    @time_display = Ori::TextNode.new("05:00.0", style: Ori::S.new(fg: FG, bold: true, align: :center))
    @status = Ori::TextNode.new("press s to start", style: Ori::S.new(fg: DM, align: :center))
  end

  def render : Ori::Box
    box bg: BG, padding: {2, 4}, direction: :vertical do
      text "Timer", fg: MAUVE, bold: true, align: :center
      text ""
      text "───────────────────", fg: DM, align: :center
      text ""
      add @time_display
      add @status
      text ""
      text "───────────────────", fg: DM, align: :center
      text ""
      text "s:start/stop  r:reset  +/-:time  q:quit", fg: DM, align: :center
    end
  end

  def on_start
    start_tick(50.milliseconds) do
      if @running_timer
        now = Time.instant
        if last = @last_tick
          dt = (now - last).total_seconds
          @remaining -= dt
          if @remaining <= 0
            @remaining = 0.0
            @running_timer = false
            @done = true
            @status.content = "  time's up!  "
          end
        end
        @last_tick = now
      end
      @time_display.content = format_time(@remaining) + (@done ? "  DONE" : "")
    end
  end

  def on_key(key : Ori::Key) : Bool
    case key.text
    when "q"
      @running = false
    when "s"
      if @running_timer
        @running_timer = false
        @last_tick = nil
        @status.content = "  paused  "
      else
        if @remaining <= 0
          @remaining = @total
          @done = false
        end
        @running_timer = true
        @last_tick = Time.instant
        @status.content = "  running  "
      end
    when "r"
      @running_timer = false
      @last_tick = nil
      @remaining = @total
      @done = false
      @status.content = "  reset  "
    when "+"
      @total = {@total + 30, 3600}.min
      @remaining = @total unless @running_timer
      @status.content = "  +30s → #{format_time(@total)}  "
    when "-"
      @total = {@total - 30, 30}.max
      @remaining = @total unless @running_timer
      @status.content = "  -30s → #{format_time(@total)}  "
    end
    true
  end

  private def format_time(seconds) : String
    s = seconds.clamp(0.0, 999999.0)
    m = (s / 60).to_i
    sec = (s % 60)
    sprintf("%02d:%05.2f", m, sec)
  end
end

TimerApp.run
