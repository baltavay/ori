class Ori::FocusManager
  @nodes : Array(Ori::Node) = [] of Ori::Node
  @index : Int32 = -1

  def update(root : Ori::Node) : Nil
    old = @index
    @nodes = collect(root)
    @index = old >= 0 && old < @nodes.size ? old : (@nodes.empty? ? -1 : 0)
    @nodes.each(&.focused = false)
    @nodes[@index]?.try(&.focused = true) if @index >= 0
  end

  def focus_first : Nil
    unfocus
    @index = @nodes.empty? ? -1 : 0
    @nodes[@index]?.try(&.focused = true)
  end

  def handle_key(key : Ori::Key) : Bool
    return false if @nodes.empty?
    n = @nodes[@index]?
    if n && n.responds_to?(:open) && n.open
      return n.on_key(key)
    end
    if key.code.tab? && !key.shift
      focus_next; true
    elsif key.code.tab? && key.shift
      focus_prev; true
    else
      n ? n.on_key(key) : false
    end
  end

  private def focus_next : Nil
    unfocus
    @index = (@index + 1) % @nodes.size
    @nodes[@index].focused = true
  end

  private def focus_prev : Nil
    unfocus
    @index = (@index - 1) % @nodes.size
    @nodes[@index].focused = true
  end

  private def unfocus : Nil
    @nodes.each do |n|
      n.blur
      n.focused = false
    end
  end

  private def collect(node : Ori::Node) : Array(Ori::Node)
    result = [] of Ori::Node
    if node.is_a?(Ori::Box)
      node.children.each { |c| result.concat(collect(c)) }
    end
    result << node if node.focusable?
    result
  end
end
