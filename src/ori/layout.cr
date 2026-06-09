module Ori::Layout
  def self.compute(root : Ori::Box) : Nil
    compute_box(root, root.rect)
  end

  private def self.compute_box(box : Ori::Box, allocated : Ori::Rect) : Nil
    box.rect = allocated
    return if box.children.empty?

    inner = allocated.inner(box.style)

    if box.style.direction == :vertical
      layout_vertical(box, inner)
    else
      layout_horizontal(box, inner)
    end
  end

  private def self.auto_h(child : Ori::Node) : Int32
    child.content_height + child.style.vpadding
  end

  private def self.auto_w(child : Ori::Node) : Int32
    child.content_width + child.style.hpadding
  end

  private def self.apply_minmax(w : Int32, h : Int32, style : Ori::S) : {Int32, Int32}
    mw = style.min_width
    xw = style.max_width
    mh = style.min_height
    xh = style.max_height
    aw = w
    ah = h
    aw = {aw, mw}.max if mw
    aw = {aw, xw}.min if xw
    ah = {ah, mh}.max if mh
    ah = {ah, xh}.min if xh
    {aw, ah}
  end

  private def self.child_size(child : Ori::Node, direction : Symbol, available : Int32) : Int32?
    if direction == :vertical
      if h = child.style.height
        h
      elsif child.style.height_pct
        (available * child.style.height_pct.not_nil! / 100.0).to_i
      elsif child.style.flex > 0
        nil  # handled by flex allocation
      else
        auto_h(child)
      end
    else
      if w = child.style.width
        w
      elsif child.style.width_pct
        (available * child.style.width_pct.not_nil! / 100.0).to_i
      elsif child.style.flex > 0
        nil
      else
        auto_w(child)
      end
    end
  end

  private def self.layout_vertical(box : Ori::Box, inner : Ori::Rect) : Nil
    fixed_total = 0
    flex_total = 0
    spacing = box.style.spacing

    box.children.each do |child|
      sz = child_size(child, :vertical, inner.h)
      if sz
        fixed_total += sz
      else
        flex_total += child.style.flex
      end
    end

    gap_total = spacing * {box.children.size - 1, 0}.max
    remaining = {inner.h - fixed_total - gap_total, 0}.max
    flex_unit = flex_total > 0 ? remaining.to_f / flex_total : 0.0

    cy = inner.y
    box.children.each_with_index do |child, idx|
      cy += spacing if idx > 0

      raw = child_size(child, :vertical, inner.h)
      h = if raw
            raw
          else
            (flex_unit * child.style.flex).round.to_i
          end

      w = child_width(child, inner.w)
      w, h = apply_minmax(w, h, child.style)

      child.rect = Ori::Rect.new(inner.x, cy, w, h)

      if child.is_a?(Ori::Box)
        compute_box(child, child.rect)
      end

      cy += h
    end

    leftover = inner.y + inner.h - cy
    if leftover > 0 && !box.children.empty?
      last = box.children.last
      unless last.style.height
        last.rect = Ori::Rect.new(last.rect.x, last.rect.y, last.rect.w, last.rect.h + leftover)
      end
    end
  end

  private def self.layout_horizontal(box : Ori::Box, inner : Ori::Rect) : Nil
    fixed_total = 0
    flex_total = 0
    spacing = box.style.spacing

    box.children.each do |child|
      sz = child_size(child, :horizontal, inner.w)
      if sz
        fixed_total += sz
      else
        flex_total += child.style.flex
      end
    end

    gap_total = spacing * {box.children.size - 1, 0}.max
    remaining = {inner.w - fixed_total - gap_total, 0}.max
    flex_unit = flex_total > 0 ? remaining.to_f / flex_total : 0.0

    cx = inner.x
    box.children.each_with_index do |child, idx|
      cx += spacing if idx > 0

      raw = child_size(child, :horizontal, inner.w)
      w = if raw
            raw
          else
            (flex_unit * child.style.flex).round.to_i
          end

      h = child_height(child, inner.h)
      w, h = apply_minmax(w, h, child.style)

      child.rect = Ori::Rect.new(cx, inner.y, w, h)

      if child.is_a?(Ori::Box)
        compute_box(child, child.rect)
      end

      cx += w
    end

    leftover = inner.x + inner.w - cx
    if leftover > 0 && !box.children.empty?
      last = box.children.last
      unless last.style.width
        last.rect = Ori::Rect.new(last.rect.x, last.rect.y, last.rect.w + leftover, last.rect.h)
      end
    end
  end

  private def self.child_width(child : Ori::Node, available : Int32) : Int32
    raw = if w = child.style.width
            {w, available}.min
          elsif child.style.width_pct
            {(available * child.style.width_pct.not_nil! / 100.0).to_i, available}.min
          else
            available
          end
    {raw, 0}.max
  end

  private def self.child_height(child : Ori::Node, available : Int32) : Int32
    raw = if h = child.style.height
            {h, available}.min
          elsif child.style.height_pct
            {(available * child.style.height_pct.not_nil! / 100.0).to_i, available}.min
          else
            available
          end
    {raw, 0}.max
  end
end
