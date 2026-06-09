class Ori::Tree < Ori::Node
  class Node
    getter label : String
    getter children : Array(Node)
    property expanded : Bool
    property data : String?

    def initialize(@label : String, @children = [] of Node, @expanded = false, @data = nil)
    end

    def leaf? : Bool
      @children.empty?
    end
  end

  @root : Node
  @flat : Array({Node, Int32})
  @cursor : Int32
  @scroll_offset : Int32
  @on_select : Proc(String, Nil)?

  def initialize(
    root : Node? = nil,
    @on_select : Proc(String, Nil)? = nil,
    style : Ori::S = Ori::S.none
  )
    super(style)
    @root = root || Node.new("root")
    @cursor = 0
    @scroll_offset = 0
    @flat = [] of {Node, Int32}
    flatten
  end

  getter root : Node
  getter cursor : Int32

  def selected_data : String?
    entry = @flat[@cursor]? || return nil
    entry[0].data || entry[0].label
  end

  def content_height : Int32
    @flat.size
  end

  def content_width : Int32
    max_w = 0
    @flat.each do |entry|
      w = entry[1] * 2 + 3 + entry[0].label.size
      max_w = w if w > max_w
    end
    {max_w, 10}.max
  end

  def focusable? : Bool
    @style.focusable
  end

  def on_key(key : Ori::Key) : Bool
    case
    when key.code.down? || key.text == "j"
      @cursor += 1 if @cursor < @flat.size - 1
      adjust_scroll
      true
    when key.code.up? || key.text == "k"
      @cursor -= 1 if @cursor > 0
      adjust_scroll
      true
    when key.code.right? || key.text == "l"
      expand
      true
    when key.code.left? || key.text == "h"
      collapse
      true
    when key.code.enter? || key.code.space?
      activate
      true
    else
      false
    end
  end

  def render_screen(screen : Ori::Screen) : Nil
    r = @rect
    return if r.w <= 0 || r.h <= 0

    bg = effective_bg
    fg = @style.fg || "#cdd6f4"
    dir_fg = "#89b4fa"
    sel_fg = "#1e1e2e"
    sel_bg = "#cba6f7"

    r.h.times do |i|
      idx = @scroll_offset + i
      ry = r.y + i
      break if ry >= r.y + r.h

      if idx < @flat.size
        node, depth = @flat[idx]
        is_cursor = idx == @cursor
        indent = "  " * depth
        icon = node.leaf? ? "  " : (node.expanded ? "▾ " : "▸ ")
        label = "#{indent}#{icon}#{node.label}"
        label = label[0, r.w].ljust(r.w)
        cell_fg = is_cursor ? sel_fg : (node.leaf? ? fg : dir_fg)
        cell_bg = is_cursor ? sel_bg : bg
        screen.write(r.x, ry, label, fg: cell_fg, bg: cell_bg, bold: is_cursor)
      else
        screen.write(r.x, ry, " " * r.w, bg: bg)
      end
    end
  end

  def render(io : IO) : Nil
  end

  private def flatten : Nil
    @flat = [] of {Node, Int32}
    flatten_node(@root, 0)
  end

  private def flatten_node(node : Node, depth : Int32) : Nil
    return if depth > 0 && !node.expanded
    node.children.each do |child|
      @flat << {child, depth}
      flatten_node(child, depth + 1) if child.expanded
    end
  end

  private def current_node : Node?
    @flat[@cursor]?.try(&.[0])
  end

  private def expand : Nil
    node = current_node
    return if node.nil? || node.leaf?
    unless node.expanded
      node.expanded = true
      flatten
    end
  end

  private def collapse : Nil
    node = current_node
    if node && !node.leaf? && node.expanded
      node.expanded = false
      flatten
      @cursor = {@cursor, @flat.size - 1}.min
    elsif (entry = @flat[@cursor]?) && entry[1] > 0
      parent_depth = entry[1]
      while @cursor > 0 && @flat[@cursor][1] >= parent_depth
        @cursor -= 1
      end
    end
  end

  private def activate : Nil
    node = current_node
    return if node.nil?
    if node.leaf?
      @on_select.try(&.call(node.data || node.label))
    else
      node.expanded = !node.expanded
      flatten
      @cursor = {@cursor, @flat.size - 1}.min
    end
  end

  private def adjust_scroll : Nil
    vh = {@rect.h, 1}.max
    if @cursor < @scroll_offset
      @scroll_offset = @cursor
    elsif @cursor >= @scroll_offset + vh
      @scroll_offset = @cursor - vh + 1
    end
  end
end
