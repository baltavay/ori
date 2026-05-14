require "../src/ori"

unless STDIN.tty?
  STDERR.puts "bounce: requires an interactive terminal"; exit 1
end

saved = Ori::Term.enter_raw
STDOUT << Ori::Term.enter_alt << Ori::Term.hide_cursor << Ori::Term.clear_screen
STDOUT.flush

box_w = 20
box_h = 10
x = 5.0
y = 5.0
vx = 30.0
vy = 20.0

screen = Ori::Screen.new

running = true
Signal::INT.trap { running = false }
Signal::TERM.trap { running = false }
STDIN.read_timeout = 16.milliseconds

last = Time.instant

while running
  now = Time.instant
  dt = (now - last).total_seconds
  last = now
  dt = 0.016 if dt > 0.1

  w, h = Ori::Term.window_size
  screen.resize(w, h)
  screen.clear

  x += vx * dt
  y += vy * dt

  if x <= 0
    x = 0.0; vx = vx.abs
  elsif x + box_w >= w
    x = (w - box_w).to_f; vx = -vx.abs
  end

  if y <= 0
    y = 0.0; vy = vy.abs
  elsif y + box_h >= h
    y = (h - box_h).to_f; vy = -vy.abs
  end

  ix = x.round.to_i
  iy = y.round.to_i

  screen.write(ix, iy, "┌", fg: "#cba6f7")
  (1...box_w - 1).each { |i| screen.put(ix + i, iy, '─', fg: "#cba6f7") }
  screen.put(ix + box_w - 1, iy, '┐', fg: "#cba6f7")

  (1...box_h - 1).each do |row|
    screen.put(ix, iy + row, '│', fg: "#cba6f7")
    (1...box_w - 1).each { |col| screen.put(ix + col, iy + row, ' ', bg: "#313244") }
    screen.put(ix + box_w - 1, iy + row, '│', fg: "#cba6f7")
  end

  screen.put(ix, iy + box_h - 1, '└', fg: "#cba6f7")
  (1...box_w - 1).each { |i| screen.put(ix + i, iy + box_h - 1, '─', fg: "#cba6f7") }
  screen.put(ix + box_w - 1, iy + box_h - 1, '┘', fg: "#cba6f7")

  screen.write(ix + 3, iy + 3, "DVD", fg: "#cdd6f4", bold: true)
  screen.write(ix + 3, iy + 5, "    VIDEO", fg: "#6c7086")

  screen.write(0, h - 1, " Press any key to quit", fg: "#6c7086")

  screen.flush(STDOUT)

  begin
    byte = STDIN.read_byte
    running = false if byte
  rescue IO::TimeoutError
  end
end

STDOUT << "\e[0m" << Ori::Term.show_cursor << Ori::Term.exit_alt
STDOUT.flush
Ori::Term.restore(saved)
