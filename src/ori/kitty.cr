require "base64"

# The kitty graphics protocol (kitty, ghostty, wezterm, …).
#
# An image is sent inside an Application Program Command escape
# (`\e_G<params>;<base64>\e\\`), in chunks the protocol caps at 4096 bytes of
# payload, and drawn at the cursor cell scaled into a cell box. Nothing is kept on
# the terminal side between frames: the renderer deletes and re-sends when the
# placements move, which only happens on the keys that change the layout.
module Ori
  module Kitty
    CHUNK = 4096

    # `a=T` transmit and display, `f=100` PNG, `q=2` no reply, `C=1` leave the cursor.
    def self.draw(io : IO, png : String, cols : Int32, rows : Int32, id : UInt32) : Nil
      data = Base64.strict_encode(File.read(png))
      offset = 0
      first = true
      while offset < data.size
        chunk = data[offset, CHUNK]
        offset += chunk.size
        more = offset < data.size ? 1 : 0
        io << "\e_G"
        if first
          io << "a=T,f=100,i=" << id << ",c=" << cols << ",r=" << rows << ",C=1,q=2,m=" << more
          first = false
        else
          io << "m=" << more
        end
        io << ';' << chunk << "\e\\"
      end
    end

    # Drop every image the terminal holds, data included. `a=p` placements could be
    # cleaned up individually, but re-sending is only paid when the layout moves.
    def self.clear(io : IO) : Nil
      io << "\e_Ga=d\e\\"
    end
  end
end
