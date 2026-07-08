local wezterm = require("wezterm")

local config = wezterm.config_builder()

config.color_scheme = "rose-pine-moon"
config.font = wezterm.font_with_fallback({
  "Hack Nerd Font",
  "JetBrains Mono Nerd Font",
  "FiraCode Nerd Font",
  "Menlo",
  "Consolas",
  "monospace",
})
config.font_size = 12.0
config.hide_tab_bar_if_only_one_tab = true
config.window_decorations = "RESIZE"
config.warn_about_missing_glyphs = false

return config
