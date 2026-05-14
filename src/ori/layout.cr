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

  private def self.layout_vertical(box : Ori::Box, inner : Ori::Rect) : Nil
    fixed_total = 0
    flex_total = 0

    box.children.each do |child|
      if h = child.style.height
        fixed_total += h
      elsif child.style.height_pct
        pct = child.style.height_pct.not_nil!
        fixed_total += (inner.h * pct / 100.0).to_i
      else
        if child.style.flex > 0
          flex_total += child.style.flex
        else
          fixed_total += auto_h(child)
        end
      end
    end

    remaining = {inner.h - fixed_total, 0}.max
    flex_unit = flex_total > 0 ? remaining.to_f / flex_total : 0.0

    cy = inner.y
    box.children.each do |child|
      w = child_width(child, inner.w)
      h = if hh = child.style.height
            hh
          elsif child.style.height_pct
            (inner.h * child.style.height_pct.not_nil! / 100.0).to_i
          elsif child.style.flex > 0
            (flex_unit * child.style.flex).round.to_i
          else
            auto_h(child)
          end

      child.rect = Ori::Rect.new(inner.x, cy, w, h)

      if child.is_a?(Ori::Box)
        compute_box(child, child.rect)
      end

      cy += h
    end
  end

  private def self.layout_horizontal(box : Ori::Box, inner : Ori::Rect) : Nil
    fixed_total = 0
    flex_total = 0

    box.children.each do |child|
      if w = child.style.width
        fixed_total += w
      elsif child.style.width_pct
        pct = child.style.width_pct.not_nil!
        fixed_total += (inner.w * pct / 100.0).to_i
      else
        if child.style.flex > 0
          flex_total += child.style.flex
        else
          fixed_total += auto_w(child)
        end
      end
    end

    remaining = {inner.w - fixed_total, 0}.max
    flex_unit = flex_total > 0 ? remaining.to_f / flex_total : 0.0

    cx = inner.x
    box.children.each do |child|
      w = if ww = child.style.width
            ww
          elsif child.style.width_pct
            (inner.w * child.style.width_pct.not_nil! / 100.0).to_i
          elsif child.style.flex > 0
            (flex_unit * child.style.flex).round.to_i
          else
            auto_w(child)
          end
      h = child_height(child, inner.h)

      child.rect = Ori::Rect.new(cx, inner.y, w, h)

      if child.is_a?(Ori::Box)
        compute_box(child, child.rect)
      end

      cx += w
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
