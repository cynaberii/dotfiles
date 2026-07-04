local wezterm = require 'wezterm'
local config = {}

local WAL_PATH = wezterm.home_dir .. "/.cache/wal/colors-wezterm.lua"

-- Watch wal cache file so WezTerm reloads automatically when pywal runs
wezterm.add_to_config_reload_watch_list(WAL_PATH)

-- Helper: read the current pywal palette fresh from disk
local function load_wal_colors()
  local ok, wal = pcall(dofile, WAL_PATH)
  if ok and wal then
    return wal
  end
  -- fallback hardcoded palette if wal hasn't run yet
  return {
    background = '#2a1f1a',
    foreground = '#EFE7DC',
    cursor_bg  = '#C9B6A6',
    cursor_fg  = '#2a1f1a',
    ansi = {
      '#2a1f1a', '#85776E', '#B8C4B1', '#C9B6A6',
      '#9e8f85', '#C9B6A6', '#B8C4B1', '#EFE7DC',
    },
    brights = {
      '#4a3b34', '#9e8f85', '#cad4c5', '#d4c5b8',
      '#b8ada6', '#dce6d8', '#e0d4ca', '#f5f0ea',
    },
  }
end

-- Initial colors at startup / new pane
config.colors = load_wal_colors()

-- CRITICAL: on every config reload, push fresh colors to EXISTING windows.
-- Setting config.colors alone does not repaint already-open panes; using
-- set_config_overrides forces the live palette to update in place.
wezterm.on('window-config-reloaded', function(window, pane)
  local fresh = load_wal_colors()
  local overrides = window:get_config_overrides() or {}
  -- only update if the palette actually changed, to avoid reload loops
  local current = overrides.colors
  if not current or current.background ~= fresh.background then
    overrides.colors = fresh
    window:set_config_overrides(overrides)
  end
end)

config.window_close_confirmation = "NeverPrompt"
config.keys = {
  {
    key = 'q',
    mods = 'SUPER',
    action = wezterm.action.CloseCurrentPane { confirm = false },
  },
  -- Manual color refresh: Cmd+Shift+P re-reads pywal and applies it live
  {
    key = 'p',
    mods = 'SUPER|SHIFT',
    action = wezterm.action_callback(function(window, pane)
      local overrides = window:get_config_overrides() or {}
      overrides.colors = load_wal_colors()
      window:set_config_overrides(overrides)
    end),
  },
}

config.enable_tab_bar = false
config.window_decorations = "RESIZE"
config.window_background_opacity = 0.55
config.macos_window_background_blur = 20
config.font = wezterm.font("JetBrainsMono Nerd Font")
config.enable_kitty_graphics = true
config.adjust_window_size_when_changing_font_size = false

return config
