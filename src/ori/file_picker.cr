class Ori::FilePicker < Ori::Node
  enum SortMode
    Name
    Date
    Size
  end

  struct Entry
    getter name : String
    getter path : String
    getter directory : Bool
    getter size : Int64
    getter hidden : Bool
    getter mtime : Time?

    def initialize(@name, @path, @directory, @size = 0_i64, @hidden = false, @mtime = nil)
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
  @sort_mode : SortMode

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
    @sort_mode = SortMode::Name
    scan_dir
  end

  getter current_dir : String
  getter selected_file : String?
  getter files : Array(Entry)
  getter cursor : Int32
  getter sort_mode : SortMode

  def did_select? : Bool
    !@selected_file.nil?
  end

  def content_height : Int32
    {@files.size, 1}.max
  end

  def content_width : Int32
    name_w = @files.map(&.name.size).max || 0
    {name_w + 22, 30}.max
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
    when key.text == "s"
      cycle_sort
      true
    when key.text == "r"
      scan_dir
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
      idx = @scroll_offset + rel_y - 1
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

    bg = effective_bg
    fg = @style.fg
    dir_fg = "#89b4fa"
    sel_fg = "#1e1e2e"
    sel_bg = "#cba6f7"
    header_fg = "#cba6f7"
    err_fg = "#f38ba8"

    if e = @err
      screen.write(r.x, r.y, "Error: #{e.message}"[0, r.w], fg: err_fg, bg: bg)
      return
    end

    visible = r.h - 1
    real_count = @files.count { |f| f.name != ".." }
    sort_label = @sort_mode.to_s.downcase
    status = "#{real_count} items  sort: #{sort_label}"
    avail = r.w - status.size - 2
    if @current_dir.size > avail && avail > 3
      head = @current_dir[0, avail - 3] + "..."
    elsif @current_dir.size > avail
      head = @current_dir[0, avail]
    else
      head = @current_dir
    end
    screen.write(r.x, r.y, "#{head}  #{status}".ljust(r.w)[0, r.w], fg: header_fg, bg: bg, bold: true)

    return if visible <= 0

    visible.times do |i|
      idx = @scroll_offset + i
      ry = r.y + 1 + i
      break if ry >= r.y + r.h

      if idx < @files.size
        entry = @files[idx]
        is_selected = idx == @cursor
        line = entry_line(entry, r.w)
        line_fg = is_selected ? sel_fg : (entry.directory ? dir_fg : fg)
        line_bg = is_selected ? sel_bg : bg
        screen.write(r.x, ry, line, fg: line_fg, bg: line_bg, bold: is_selected)
      else
        screen.write(r.x, ry, " " * r.w, bg: bg)
      end
    end
  end

  def render(io : IO) : Nil
  end

  private def entry_line(entry : Entry, width : Int32) : String
    if width < 22
      if entry.directory
        name = entry.name == ".." ? "../" : "#{entry.name}/"
        " #{name}"[0, width].ljust(width)
      else
        " #{entry.name}"[0, width].ljust(width)
      end
    else
      suffix_w = 11
      name_w = width - suffix_w - 2
      name_w = {name_w, 1}.max

      if entry.directory
        name = entry.name == ".." ? "../" : "#{entry.name}/"
        name = name[0, name_w].ljust(name_w)
        " #{name}  #{' '.to_s.rjust(8)} #{' '.to_s.ljust(10)}"
      else
        name = entry.name[0, name_w].ljust(name_w)
        size_s = format_size(entry.size).rjust(8)
        date_s = format_mtime(entry.mtime).ljust(10)
        " #{name} #{size_s} #{date_s}"
      end
    end
  end

  private def format_size(bytes : Int64) : String
    units = ["B", "KB", "MB", "GB", "TB"]
    size = bytes.to_f
    unit = 0
    while size >= 1024 && unit < units.size - 1
      size /= 1024
      unit += 1
    end
    if unit == 0
      "#{bytes}B"
    else
      "%.1f%s" % {size, units[unit]}
    end
  end

  private def format_mtime(mtime : Time?) : String
    if t = mtime
      now = Time.local
      if t.year == now.year && t.month == now.month && t.day == now.day
        t.to_s("%H:%M")
      elsif t.year == now.year
        t.to_s("%b %d")
      else
        t.to_s("%Y-%m-%d")
      end
    else
      ""
    end
  end

  private def scan_dir : Nil
    @files = [] of Entry
    @err = nil
    begin
      entries = Dir.entries(@current_dir)
      dirs = [] of Entry
      files = [] of Entry
      entries.each do |name|
        next if name == "."
        next if name.starts_with?('.') && !@show_hidden
        path = File.join(@current_dir, name)
        info = File.info?(path)
        is_dir = info.try(&.directory?) || File.directory?(path)
        hidden = name.starts_with?('.')
        size = info.try(&.size) || 0_i64
        mtime = info.try(&.modification_time)
        entry = Entry.new(name, path, is_dir, size, hidden, mtime)
        if is_dir
          dirs << entry
        else
          next unless @allowed_types.empty? || @allowed_types.any? { |ext| name.ends_with?(ext) }
          files << entry
        end
      end

      case @sort_mode
      in SortMode::Name
        dirs.sort_by! { |e| e.name.downcase }
        files.sort_by! { |e| e.name.downcase }
      in SortMode::Date
        dirs.sort_by! { |e| e.mtime || Time.utc(1980, 1, 1) }
        dirs.reverse!
        files.sort_by! { |e| e.mtime || Time.utc(1980, 1, 1) }
        files.reverse!
      in SortMode::Size
        dirs.sort_by! { |e| e.name.downcase }
        files.sort_by! { |e| e.size }
        files.reverse!
      end

      parent_path = File.dirname(@current_dir)
      parent_entry = Entry.new("..", parent_path, true)
      @files = [parent_entry] + dirs + files
    rescue ex : Exception
      @err = ex
    end
  end

  private def select_current : Nil
    return if @cursor >= @files.size
    entry = @files[@cursor]
    if entry.name == ".."
      go_up
    elsif entry.directory
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

  private def cycle_sort : Nil
    @sort_mode = case @sort_mode
                 in SortMode::Name then SortMode::Date
                 in SortMode::Date then SortMode::Size
                 in SortMode::Size then SortMode::Name
                 end
    @cursor = 0
    @scroll_offset = 0
    scan_dir
  end
end
