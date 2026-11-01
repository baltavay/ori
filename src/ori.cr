module Ori
  VERSION = "0.1.0"

  def self.border_chars(style : Symbol) : NamedTuple(tl: Char, tr: Char, bl: Char, br: Char, h: Char, v: Char, prefix: Char)
    case style
    when :single   then {tl: '┌', tr: '┐', bl: '└', br: '┘', h: '─', v: '│', prefix: '▌'}
    when :double   then {tl: '╔', tr: '╗', bl: '╚', br: '╝', h: '═', v: '║', prefix: '║'}
    when :rounded  then {tl: '╭', tr: '╮', bl: '╰', br: '╯', h: '─', v: '│', prefix: '▌'}
    when :thick    then {tl: '┏', tr: '┓', bl: '┗', br: '┛', h: '━', v: '┃', prefix: '█'}
    else                {tl: '┌', tr: '┐', bl: '└', br: '┘', h: '─', v: '│', prefix: '▌'}
    end
  end
end

require "./ori/key"
require "./ori/mouse"
require "./ori/term"
require "./ori/color"
require "./ori/calendar"
require "./ori/input_parser"
require "./ori/s"
require "./ori/rect"
require "./ori/screen"
require "./ori/graphics"
require "./ori/node"
require "./ori/image_node"
require "./ori/canvas"
require "./ori/progress_bar"
require "./ori/spinner"
require "./ori/text_node"
require "./ori/input_node"
require "./ori/text_area"
require "./ori/table"
require "./ori/list"
require "./ori/viewport"
require "./ori/select"
require "./ori/file_picker"
require "./ori/paginator"
require "./ori/markdown_node"
require "./ori/sparkline"
require "./ori/tabs"
require "./ori/button"
require "./ori/checkbox"
require "./ori/tree"
require "./ori/slider"
require "./ori/radio"
require "./ori/toast"
require "./ori/help"
require "./ori/date_picker"
require "./ori/datetime_picker"
require "./ori/box"
require "./ori/layout"
require "./ori/renderer"
require "./ori/focus"
require "./ori/dsl"
require "./ori/app"
require "./ori/spring"
require "./ori/page"
require "./ori/test_harness"
require "./ori/harness"
