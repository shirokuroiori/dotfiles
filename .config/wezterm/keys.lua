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

  -- 分割（"\" = 縦棒で横方向に分割、"-" で縦方向に分割）
  -- phys: 指定でキーボードレイアウト/kitty_keyboard プロトコルの揺れを回避
  {
    key = 'phys:Backslash',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' },
  },
  {
    key = 'phys:Minus',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' },
  },

  -- 現在ペインを閉じる
  {
    key = 'w',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.CloseCurrentPane { confirm = true },
  },

  -- ペインの並び替え（時計回り / 反時計回り）
  -- 反時計回りは Ctrl+Alt+Shift+r（mods に SHIFT を入れる時は key を小文字のままにする）
  {
    key = 'r',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.RotatePanes 'Clockwise',
  },
  {
    key = 'r',
    mods = 'CTRL|ALT|SHIFT',
    action = wezterm.action.RotatePanes 'CounterClockwise',
  },

  -- 番号オーバーレイで選んだペインと現在ペインをスワップ
  {
    key = 's',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.PaneSelect { mode = 'SwapWithActive' },
  },

  -- 番号オーバーレイで選んだペインにフォーカスをワープ
  {
    key = 'p',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.PaneSelect { mode = 'Activate' },
  },

  -- コピーモード（デフォルトは選択モードが残ったまま入るため、
  -- 入った直後に ClearSelectionMode して「選択なしで閲覧」から始める）
  -- v: 文字選択 / V: 行選択 / y: コピーして抜ける / q, Esc: 抜ける
  {
    key = 'x',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.Multiple {
      wezterm.action.ActivateCopyMode,
      wezterm.action.CopyMode 'ClearPattern',
      wezterm.action.CopyMode 'ClearSelectionMode',
    },
  },
}