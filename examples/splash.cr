require "../src/ori"

COLORS = [
  "#881177", "#aa3355", "#cc6666", "#ee9944",
  "#eedd00", "#99dd55", "#44dd88", "#22ccbb",
  "#00bbcc", "#0099cc", "#3366bb", "#663399",
]

PARSED_COLORS = COLORS.map do |c|
  h = c.lchop('#')
  {h[0..1].to_i(16), h[2..3].to_i(16), h[4..5].to_i(16)}
end

private def gradient_rgb(pos : Float64) : {Int32, Int32, Int32}
  pos = 0.0 if pos <= 0
  pos = 1.0 if pos >= 1
  idx = pos * (COLORS.size - 1)
  i1 = idx.floor.to_i % COLORS.size
  i2 = idx.ceil.to_i % COLORS.size
  t = idx - idx.floor
  r1, g1, b1 = PARSED_COLORS[i1]
  r2, g2, b2 = PARSED_COLORS[i2]
  {
    (r1 * (1 - t) + r2 * t).to_i,
    (g1 * (1 - t) + g2 * t).to_i,
    (b1 * (1 - t) + b2 * t).to_i,
  }
end

private def gradient(w : Int32, h : Int32, rate : Int64) : String
  t = Time.utc.to_unix_ns * rate / 1_000_000_000.0
  angle = -t * Math::PI / 180.0
  sin_a = Math.sin(angle)
  cos_a = Math.cos(angle)
  center_x = w.to_f / 2.0
  center_y = h.to_f

  s = IO::Memory.new(w * h * 2)
  h.times do |line_y|
    point_y = line_y.to_f * 2 - center_y
    point_x = 0.0 - center_x

    x1 = (center_x + (point_x * cos_a - point_y * sin_a)) / w.to_f
    x2 = (center_x + (point_x * cos_a - (point_y + 1.0) * sin_a)) / w.to_f
    point_x = w.to_f - center_x
    end_x1 = (center_x + (point_x * cos_a - point_y * sin_a)) / w.to_f
    delta_x = (end_x1 - x1) / w.to_f

    s << Ori::Term.move(0, line_y)
    w.times do |x|
      p1 = x1 + x.to_f * delta_x
      p2 = x2 + x.to_f * delta_x
      r1, g1, b1 = gradient_rgb(p1)
      r2, g2, b2 = gradient_rgb(p2)
      s << "\e[38;2;#{r1};#{g1};#{b1}m\e[48;2;#{r2};#{g2};#{b2}m▀"
    end
    s << "\e[0m"
  end
  s.to_s
end

unless STDIN.tty?
  STDERR.puts "splash: requires an interactive terminal"; exit 1
end

saved = Ori::Term.enter_raw
STDOUT << Ori::Term.enter_alt << Ori::Term.hide_cursor << Ori::Term.clear_screen
STDOUT.flush

rate = 90_i64
running = true
Signal::INT.trap { running = false }
Signal::TERM.trap { running = false }

STDIN.read_timeout = 16.milliseconds

while running
  w, h = Ori::Term.window_size
  STDOUT << gradient(w, h, rate)
  STDOUT.flush

  begin
    STDIN.read_byte
    running = false
  rescue IO::TimeoutError
  end
end

STDOUT << "\e[0m" << Ori::Term.show_cursor << Ori::Term.exit_alt
STDOUT.flush
Ori::Term.restore(saved)
