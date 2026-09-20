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

  -- エージェント一覧（docs/plans/wezterm-multi-agent-spec.md §4.6）。
  -- 現在のウィンドウに新規タブでランチャーを開く。選んでジャンプすると
  -- TUI が終了し、このタブも一緒に閉じる。
  -- 常駐で眺めたいときは `wezterm-agents --watch` を直接叩く。
  --
  -- 呼び出し元ペインのIDを WEZTERM_AGENTS_ORIGIN_PANE として渡す。
  -- Esc/q で何も選ばずに閉じたとき、wezterm-agents 側がこれを見て
  -- 呼び出し元ペインへジャンプしてから終了する（app.rs の quit() 参照）。
  -- これが無いと、タブを閉じたときの既定のフォーカス移動先（右隣のタブ）に
  -- 行ってしまい、cmd+shift+a を押す前にいたタブへ戻れない。
  {
    key = 'a',
    mods = 'CMD|SHIFT',
    action = wezterm.action_callback(function(window, pane)
      -- すでにランチャーのタブが開いていたら、新しく開かずにそこへ移動する。
      -- mux 全体を走査して wezterm-agents を前面プロセスに持つペインを探す。
      for _, mux_win in ipairs(wezterm.mux.all_windows()) do
        for _, mux_tab in ipairs(mux_win:tabs()) do
          for _, mux_pane in ipairs(mux_tab:panes()) do
            local ok, name = pcall(function()
              return mux_pane:get_foreground_process_name()
            end)
            if ok and name and name:match('wezterm%-agents$') then
              pcall(function() mux_tab:activate() end)
              pcall(function() mux_pane:activate() end)
              local gok, gui_win = pcall(function() return mux_win:gui_window() end)
              if gok and gui_win then
                pcall(function() gui_win:focus() end)
              end
              return
            end
          end
        end
      end

      window:perform_action(
        wezterm.action.SpawnCommandInNewTab {
          args = { os.getenv('HOME') .. '/.local/bin/wezterm-agents' },
          set_environment_variables = {
            WEZTERM_AGENTS_ORIGIN_PANE = tostring(pane:pane_id()),
          },
        },
        pane
      )
    end),
  },

  -- workspace一覧をfuzzy検索で表示（docs/wezterm-ai-agent-ideas.md §6）。
  -- 選ぶとそのworkspaceに属するWindow群だけが手前に表示される。
  {
    key = 'p',
    mods = 'CMD|SHIFT',
    action = wezterm.action.ShowLauncherArgs { flags = 'FUZZY|WORKSPACES' },
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