local wezterm = require 'wezterm'

return {
  -- Ctrl+h/j/k/l でウィンドウ間移動
  {
    key = "h",
    mods = "CTRL",
    action = wezterm.action.SendKey { key = "h", mods = "CTRL" },
  },
  {
    key = "j",
    mods = "CTRL",
    action = wezterm.action.SendKey { key = "j", mods = "CTRL" },
  },
  {
    key = "k",
    mods = "CTRL",
    action = wezterm.action.SendKey { key = "k", mods = "CTRL" },
  },
  {
    key = "l",
    mods = "CTRL",
    action = wezterm.action.SendKey { key = "l", mods = "CTRL" },
  },
  -- Alt+h/j/k/l でリサイズ
  {
    key = "h",
    mods = "ALT",
    action = wezterm.action.SendKey { key = "h", mods = "ALT" },
  },
  {
    key = "j",
    mods = "ALT",
    action = wezterm.action.SendKey { key = "j", mods = "ALT" },
  },
  {
    key = "k",
    mods = "ALT",
    action = wezterm.action.SendKey { key = "k", mods = "ALT" },
  },
  {
    key = "l",
    mods = "ALT",
    action = wezterm.action.SendKey { key = "l", mods = "ALT" },
  },
  -- hjklでペインの移動
  {
    key = 'h',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.ActivatePaneDirection 'Left',
  },
  {
    key = 'j',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.ActivatePaneDirection 'Down',
  },
  {
    key = 'k',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.ActivatePaneDirection 'Up',
  },
  {
    key = 'l',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.ActivatePaneDirection 'Right',
  },
  -- hjklでペイン境界の調整
  {
    key = 'h',
    mods = 'ALT|SHIFT',
    action = wezterm.action.AdjustPaneSize { 'Left', 1 },
  },
  {
    key = 'j',
    mods = 'ALT|SHIFT',
    action = wezterm.action.AdjustPaneSize { 'Down', 1 },
  },
  {
    key = 'k',
    mods = 'ALT|SHIFT',
    action = wezterm.action.AdjustPaneSize { 'Up', 1 },
  },
  {
    key = 'l',
    mods = 'ALT|SHIFT',
    action = wezterm.action.AdjustPaneSize { 'Right', 1 },
  },
}
