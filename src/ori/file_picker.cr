class Ori::FilePicker < Ori::Node
  struct Entry
    getter name : String
    getter path : String
    getter directory : Bool
    getter size : Int64
    getter hidden : Bool

    def initialize(@name, @path, @directory, @size = 0_i64, @hidden = false)
    end
  end

  @current_dir : String
  @files : Array(Entry)
  @cursor : Int32
  @scroll_offset : Int32
  @selected_file : String?
  @err : Exception?
  @allowed_types : Array(String)
  @show_hidden : Bool
  @on_select : Proc(String, Nil)?

  def initialize(
    current_dir : String = Dir.current,
    @allowed_types : Array(String) = [] of String,
    @show_hidden : Bool = false,
    @on_select : Proc(String, Nil)? = nil,
    style : Ori::S = Ori::S.none
  )
    super(style)
    @current_dir = File.expand_path(current_dir)
    @files = [] of Entry
    @cursor = 0
    @scroll_offset = 0
    @selected_file = nil
    @err = nil
    scan_dir
  end

  getter current_dir : String
  getter selected_file : String?
  getter files : Array(Entry)
  getter cursor : Int32

  def did_select? : Bool
    !@selected_file.nil?
  end

  def content_height : Int32
    {@files.size, 1}.max
  end

  def content_width : Int32
    {@files.map(&.name.size).max + 4, 20}.max
  end

  def focusable? : Bool
    true
  end

  def current_dir=(dir : String) : Nil
    @current_dir = File.expand_path(dir)
    @cursor = 0
    @scroll_offset = 0
    @selected_file = nil
    scan_dir
  end

  def on_key(key : Ori::Key) : Bool
    case
    when key.code.up? || key.text == "k"
      @cursor -= 1 if @cursor > 0
      adjust_scroll
      true
    when key.code.down? || key.text == "j"
      @cursor += 1 if @cursor < @files.size - 1
      adjust_scroll
      true
    when key.code.home? || key.text == "g"
      @cursor = 0
      adjust_scroll
      true
    when key.code.end? || key.text == "G"
      @cursor = {@files.size - 1, 0}.max
      adjust_scroll
      true
    when key.code.enter?
      select_current
      true
    when key.code.backspace? || key.text == "h"
      go_up
      true
    else
      false
    end
  end

  def on_mouse(mouse : Ori::Mouse) : Bool
    case mouse.action
    when Ori::Mouse::Action::Press
      r = @rect
      rel_y = mouse.y - r.y
      idx = @scroll_offset + rel_y
      if idx >= 0 && idx < @files.size
        @cursor = idx
        select_current
      end
      true
    when Ori::Mouse::Action::Wheel
      if mouse.button.wheel_up?
        @cursor -= 1 if @cursor > 0
      elsif mouse.button.wheel_down?
        @cursor += 1 if @cursor < @files.size - 1
      end
      adjust_scroll
      true
    else
      false
    end
  end

  def render_screen(screen : Ori::Screen) : Nil
    r = @rect
    return if r.w <= 0 || r.h <= 0
    fg = @style.fg
    bg = effective_bg
    dir_fg = "#89b4fa"
    sel_fg = "#1e1e2e"
    sel_bg = "#cba6f7"
    err_fg = "#f38ba8"

    if e = @err
      msg = "Error: #{e.message}"
      msg.each_char_with_index do |ch, ci|
        screen.put(r.x + ci, r.y, ch, fg: err_fg, bg: bg) if ci < r.w
      end
      return
    end

    header = @current_dir
    header.each_char_with_index do |ch, ci|
      screen.put(r.x + ci, r.y, ch, fg: "#cba6f7", bg: bg, bold: true) if ci < r.w
    end

    visible = r.h - 1
    return if visible <= 0

    visible.times do |i|
      idx = @scroll_offset + i
      ry = r.y + 1 + i
      break if ry >= r.y + r.h

      if idx < @files.size
        entry = @files[idx]
        prefix = entry.directory ? "📁 " : "   "
        label = "#{prefix}#{entry.name}"
        is_selected = idx == @cursor
        label_fg = is_selected ? sel_fg : (entry.directory ? dir_fg : fg)
        label_bg = is_selected ? sel_bg : bg

        label.each_char_with_index do |ch, ci|
          screen.put(r.x + ci, ry, ch, fg: label_fg, bg: label_bg, bold: is_selected) if ci < r.w
        end
        label.size.upto(r.w - 1) do |ci|
          screen.put(r.x + ci, ry, ' ', fg: label_fg, bg: label_bg)
        end
      else
        r.w.times do |ci|
          screen.put(r.x + ci, ry, ' ', bg: bg)
        end
      end
    end
  end

  def render(io : IO) : Nil
  end

  private def scan_dir : Nil
    @files = [] of Entry
    @err = nil
    begin
      entries = Dir.entries(@current_dir)
      dirs = [] of Entry
      files = [] of Entry
      entries.sort_by!(&.downcase)
      entries.each do |name|
        next if name == "."
        next if name.starts_with?('.') && !@show_hidden
        path = File.join(@current_dir, name)
        is_dir = File.directory?(path)
        hidden = name.starts_with?('.')
        size = File.info?(path).try(&.size) || 0_i64
        entry = Entry.new(name, path, is_dir, size, hidden)
        if is_dir
          dirs << entry
        else
          next unless @allowed_types.empty? || @allowed_types.any? { |ext| name.ends_with?(ext) }
          files << entry
        end
      end
      @files = dirs + files
    rescue ex : Exception
      @err = ex
    end
  end

  private def select_current : Nil
    return if @cursor >= @files.size
    entry = @files[@cursor]
    if entry.directory
      self.current_dir = entry.path
    elsif @allowed_types.empty? || @allowed_types.any? { |ext| entry.name.ends_with?(ext) }
      @selected_file = entry.path
      @on_select.try(&.call(entry.path))
    end
  end

  private def go_up : Nil
    parent = File.dirname(@current_dir)
    self.current_dir = parent if parent != @current_dir
  end

  private def adjust_scroll : Nil
    vh = {@rect.h - 1, 1}.max
    if @cursor < @scroll_offset
      @scroll_offset = @cursor
    elsif @cursor >= @scroll_offset + vh
      @scroll_offset = @cursor - vh + 1
    end
  end
end
