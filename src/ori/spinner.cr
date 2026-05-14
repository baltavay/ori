class Ori::Spinner < Ori::Node
  FRAMES = {
    dots:          ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"],
    line:          ["-", "\\", "|", "/"],
    arc:           ["◜", "◠", "◝", "◞", "◡", "◟"],
    circle:        ["◐", "◓", "◑", "◒"],
    pipe:          ["┤", "┘", "┴", "└", "├", "┌", "┬", "┐"],
    triangle:      ["◢", "◣", "◤", "◥"],
    bounce:        ["⠁", "⠂", "⠄", "⠂"],
    star:          ["✶", "✸", "✹", "✺", "✹", "✷"],
  }

  @frames : Array(String)
  @interval : Time::Span
  @start : Time::Instant

  def initialize(
    type : Symbol = :dots,
    style : Ori::S = Ori::S.none,
    interval : Time::Span = 0.1.seconds
  )
    super(style)
    @frames = FRAMES[type]? || FRAMES[:dots]
    @interval = interval
    @start = Time.instant
  end

  def content_height : Int32
    1
  end

  def content_width : Int32
    1
  end

  def frame : String
    elapsed = (Time.instant - @start).total_seconds
    idx = (elapsed / @interval.total_seconds).to_i % @frames.size
    @frames[idx]
  end

  def frame=(idx : Int32)
    @start = Time.instant - @interval * idx
  end

  def reset : Nil
    @start = Time.instant
  end

  def render_screen(screen : Ori::Screen) : Nil
    f = frame
    f.each_char do |ch|
      screen.put(@rect.x, @rect.y, ch, fg: @style.fg, bg: effective_bg)
    end
  end

  def render(io : IO) : Nil
    f = frame
    f = Ori::Color.apply(@style.fg, f) if @style.fg
    f = Ori::Color.apply_bg(effective_bg, f) if effective_bg
    io << Ori::Term.move(@rect.x, @rect.y) << f
  end
end
