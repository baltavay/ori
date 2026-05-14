struct Ori::HelpBinding
  getter keys : Array(String)
  getter help_key : String
  getter help_desc : String
  getter disabled : Bool

  def initialize(@keys : Array(String), @help_key : String, @help_desc : String, @disabled : Bool = false)
  end

  def enabled? : Bool
    !@disabled && !@keys.empty?
  end
end

class Ori::Help < Ori::Node
  @bindings : Array(Ori::HelpBinding)
  @show_all : Bool

  def initialize(
    bindings : Array(Ori::HelpBinding) = [] of Ori::HelpBinding,
    @show_all : Bool = false,
    style : Ori::S = Ori::S.none
  )
    super(style)
    @bindings = bindings
  end

  getter bindings : Array(Ori::HelpBinding)
  getter show_all : Bool

  def show_all=(v : Bool) : Nil
    @show_all = v
  end

  def content_height : Int32
    @show_all ? full_height : 1
  end

  def content_width : Int32
    @show_all ? full_width : short_width
  end

  def focusable? : Bool
    false
  end

  def render_screen(screen : Ori::Screen) : Nil
    r = @rect
    return if r.w <= 0 || r.h <= 0
    fg = @style.fg
    bg = effective_bg
    key_fg = "#89dceb"
    desc_fg = "#6c7086"

    if @show_all
      row = 0
      @bindings.each do |b|
        next unless b.enabled?
        break if row >= r.h
        cx = 0
        key_text = b.help_key.rjust(12)
        key_text.each_char do |ch|
          screen.put(r.x + cx, r.y + row, ch, fg: key_fg, bg: bg) if cx < r.w
          cx += 1
        end
        sep = "  "
        sep.each_char do |ch|
          screen.put(r.x + cx, r.y + row, ch, fg: desc_fg, bg: bg) if cx < r.w
          cx += 1
        end
        b.help_desc.each_char do |ch|
          screen.put(r.x + cx, r.y + row, ch, fg: fg, bg: bg) if cx < r.w
          cx += 1
        end
        row += 1
      end
    else
      cx = 0
      enabled = @bindings.select(&.enabled?)
      enabled.each_with_index do |b, i|
        break if cx >= r.w
        if i > 0
          screen.put(r.x + cx, r.y, '•', fg: desc_fg, bg: bg) if cx < r.w
          cx += 2
        end
        b.help_key.each_char do |ch|
          screen.put(r.x + cx, r.y, ch, fg: key_fg, bg: bg) if cx < r.w
          cx += 1
        end
        cx += 1
        b.help_desc.each_char do |ch|
          screen.put(r.x + cx, r.y, ch, fg: desc_fg, bg: bg) if cx < r.w
          cx += 1
        end
        cx += 1
      end
    end
  end

  def render(io : IO) : Nil
  end

  private def short_width : Int32
    enabled = @bindings.select(&.enabled?)
    return 0 if enabled.empty?
    enabled.map { |b| b.help_key.size + 1 + b.help_desc.size + 2 }.sum
  end

  private def full_width : Int32
    enabled = @bindings.select(&.enabled?)
    return 0 if enabled.empty?
    {enabled.map { |b| 14 + b.help_desc.size }.max, 20}.max
  end

  private def full_height : Int32
    @bindings.count(&.enabled?)
  end
end
