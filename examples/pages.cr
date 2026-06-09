require "../src/ori"

BG = "#1e1e2e"; DM = "#6c7086"; MAUVE = "#cba6f7"; GREEN = "#a6e3a1"

class MainPage < Ori::Page
  def render : Ori::Box
    box bg: BG, padding: {1, 2} do
      text "Main Page", bold: true, fg: MAUVE
      text ""
      button label: "Delete file", variant: :danger, focusable: true,
        on_press: -> { app.push_page(ConfirmPage.new(app)) }
      text ""
      text "ctrl+c: quit", fg: DM
    end
  end

  def bindings : Hash(String, String)
    {"enter" => "open confirm dialog"}
  end
end

class ConfirmPage < Ori::Page
  def render : Ori::Box
    box bg: BG, padding: {2, 4} do
      text "Are you sure?", bold: true, fg: "#f38ba8"
      text "This action cannot be undone.", fg: DM
      text ""
      box direction: :horizontal, spacing: 2 do
        button label: "Yes, delete", variant: :danger, focusable: true,
          on_press: -> { puts "DELETED!"; app.pop_page }
        button label: "Cancel", variant: :default, focusable: true,
          on_press: -> { app.pop_page }
      end
    end
  end

  def bindings : Hash(String, String)
    {"tab" => "choose yes/no", "enter" => "confirm selection"}
  end

  def on_enter : Nil
    @focus.focus_first
  end
end

class PagesApp < Ori::App
  def initialize
    super
    push_page(MainPage.new(self))
  end
end

PagesApp.run
