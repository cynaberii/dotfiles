require("full-border"):setup()

Header:children_add(function()
  return ui.Span("  yazi"):style(ui.Style():fg("#F0A9C7"):bold())
end, 500, Header.LEFT)
