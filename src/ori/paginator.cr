struct Ori::Paginator
  enum Type
    Arabic
    Dots
  end

  getter page : Int32
  getter per_page : Int32
  getter total_pages : Int32
  getter type : Type
  getter active_dot : String
  getter inactive_dot : String

  def initialize(
    @per_page : Int32 = 10,
    @type : Type = Type::Arabic,
    @active_dot : String = "•",
    @inactive_dot : String = "○"
  )
    @page = 0
    @total_pages = 0
  end

  def set_total_pages(items : Int32) : Int32
    @total_pages = items > 0 ? (items + @per_page - 1) // @per_page : 0
    @page = {@page, {@total_pages - 1, 0}.max}.min
    @total_pages
  end

  def items_on_page(total_items : Int32) : Int32
    s, e = slice_bounds(total_items)
    e - s
  end

  def slice_bounds(total_items : Int32) : {Int32, Int32}
    start = @page * @per_page
    ed = {start + @per_page, total_items}.min
    {start, ed}
  end

  def prev_page : Nil
    @page -= 1 if @page > 0
  end

  def next_page : Nil
    @page += 1 if @page < @total_pages - 1
  end

  def on_first_page? : Bool
    @page <= 0
  end

  def on_last_page? : Bool
    @page >= @total_pages - 1
  end

  def view : String
    case @type
    when Type::Arabic
      "#{@page + 1}/#{@total_pages}"
    when Type::Dots
      @total_pages.times.map do |i|
        i == @page ? @active_dot : @inactive_dot
      end.join(" ")
    else
      ""
    end
  end
end
