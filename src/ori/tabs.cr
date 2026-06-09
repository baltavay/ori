class Ori::Tabs < Ori::Node
  @tabs : Array(String)
  @active : Int32
  @on_change : Proc(Int32, Nil)?

  def initialize(
    @tabs : Array(String) = [] of String,
    active : Int32 = 0,
    @on_change : Proc(Int32, Nil)? = nil,
    style : Ori::S = Ori::S.none
  )
    super(style)
    @active = active.clamp(0, {@tabs.size - 1, 0}.max)
  end

  getter tabs : Array(String)
  getter active : Int32
  getter active_label : String?
  def active=(idx : Int32)
    @active = idx.clamp(0, {@tabs.size - 1, 0}.max)
  end

  def content_height : Int32
    1
  end

  def content_width : Int32
    return 5 if @tabs.empty?
    @tabs.sum(&.size) + (@tabs.size - 1) * 3 + 2
  end

  def focusable? : Bool
    @style.focusable
  end

  def on_key(key : Ori::Key) : Bool
    case
    when key.code.left? || key.text == "h"
      if @active > 0
        @active -= 1
        @on_change.try(&.call(@active))
      end
      true
    when key.code.right? || key.text == "l"
      if @active < @tabs.size - 1
        @active += 1
        @on_change.try(&.call(@active))
      end
      true
    when key.code.home? || key.text == "g"
      @active = 0
      @on_change.try(&.call(@active))
      true
    when key.code.end? || key.text == "G"
      @active = @tabs.size - 1
      @on_change.try(&.call(@active))
      true
    else
      false
    end
  end

  def on_mouse(mouse : Ori::Mouse) : Bool
    if mouse.press? && mouse.in?(@rect)
      cx = @rect.x
      @tabs.each_with_index do |tab, i|
        label = tab_label(tab, i)
        after = cx + label.size
        if mouse.x >= cx && mouse.x < after
          if i != @active
            @active = i
            @on_change.try(&.call(@active))
          end
          return true
        end
        cx = after
      end
    end
    false
  end

  def render_screen(screen : Ori::Screen) : Nil
    r = @rect
    return if r.w <= 0 || r.h <= 0

    bg = effective_bg
    fg = @style.fg || "#cdd6f4"
    active_fg = "#1e1e2e"
    active_bg = "#cba6f7"

    cx = r.x
    @tabs.each_with_index do |tab, i|
      is_active = i == @active
      label = tab_label(tab, i)
      is_active ? screen.write(cx, r.y, label, fg: active_fg, bg: active_bg, bold: true) :
                  screen.write(cx, r.y, label, fg: fg, bg: bg)
      cx += label.size
    end

    (cx...r.x + r.w).each { |ci| screen.put(ci, r.y, ' ', bg: bg) }
  end

  def render(io : IO) : Nil
    r = @rect
    return if r.w <= 0

    bg = effective_bg
    fg = @style.fg || "#cdd6f4"
    active_fg = "#1e1e2e"
    active_bg = "#cba6f7"

    cx = r.x
    @tabs.each_with_index do |tab, i|
      is_active = i == @active
      label = tab_label(tab, i)
      res = Ori::Color.apply(is_active ? active_fg : fg, label)
      res = Ori::Color.apply_bg(is_active ? active_bg : bg, res)
      res = "\e[1m#{res}" if is_active
      io << Ori::Term.move(cx, r.y) << res
      cx += label.size
    end
  end

  private def tab_label(tab : String, idx : Int32) : String
    " #{tab} "
  end
end
