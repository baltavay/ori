require "./node"

# A picture in the cell grid.
#
# The node owns a cell rectangle — the layout gives it one, like any other node — and
# registers the image with the screen; the renderer places it after the text, fitted
# inside that rectangle so the aspect ratio is kept. The cells themselves are painted
# with the node's background, so an image that is still being encoded (sixel needs a
# process run) shows as a block rather than as a hole.
class Ori::ImageNode < Ori::Node
  getter path : String

  @@sizes = {} of String => Tuple(Int32, Int32)?

  def initialize(@path : String, style : Ori::S = Ori::S.none)
    super(style)
  end

  def content_height : Int32
    @style.height || 1
  end

  def content_width : Int32
    @style.width || 1
  end

  # Text is not this node's job: the image is placed after the frame is flushed.
  def render(io : IO) : Nil
  end

  def render_screen(screen : Ori::Screen) : Nil
    return if @rect.w < 1 || @rect.h < 1
    if bg = effective_bg
      (@rect.h).times { |row| screen.write(@rect.x, @rect.y + row, " " * @rect.w, bg: bg) }
    end
    return unless size = self.class.size(@path)
    screen.place_image(@rect.x, @rect.y, @rect.w, @rect.h, @path, size[0], size[1])
  end

  # PNG dimensions straight out of the header (width at byte 16, height at 20, both
  # big-endian); cached because a frame asks once per visible image.
  def self.size(path : String) : Tuple(Int32, Int32)?
    return nil unless File.exists?(path)
    stamp = File.info?(path).try { |info| "#{info.size}:#{info.modification_time.to_unix}" } || "0"
    key = "#{path}:#{stamp}"
    if @@sizes.has_key?(key)
      return @@sizes[key]
    end
    dims = read_size(path)
    @@sizes[key] = dims
    dims
  end

  private def self.read_size(path : String) : Tuple(Int32, Int32)?
    header = Bytes.new(24)
    File.open(path, "rb") { |file| file.read_fully(header) }
    return nil unless header[12, 4] == "IHDR".to_slice
    width = (header[16].to_i32 << 24) | (header[17].to_i32 << 16) | (header[18].to_i32 << 8) | header[19].to_i32
    height = (header[20].to_i32 << 24) | (header[21].to_i32 << 16) | (header[22].to_i32 << 8) | header[23].to_i32
    return nil if width <= 0 || height <= 0
    {width, height}
  rescue
    nil
  end
end
