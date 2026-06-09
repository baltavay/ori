# A Page is a self-contained view with its own widget tree,
# focus manager, bindings, and lifecycle hooks.
#
# Apps push/pop pages onto a stack. Only the top page receives
# keyboard events and renders.
#
# Usage:
#   class MainPage < Ori::Page
#     def render : Ori::Box
#       box { button "Go", on_press: -> { app.push_page(ConfirmPage.new(app)) } }
#     end
#     def bindings; {"q" => "quit"}; end
#   end
class Ori::Page
  include Ori::DSL

  getter focus : Ori::FocusManager
  getter root : Ori::Box?
  getter app : Ori::App

  def initialize(@app : Ori::App)
    @focus = Ori::FocusManager.new
    @root = nil
  end

  def render : Ori::Box
    box {}
  end

  def bindings : Hash(String, String)
    {} of String => String
  end

  def on_key(key : Ori::Key) : Bool
    false
  end

  def on_enter : Nil
  end

  def on_exit : Nil
  end
end
