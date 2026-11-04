require "../src/ori"

BG = "#1e1e2e"; DM = "#6c7086"; MAUVE = "#cba6f7"; GREEN = "#a6e3a1"
BLUE = "#89b4fa"; PINK = "#f5c2e7"

class SpringApp < Ori::App
  @pos_h = 50.0; @vel_h = 0.0; @target_h = 50.0
  @pos_v = 50.0; @vel_v = 0.0; @target_v = 50.0
  @clock = Ori::Spring::Clock.new
  @bar_h : Ori::ProgressBar; @bar_v : Ori::ProgressBar
  @h_label : Ori::TextNode; @v_label : Ori::TextNode

  def initialize
    @bar_h = Ori::ProgressBar.new(style: Ori::S.new(bar_style: :blocks, fg: BLUE, bg: BG))
    @bar_v = Ori::ProgressBar.new(style: Ori::S.new(bar_style: :gradient, fg: BLUE, bg: BG, gradient_to: PINK))
    @h_label = Ori::TextNode.new(""); @v_label = Ori::TextNode.new("")
  end

  def on_start : Nil
    start_tick_with_elapsed(16.milliseconds) do |dt|
      schedule = @clock.take(dt)
      @pos_h, @vel_h = Ori::Spring.apply(schedule, @pos_h, @vel_h, @target_h, 5.0, 0.5)
      @pos_v, @vel_v = Ori::Spring.apply(schedule, @pos_v, @vel_v, @target_v, 3.0, 0.15)
      @bar_h.value = @pos_h.clamp(0.0, 100.0); @bar_v.value = @pos_v.clamp(0.0, 100.0)
      @h_label.content = "Spring 1 (damping 0.5): #{@pos_h.round(1)}%  vel: #{@vel_h.round(2)}"
      @v_label.content = "Spring 2 (damping 0.15): #{@pos_v.round(1)}%  vel: #{@vel_v.round(2)}"
    end
  end

  def render : Ori::Box
    box bg: BG, padding: {1, 2} do
      text "Spring Animation", fg: MAUVE, bold: true
      text "l/h: move target 1  k/j: move target 2  ctrl+c: quit", fg: DM
      box padding: {1, 0} do; attach @bar_h; attach @h_label; attach @bar_v; attach @v_label; end
      text "Target 1 (damping 0.5): #{@target_h.round}%", fg: DM
      text "Target 2 (damping 0.15): #{@target_v.round}%", fg: DM
    end
  end

  def on_key(key : Ori::Key) : Bool
    case key.text
    when "q" then @running = false; true
    when "l" then @target_h = {[@target_h+20.0,100.0].min,0.0}.max; true
    when "h" then @target_h = {[@target_h-20.0,100.0].min,0.0}.max; true
    when "j" then @target_v = {[@target_v-20.0,100.0].min,0.0}.max; true
    when "k" then @target_v = {[@target_v+20.0,100.0].min,0.0}.max; true
    else false
    end
  end
end
SpringApp.run
