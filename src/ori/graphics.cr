require "./kitty"
require "./sixel"

# Which image protocol the terminal actually speaks.
#
# Reading `$TERM` is how this goes wrong: foot says `TERM=foot` and implements
# **sixel**, not the kitty graphics protocol, and a multiplexer rewrites TERM again.
# So the terminal is asked, once, before the first frame that has an image:
#
#   * a kitty graphics query (`a=q`) — only a terminal with the protocol answers
#     `i=31;OK`;
#   * a primary device-attributes request (`CSI c`) — sixel is attribute 4.
#
# `ORI_IMAGES=kitty|sixel|none` skips the probe.
module Ori
  class Graphics
    enum Backend
      None
      Kitty
      Sixel
    end

    PROBE_TIMEOUT = 250.milliseconds

    getter backend : Backend = Backend::None
    getter cell : {Int32, Int32} = {8, 16}
    getter reply : String = ""
    getter sixel : Ori::Sixel?

    def initialize(@output : IO = STDOUT)
    end

    # `probe_io` is stdin when the caller can afford to wait for the terminal's
    # answer (an app whose tty is in raw mode), nil otherwise.
    def configure(cell : {Int32, Int32}, probe_io : IO? = nil, cache_dir : String? = nil) : Nil
      @cell = {cell[0].clamp(4, 64), cell[1].clamp(6, 128)}
      @backend = override || (probe_io ? probe(probe_io) : Backend::None)
      @sixel = if backend.sixel? && Ori::Sixel.available?
                 Ori::Sixel.new(cache_dir || self.class.default_cache_dir, @cell)
               end
      @backend = Backend::None if backend.sixel? && @sixel.nil?
    end

    def configured? : Bool
      !@backend.none?
    end

    def name : String
      case @backend
      when Backend::Kitty then "kitty"
      when .sixel? then "sixel"
      else              "none"
      end
    end

    # The payload for sixel, encoded at the current cell size.
    def sixel_data(png : String, cols : Int32, rows : Int32) : String?
      @sixel.try(&.fetch(png, cols, rows))
    end

    # Draw one image whose top-left cell is the cursor. False when the payload is not
    # ready yet (sixel), so the caller can retry next frame.
    def draw(png : String, cols : Int32, rows : Int32, id : UInt32) : Bool
      case @backend
      when .kitty?
        Ori::Kitty.draw(@output, png, cols, rows, id)
        true
      when .sixel?
        data = sixel_data(png, cols, rows)
        return false unless data
        @output << data
        true
      else
        false
      end
    end

    def clear : Nil
      Ori::Kitty.clear(@output) if backend.kitty?
    end

    # The cell box an image of `width`x`height` pixels should occupy inside a
    # `max_cols`x`max_rows` area, keeping its aspect ratio. Cells are not square, so
    # the ratio is `cols/rows = (w/h) * (cell_h/cell_w)`.
    def cell_box(width : Int32, height : Int32, max_cols : Int32, max_rows : Int32) : {Int32, Int32}
      return {1, 1} if width <= 0 || height <= 0 || max_cols < 1 || max_rows < 1
      ratio = @cell[1].to_f32 / @cell[0].to_f32
      cols = max_cols
      rows = (cols.to_f32 * height / (width * ratio)).round.to_i32
      if rows > max_rows
        rows = max_rows
        cols = (rows.to_f32 * ratio * width / height).round.to_i32
      end
      {cols.clamp(1, max_cols), rows.clamp(1, max_rows)}
    end

    def self.default_cache_dir : String
      base = ENV["XDG_CACHE_HOME"]?.presence || File.join(ENV["HOME"]? || "/tmp", ".cache")
      File.join(base, "ori", "images")
    end

    # The probe, exposed so an app can print what the terminal said.
    def self.query(output : IO, input : IO) : String
      output << "\e_Gi=31,s=1,v=1,a=q,t=d,f=24;AAAA\e\\"
      output << "\e[c"
      output.flush
      reply = String.new
      begin
        input.read_timeout = PROBE_TIMEOUT
        while (byte = input.read_byte)
          reply += byte.chr
          break if reply.size >= 256
        end
      rescue IO::TimeoutError | IO::Error
      ensure
        input.read_timeout = nil
      end
      reply
    end

    private def probe(input : IO) : Backend
      @reply = self.class.query(@output, input)
      return Backend::Kitty if @reply.includes?("i=31;OK")
      if md = /\[([0-9;]*)c/.match(@reply)
        return Backend::Sixel if md[1].split(';').includes?("4")
      end
      return from_term if @reply.empty?
      Backend::None
    end

    private def from_term : Backend
      term = ENV["TERM"]? || ""
      return Backend::Kitty if term.includes?("kitty") || term.includes?("ghostty") || term.includes?("wezterm")
      return Backend::Sixel if term.includes?("foot")
      Backend::None
    end

    private def override : Backend?
      case ENV["ORI_IMAGES"]?
      when "kitty" then Backend::Kitty
      when "sixel" then Backend::Sixel
      when "none"  then Backend::None
      end
    end
  end
end
