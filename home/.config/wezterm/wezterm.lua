local wezterm = require("wezterm")
local config = wezterm.config_builder()

config.color_scheme = "VisiBone (terminal.sexy)"
config.font_size = 12.0
config.window_decorations = "RESIZE"
config.warn_about_missing_glyphs = false
config.use_fancy_tab_bar = false
config.adjust_window_size_when_changing_font_size = false

config.max_fps = 240
config.animation_fps = 240

config.leader = { key = "q", mods = "CTRL", timeout_milliseconds = 1000 }
config.keys = {
    {
        mods = "LEADER",
        key = "t",
        action = wezterm.action.SpawnTab "CurrentPaneDomain",
    },
    {
        mods = "LEADER",
        key = "w",
        action = wezterm.action.CloseCurrentPane { confirm = false }
    },
    {
        mods = "LEADER|SHIFT",
        key = "|",
        action = wezterm.action.SplitHorizontal { domain = "CurrentPaneDomain" }
    },
    {
        mods = "LEADER",
        key = "-",
        action = wezterm.action.SplitVertical { domain = "CurrentPaneDomain" }
    },
    {
        mods = "LEADER",
        key = "LeftArrow",
        action = wezterm.action.ActivatePaneDirection "Left"
    },
    {
        mods = "LEADER",
        key = "DownArrow",
        action = wezterm.action.ActivatePaneDirection "Down"
    },
    {
        mods = "LEADER",
        key = "UpArrow",
        action = wezterm.action.ActivatePaneDirection "Up"
    },
    {
        mods = "LEADER",
        key = "RightArrow",
        action = wezterm.action.ActivatePaneDirection "Right"
    },
    {
        mods = "LEADER",
        key = "h",
        action = wezterm.action.AdjustPaneSize { "Left", 5 }
    },
    {
        mods = "LEADER",
        key = "j",
        action = wezterm.action.AdjustPaneSize { "Right", 5 }
    },
    {
        mods = "LEADER",
        key = "k",
        action = wezterm.action.AdjustPaneSize { "Up", 5 }
    },
    {
        mods = "LEADER",
        key = "l",
        action = wezterm.action.AdjustPaneSize { "Down", 5 }
    },
    {
        mods = "CTRL|SHIFT",
        key = "=",
        action = wezterm.action.IncreaseFontSize
    },
    {
        mods = "CTRL|SHIFT",
        key = "-",
        action = wezterm.action.DecreaseFontSize
    }
}

-- WSL needs an explicit default_prog that probes for zsh; on macOS the
-- default (the login shell) is already correct.
if wezterm.target_triple:find("windows") then
  config.wsl_domains = {
    {
      name = "WSL:Ubuntu",
      distribution = "Ubuntu",
      default_cwd = "~",
      default_prog = {
        "bash",
        "-c",
        'if command -v zsh >/dev/null 2>&1; then exec zsh -l; else exec "$SHELL" -l; fi',
      },
    },
  }
  config.default_domain = "WSL:Ubuntu"
end

wezterm.on("gui-startup", function(cmd)
  local screen = wezterm.gui.screens().active

  local ratio = 0.75
  local width = screen.width * ratio
  local height = screen.height * ratio

  local x = (screen.width - width) / 2
  local y = (screen.height - height) / 2

  local tab, pane, window = wezterm.mux.spawn_window({
    position = { x = x, y = y, origin = 'ActiveScreen' }
  })

  window:gui_window():set_inner_size(width, height)
end)

wezterm.on('update-right-status', function(window, pane)
  local leader = ''
  if window:leader_is_active() then
    leader = 'LEADER ACTIVE'
  end
  window:set_right_status(leader)
end)

return config
