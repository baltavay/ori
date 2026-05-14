module Ori::Color
  def self.apply(fg : String?, text : String) : String
    return text unless fg
    r, g, b = hex_rgb(fg)
    "\e[38;2;#{r};#{g};#{b}m#{text}\e[0m"
  end

  def self.apply_bg(bg : String?, text : String) : String
    return text unless bg
    r, g, b = hex_rgb(bg)
    "\e[48;2;#{r};#{g};#{b}m#{text}\e[0m"
  end

  def self.fg(hex : String, text : String) : String
    apply(hex, text)
  end

  def self.bg(hex : String, text : String) : String
    apply_bg(hex, text)
  end

  def self.inverse(text : String) : String
    "\e[7m#{text}\e[0m"
  end

  def self.dim(text : String) : String
    "\e[2m#{text}\e[0m"
  end

  def self.bold(text : String) : String
    "\e[1m#{text}\e[0m"
  end

  def self.paint(text : String, fg : String? = nil, bg : String? = nil, bold = false) : String
    pre = IO::Memory.new
    if bg
      r, g, b = hex_rgb(bg)
      pre << "\e[48;2;#{r};#{g};#{b}m"
    end
    if fg
      r, g, b = hex_rgb(fg)
      pre << "\e[38;2;#{r};#{g};#{b}m"
    end
    pre << "\e[1m" if bold
    "#{pre}#{text}\e[0m"
  end

  def self.hex_rgb(hex : String) : {Int32, Int32, Int32}
    h = hex.delete('#')
    h = "#{h[0]}#{h[0]}#{h[1]}#{h[1]}#{h[2]}#{h[2]}" if h.size == 3
    return {0, 0, 0} unless h.size >= 6
    {h[0, 2].to_i(16, whitespace: false), h[2, 2].to_i(16, whitespace: false), h[4, 2].to_i(16, whitespace: false)}
  rescue ArgumentError
    {0, 0, 0}
  end
end
