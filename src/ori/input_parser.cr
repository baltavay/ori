struct Ori::InputParser
  private enum State; Normal; Escape; Csi; Ss3; Utf8; end

  @state : State = State::Normal
  @csi_params : String = ""
  @utf8_buf : Bytes = Bytes.new(4)
  @utf8_len : Int32 = 0
  @utf8_exp : Int32 = 0
  @pasting : Bool = false

  def pasting? : Bool
    @pasting
  end

  private enum EventType
    Key
    Mouse
  end

  struct Result
    getter key : Ori::Key?
    getter mouse : Ori::Mouse?

    def initialize(@key : Ori::Key? = nil, @mouse : Ori::Mouse? = nil)
    end

    def key? : Bool
      !@key.nil?
    end

    def mouse? : Bool
      !@mouse.nil?
    end
  end

  def in_escape_state? : Bool
    @state == State::Escape
  end

  def flush_escape : Ori::Key?
    return nil unless @state == State::Escape
    @state = State::Normal
    Ori::Key.new(code: :escape)
  end

  def parse(byte : UInt8) : Ori::Key?
    r = parse_full(byte)
    r.is_a?(Result) && r.key? ? r.key : nil
  end

  def parse_full(byte : UInt8) : Result?
    case @state
    in State::Normal
      if @pasting
        case byte
        when 0x1b
          @state = State::Escape; @csi_params = ""; nil
        when 0x0d, 0x0a, 0x0c
          Result.new(key: Ori::Key.new(code: :enter))
        when 0x09
          Result.new(key: Ori::Key.new(text: "\t"))
        else
          if byte >= 0x20 && byte < 0x7f
            Result.new(key: Ori::Key.new(text: byte.chr.to_s))
          elsif byte >= 0x80
            @utf8_buf[0] = byte; @utf8_len = 1
            @utf8_exp = (byte & 0xE0) == 0xC0 ? 2 : (byte & 0xF0) == 0xE0 ? 3 : (byte & 0xF8) == 0xF0 ? 4 : 0
            @state = @utf8_exp > 0 ? State::Utf8 : State::Normal
            nil
          else
            nil
          end
        end
      else
        parse_normal(byte)
      end
    in State::Escape
      @state = State::Normal
      case byte
      when 0x5b then @state = State::Csi; @csi_params = ""; nil
      when 0x4f then @state = State::Ss3; nil
      when 0x1b then Result.new(key: Ori::Key.new(code: :escape))
      else Result.new(key: Ori::Key.new(code: :escape))
      end
    in State::Csi
      if byte >= 0x30 && byte <= 0x3f
        @csi_params += byte.chr; nil
      else
        @state = State::Normal
        params = parse_params(@csi_params)
        case byte.chr
        when 'A' then mk(:up, params); when 'B' then mk(:down, params)
        when 'C' then mk(:right, params); when 'D' then mk(:left, params)
        when 'H' then mk(:home, params); when 'F' then mk(:end, params)
        when 'Z' then Result.new(key: Ori::Key.new(code: :tab, shift: true))
        when '~' then parse_tilde(params)
        when 'u' then parse_u(params)
        when 'M' then parse_sgr_mouse(params, :press)
        when 'm' then parse_sgr_mouse(params, :release)
        else nil
        end
      end
    in State::Ss3
      @state = State::Normal
      case byte
      when 0x41 then Result.new(key: Ori::Key.new(code: :up)); when 0x42 then Result.new(key: Ori::Key.new(code: :down))
      when 0x43 then Result.new(key: Ori::Key.new(code: :right)); when 0x44 then Result.new(key: Ori::Key.new(code: :left))
      when 0x48 then Result.new(key: Ori::Key.new(code: :home)); when 0x46 then Result.new(key: Ori::Key.new(code: :end))
      when 0x50 then Result.new(key: Ori::Key.new(code: :f1)); when 0x51 then Result.new(key: Ori::Key.new(code: :f2))
      when 0x52 then Result.new(key: Ori::Key.new(code: :f3)); when 0x53 then Result.new(key: Ori::Key.new(code: :f4))
      else nil
      end
    in State::Utf8
      @utf8_buf[@utf8_len] = byte; @utf8_len += 1
      if @utf8_len >= @utf8_exp
        @state = State::Normal
        begin
          ch = String.new(@utf8_buf[0...@utf8_len])[0]?
          ch ? Result.new(key: Ori::Key.new(text: ch.to_s)) : nil
        rescue; nil
        end
      else nil
      end
    end
  end

  private def parse_normal(byte : UInt8) : Result?
    case byte
    when 0x1b then @state = State::Escape; @csi_params = ""; nil
    when 0x0d, 0x0a, 0x0c then Result.new(key: Ori::Key.new(code: :enter))
    when 0x7f, 0x08 then Result.new(key: Ori::Key.new(code: :backspace))
    when 0x09 then Result.new(key: Ori::Key.new(code: :tab))
    when 0x20 then Result.new(key: Ori::Key.new(code: :space, text: " "))
    when 0x01..0x1a then Result.new(key: Ori::Key.new(text: (byte + 0x60).chr.to_s, ctrl: true))
    else
      if byte >= 0x20 && byte < 0x7f
        Result.new(key: Ori::Key.new(text: byte.chr.to_s))
      elsif byte >= 0x80
        @utf8_buf[0] = byte; @utf8_len = 1
        @utf8_exp = (byte & 0xE0) == 0xC0 ? 2 : (byte & 0xF0) == 0xE0 ? 3 : (byte & 0xF8) == 0xF0 ? 4 : 0
        @state = @utf8_exp > 0 ? State::Utf8 : State::Normal
        nil
      else nil
      end
    end
  end

  private def mk(code : Ori::Key::Code, params : Array(Int32)) : Result
    m = params[1]? || 1
    Result.new(key: Ori::Key.new(code: code, ctrl: m == 5 || m > 6, alt: m == 3 || m == 4 || m > 6, shift: m == 2 || m == 4 || m == 6 || m == 8))
  end

  private def parse_tilde(params : Array(Int32)) : Result?
    c = params[0]? || 0
    m = params[1]? || 1
    if c == 27
      charcode = params[2]? || 0
      shift = m == 2 || m == 4 || m == 6 || m == 8
      ctrl = m == 5 || m > 6
      alt = m == 3 || m == 4 || m > 6
      if charcode == 13 || charcode == 0
        return Result.new(key: Ori::Key.new(code: :enter, shift: shift, ctrl: ctrl, alt: alt))
      elsif charcode >= 32 && charcode < 127
        ch = charcode.chr.to_s
        return Result.new(key: Ori::Key.new(text: ch, ctrl: ctrl, alt: alt, shift: shift))
      elsif charcode == 9
        return Result.new(key: Ori::Key.new(code: :tab, shift: shift, ctrl: ctrl, alt: alt))
      elsif charcode == 127 || charcode == 8
        return Result.new(key: Ori::Key.new(code: :backspace, shift: shift, ctrl: ctrl, alt: alt))
      end
      return Result.new(key: Ori::Key.new(code: :unknown, ctrl: ctrl, alt: alt, shift: shift))
    end

    code = case c
      when 200 then @pasting = true; return nil
      when 201 then @pasting = false; return nil
      when 2 then Ori::Key::Code::Insert; when 3 then Ori::Key::Code::Delete
      when 5 then Ori::Key::Code::PgUp; when 6 then Ori::Key::Code::PgDown
      when 1, 7, 8, 9 then Ori::Key::Code::Home; when 4 then Ori::Key::Code::End
      when 11 then Ori::Key::Code::F1; when 12 then Ori::Key::Code::F2
      when 13 then Ori::Key::Code::F3; when 14 then Ori::Key::Code::F4
      when 15 then Ori::Key::Code::F5; when 17 then Ori::Key::Code::F6
      when 18 then Ori::Key::Code::F7; when 19 then Ori::Key::Code::F8
      when 20 then Ori::Key::Code::F9; when 21 then Ori::Key::Code::F10
      when 23 then Ori::Key::Code::F11; when 24 then Ori::Key::Code::F12
      else Ori::Key::Code::Unknown
      end
    mk(code, params)
  end

  private def parse_u(params : Array(Int32)) : Result?
    c = params[0]? || 0
    m = params[1]? || 1
    shift = m == 2 || m == 4 || m == 6 || m == 8
    ctrl = m == 5 || m > 6
    alt = m == 3 || m == 4 || m > 6
    case c
    when 200
      @pasting = true; nil
    when 201
      @pasting = false; nil
    when 13
      Result.new(key: Ori::Key.new(code: :enter, shift: shift, ctrl: ctrl, alt: alt))
    when 9
      Result.new(key: Ori::Key.new(code: :tab, shift: shift, ctrl: ctrl, alt: alt))
    when 127, 8
      Result.new(key: Ori::Key.new(code: :backspace, shift: shift, ctrl: ctrl, alt: alt))
    else
      if c >= 32 && c < 127
        Result.new(key: Ori::Key.new(text: c.chr.to_s, shift: shift, ctrl: ctrl, alt: alt))
      else
        Result.new(key: Ori::Key.new(code: :unknown, shift: shift, ctrl: ctrl, alt: alt))
      end
    end
  end

  private def parse_sgr_mouse(params : Array(Int32), default_action : Symbol) : Result?
    return nil unless params.size >= 3
    btn_code = params[0]
    x = {params[1] - 1, 0}.max
    y = {params[2] - 1, 0}.max

    ctrl = (btn_code & 0x10) != 0
    alt = (btn_code & 0x08) != 0
    shift = (btn_code & 0x04) != 0

    base = btn_code & 0x43
    button = case base
             when 0  then Ori::Mouse::Button::Left
             when 1  then Ori::Mouse::Button::Middle
             when 2  then Ori::Mouse::Button::Right
             when 64 then Ori::Mouse::Button::WheelUp
             when 65 then Ori::Mouse::Button::WheelDown
             else         Ori::Mouse::Button::None
             end

    motion = (btn_code & 0x20) != 0

    action = if button.wheel_up? || button.wheel_down?
               Ori::Mouse::Action::Wheel
             elsif motion
               Ori::Mouse::Action::Motion
             elsif default_action == :release
               Ori::Mouse::Action::Release
             else
               Ori::Mouse::Action::Press
             end

    mouse = Ori::Mouse.new(x: x, y: y, button: button, action: action, ctrl: ctrl, alt: alt, shift: shift)
    Result.new(mouse: mouse)
  end

  private def parse_params(s : String) : Array(Int32)
    return [] of Int32 if s.empty?
    s.lchop('<').split(';').map { |p| p.to_i? || 0 }
  end
end
