module Ori::Term
  def self.move(x : Int32, y : Int32) : String
    "\e[#{y + 1};#{x + 1}H"
  end

  def self.clear_screen : String
    "\e[2J\e[H"
  end

  def self.hide_cursor : String
    "\e[?25l"
  end

  def self.show_cursor : String
    "\e[?25h"
  end

  def self.cursor_default : String
    "\e[0 q"
  end

  def self.cursor_shape(shape : Symbol) : String
    case shape
    when :block       then "\e[2 q"
    when :block_blink then "\e[1 q"
    when :underline   then "\e[4 q"
    when :underline_blink then "\e[3 q"
    when :bar         then "\e[6 q"
    when :bar_blink   then "\e[5 q"
    else                   "\e[2 q"
    end
  end

  def self.cursor_at(x : Int32, y : Int32) : String
    "\e[#{y + 1};#{x + 1}H\e[?25h"
  end

  def self.enter_alt : String
    "\e[?1049h"
  end

  def self.exit_alt : String
    "\e[?1049l"
  end

  def self.erase_line : String
    "\e[K"
  end

  def self.enable_mouse : String
    "\e[?1000h\e[?1002h\e[?1006h"
  end

  def self.disable_mouse : String
    "\e[?1006l\e[?1002l\e[?1000l"
  end

  lib LIoctl
    struct Winsize
      ws_row : UInt16; ws_col : UInt16; ws_xpixel : UInt16; ws_ypixel : UInt16
    end
    fun ioctl(fd : Int32, req : UInt64, ...) : Int32
  end

  def self.window_size : {Int32, Int32}
    ws = uninitialized LIoctl::Winsize
    ret = LIoctl.ioctl(0, 0x00005413_u64, pointerof(ws))
    ret != 0 || ws.ws_col == 0 ? {80, 24} : {ws.ws_col.to_i, ws.ws_row.to_i}
  end

  def self.enter_raw : LibC::Termios
    old = uninitialized LibC::Termios
    if LibC.tcgetattr(0, pointerof(old)) != 0
      raise "ori: failed to get terminal attributes"
    end
    raw = old
    raw.c_iflag = raw.c_iflag & ~(LibC::BRKINT | LibC::ICRNL | LibC::INPCK | LibC::ISTRIP | LibC::IXON)
    raw.c_oflag = raw.c_oflag & ~LibC::OPOST
    raw.c_cflag = (raw.c_cflag & ~LibC::CS8) | LibC::CS8
    raw.c_lflag = raw.c_lflag & ~(LibC::ECHO | LibC::ICANON | LibC::ISIG | LibC::IEXTEN)
    raw.c_cc[LibC::VMIN] = 1_u8; raw.c_cc[5] = 0_u8
    LibC.tcsetattr(0, LibC::TCSAFLUSH, pointerof(raw))
    old
  end

  def self.restore(state : LibC::Termios) : Nil
    LibC.tcsetattr(0, LibC::TCSAFLUSH, pointerof(state))
  rescue Exception
  end
end
