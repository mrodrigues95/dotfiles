local wezterm = require("wezterm")

local config = wezterm.config_builder()

config.color_scheme = "VisiBone (terminal.sexy)"
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

if wezterm.target_triple:find("darwin") then
  config.default_prog = { "/Users/mrodrigues/.nix-profile/bin/fish", "-l" }
elseif wezterm.target_triple:find("windows") then
  config.wsl_domains = {
    {
      name = "WSL:Ubuntu",
      distribution = "Ubuntu",
      default_cwd = "/home/mrodrigues",
      default_prog = { "/home/mrodrigues/.nix-profile/bin/fish", "-l" },
    },
  }
  config.default_domain = "WSL:Ubuntu"
end

return config
