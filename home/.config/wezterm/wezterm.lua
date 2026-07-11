local wezterm = require("wezterm")

local config = wezterm.config_builder()

config.color_scheme = "VisiBone (terminal.sexy)"
config.font_size = 12.0
config.hide_tab_bar_if_only_one_tab = true
config.window_decorations = "RESIZE"
config.warn_about_missing_glyphs = false
config.animation_fps = 120

config.keys = {
  { key = "d", mods = "CTRL", action = wezterm.action.SplitHorizontal { domain = "CurrentPaneDomain" } },
  { key = "d", mods = "CTRL|SHIFT", action = wezterm.action.SplitVertical { domain = "CurrentPaneDomain" } },
}

-- set fish as the default shell
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

-- set terminal size and position
wezterm.on("gui-startup", function(cmd)
  local screen = wezterm.gui.screens().active
  
  local ratio = 0.5
  local width = screen.width * ratio
  local height = screen.height * ratio
  
  local x = (screen.width - width) / 2
  local y = (screen.height - height) / 2
  
  local tab, pane, window = wezterm.mux.spawn_window({
    position = { x = x, y = y, origin = 'ActiveScreen' }
  })
  
  window:gui_window():set_inner_size(width, height)
end)

config.keys = {
  { key = "d", mods = "CTRL", action = wezterm.action.SplitHorizontal { domain = "CurrentPaneDomain" } },
  { key = "d", mods = "CTRL|SHIFT", action = wezterm.action.SplitVertical { domain = "CurrentPaneDomain" } },
}

return config
