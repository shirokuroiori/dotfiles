local wezterm = require 'wezterm'

-- smart-splits.nvim 以外のキーバインドはここに置く。
-- Ctrl+hjkl（移動）/ Alt+hjkl（リサイズ）は wezterm.lua 側で
-- smart-splits の wezterm plugin に委譲している。
return {
  -- ペインのズームトグル（全画面↔分割）
  {
    key = 'z',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.TogglePaneZoomState,
  },
}