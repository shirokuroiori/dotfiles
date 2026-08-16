-- Pull in the wezterm API
local wezterm = require 'wezterm'
-- マルチエージェント一覧（docs/plans/wezterm-multi-agent-spec.md）向けのハンドラ。
-- ペインジャンプと既読管理を持つ。format-tab-title からは is_dismissed() だけを
-- 呼ぶこと（テーブル参照のみ。ここに I/O を持ち込まない。仕様書 §3.2.1）。
local agents = require 'agents'
-- This will hold the configuration.
local config = wezterm.config_builder()

-- タブバー帯（ファンシータブの titlebar 下地）。colors/voltwave.toml の background / tab_bar.background と揃える
local tab_bar_strip_bg = "#200933"

-- ウィンドウ外周の枠線（window_frame）。現状 width 0 だが、voltwave の win_separator（split）に合わせておく
local frame_border_width = "0px"
local frame_border_color = "#8c57c7"

-- カスタムカラースキームの定義
config.color_schemes = require 'color_schemes'


config.default_cursor_style = 'SteadyBar'

-- For example, changing the initial geometry for new windows:
config.initial_cols = 150
config.initial_rows = 50


-- WebGpu はグリフ合成のガンマ補正が正しくなく、文字が太く・甘く描かれる。
-- 未解決の既知バグ: https://github.com/wezterm/wezterm/issues/3032
--   "WebGpu causes my fonts to render ... thick/bold. Setting OpenGL ... normal/thin again"
-- 縦ステムの実測（不透明・Bizin Gothic 16・nvim 全画面）:
--            実効幅    ピーク  中心画素の占有率  検出本数
--   Ghostty  1.732px   61.6    61.2%            464
--   WebGpu   1.854px   59.4    57.7%            311   ← Ghostty比 +7.0%
--   OpenGL   1.774px   58.2    59.4%            467   ← Ghostty比 +2.4%
-- OpenGL の方が Ghostty に近く、差の約2/3が消える。明示指定して既定値の変更に左右されないようにする。
-- ※ 絶対値は実行ごとに約2%ぶれる（nvim の表示内容で対象文字が変わるため）。
--   信頼できるのは同一実行内での比較のみ。上表は WebGpu と OpenGL を同一実行で測ったもの。
config.front_end = 'OpenGL'
-- webgpu_power_preference は WebGpu 専用。OpenGL では無意味なので無効化。
-- config.webgpu_power_preference = 'HighPerformance'

-- フォントのラスタライズ。WezTerm は macOS でも CoreText ではなく常に FreeType を使うため、
-- 既定のままだと Ghostty / ネイティブアプリ（CoreText）より字形が硬くなる。
-- 非Retina（1920x1080 @1x）ではこの差がそのまま「荒さ」として出るので CoreText 寄りに寄せる。
--
-- Light : 縦方向のみヒンティング。横のステム位置を歪めないので CoreText に一番近い
-- Normal(render_target) : グレースケールAA。HorizontalLcd はサブピクセルRGBで、
--                          暗背景＋高彩度の文字だと色フリンジが出てざらつく
-- 以前 HorizontalLcd で色フリンジが出たのは front_end = WebGpu だったため
-- （透過ウィンドウ上のサブピクセルAA には Dual Source Blending が要り、OpenGL のみ対応:
--  https://github.com/wezterm/wezterm/issues/932, /issues/3625）。
-- OpenGL でも実測すると HorizontalLcd は太くなるので Normal のまま。同一実行内の比較:
--   OpenGL + Normal         1.815px  中心占有 58.4%
--   OpenGL + HorizontalLcd  1.889px  中心占有 56.3%  ← 悪化
config.freetype_load_target = 'Light'
config.freetype_render_target = 'Normal'
-- 【実測メモ】この2つはこのフォントでは効果がない。スクリーンショットの画素差(255階調)で:
--   freetype_load_flags   MONOCHROME vs DEFAULT = 0.013  → 無効。AA無効すら効かない
--   interpreter_version   35 vs 40              = 0.014  → 無効
--   freetype_load_target  Light vs Normal       = 0.46   → 0.18%。測れるが視認不能
-- 触る意味があるのは load_target だけで、それも実質変わらない。
-- config.freetype_interpreter_version = 35
-- config.freetype_load_flags = 'NO_HINTING'
--
-- 【縦ステムの実測】不透明・同フォント・同サイズで比較(nvim 全画面, 300本以上):
--            実効幅    ピーク   中心画素の占有率
--   Ghostty  1.732px   61.6     61.2%
--   WezTerm  1.847px   59.2     57.8%
-- WezTerm の縦線は 7% 太く、やや甘い。設定では動かせず、FreeType と CoreText の差。
-- ※ 横棒(ハイフン)で測ると縦方向のヒンティングしか見えないため差が出ない。
--   太さの体感を確かめたいときは必ず縦ステムで測ること。

-- font size
-- Bizin Gothic の送り幅は em のちょうど 0.5 倍なので、セル幅 = font_size / 2。
-- 非Retina(1x) では font_size=15 だと 7.5px となり、列ごとにグリフが半ピクセルずれた
-- 位置に打たれて滲み方が変わる（＝文字ごとにガタついて見える）。偶数にして整数化する。
--   14 -> 7px / 15 -> 7.5px / 16 -> 8px  （wezterm ls-fonts --text 'A' で確認可）
config.font_size = 16
config.line_height = 1.0
-- 絵文字は WezTerm 内蔵の Noto Emoji に先にマッチしてしまい、macOS ネイティブアプリの
-- Apple Color Emoji と見た目が変わる。フォールバックの2番目に明示して優先させる。
config.font = wezterm.font_with_fallback({
  -- このファミリは Regular / Bold の2ウェイトのみ。weight=500 は Regular に丸められて
  -- 効かないので指定しない。1x で線を太らせたいなら weight = "Bold" にする。
  { family = "Bizin Gothic Discord NF" },
  { family = "Apple Color Emoji", scale = 2.0 },
})
-- 💡
-- ℹ️ ♻️ ⚠️ が ✅ より小さく見えるのは、これらが「基底文字 + U+FE0F(VS16)」の2コードポイント
-- 構成で、既定の unicode_version = 9 では VS16 付き絵文字列が 1セル幅と判定されるため。
-- 絵文字グリフが半分の幅に押し込まれていた。14 にすると 2セル幅になり ✅ と揃う。
--   ℹ️(U+2139 U+FE0F) / ♻️(U+267B U+FE0F) / ⚠️(U+26A0 U+FE0F) : cells 1 -> 2
--   ✅(U+2705) は単体で East Asian Width = Wide なので元から 2セル
-- unicode_version は端末全体の文字幅計算に効くため、罫線・ギリシャ文字・キリル文字・
-- 記号・丸数字など46文字で 9 と 14 を実測比較したが、変化したのは上記の VS16 付き3文字のみ。
config.unicode_version = 14

-- 【実測メモ】絵文字のサイズ調整は事実上「2択」しかない。
-- Apple Color Emoji はビットマップフォントで固定ストライクしか持たない
-- （[26,34,42,52,63,68,84,126,210]。wezterm ls-fonts が列挙する）。
-- そのため per-font の scale は非単調で、有効なのは 1.6 と 2.0 の2点だけ:
--   scale=0.5 / 0.8 / 1.0 / 1.2 / 1.4 / 1.5 / 1.55 -> 12.19px
--   scale=1.6                                      -> 18.72px
--   scale=1.7 / 1.8                                -> 12.19px  ← 1.6 より小さい
--   scale=2.0                                      -> 18.58px
--   scale=2.2                                      -> 12.19px
-- 中間の値は取れないので「気持ちだけ小さく」はできない。大きい方に戻すなら 2 にする。
--   （wezterm ls-fonts --text '✅' の x_adv で確認可）
--
-- allow_square_glyphs_to_overflow_width は効果なし（'Never' を試したが見た目が変わらない）。
-- 絵文字は元から 2セル内に収まっており、はみ出していないため。
-- ls-fonts の x_adv は Never / WhenFollowedBySpace で同じ 18.58 を報告し、
-- cell_width の影響も現れない。つまり x_adv は描画幅ではなくフォント側のメトリック。
-- この系統の設定は ls-fonts では検証できないので、必ず目視で確認すること。

config.max_fps = 120
-- 逆にセル側を広げる方向（8px -> 9px）。絵文字は相対的に小さく見えるが、
-- 全カラムが 12.5% 広がって initial_cols=150 だと窓幅 1200px -> 1350px になる。
-- config.cell_width = 1.125
-- ✅✨🍣♻️ℹ️♻️♻️♻️♻️♻️♻️
--       aaaaaaaaaaaaaaa♻️aaa
-- color schema
config.color_scheme = "voltwave"
config.window_background_opacity = 0.75

-- macOS の背景ブラーは「文字のコントラストを削る」最大の要因。実測（ハイフンのピーク強度）:
--   不透明                 81.8  (Ghostty 不透明 = 80.8 とほぼ同じ)
--   opacity 0.75 / blur 0  89.2  ← 透過のまま最もシャープ
--   opacity 0.75 / blur 25 57.5  ← 30% 失う
-- ブラーは二値的で、5 以上はどの値でも 57.5 で変わらない（半径を下げても無意味）。
-- Ghostty がシャープに見えていた主因はこれ（不透明で動いていたため）。
-- ただしブラーを切っても縦ステムに 7% の差は残る（上記）。そちらは設定では消せない。
-- 「すりガラス」感が欲しくなったら 20〜25 に戻す。
config.macos_window_background_blur = 5

-- 背景画像（未指定だと反映されない）。
-- wezterm.config_dir は「設定ファイルを置いたディレクトリ」（例: ~/.config/wezterm）。
-- wezterm.lua だけシンボリックリンクしている場合は、そのディレクトリに space-city.png も置くかリンクすること。
-- config.window_background_image = wezterm.config_dir .. '/space-city.png'
-- 暗すぎ／明るすぎるときは 0.0〜1.0 で調整
-- config.window_background_image_hsb = { brightness = 0.35, hue = 1.0, saturation = 1.0 }




-- ファンシータブバー（既定）の「タブ列全体の下地」は window_frame の titlebar_bg。
-- voltwave では tab_bar_strip_bg をスキームの bg と同一にし、タブ列〜タイトルバーまで色を連続させる。
-- "none" だと window_background_opacity がそのまま効き、壁紙がタブ裏に透ける。
-- 不透過の実色を指定するとペインだけ透過・タブ帯は不透明にできる。

-- macOS の角丸＋透過では、内側の描画が矩形のままなので角に隙間が出ることがある。枠線を付けるとそこがやや目立つ場合あり。
config.window_frame = {
  border_left_width = frame_border_width,
  border_right_width = frame_border_width,
  border_bottom_height = frame_border_width,
  border_top_height = frame_border_width,
  border_left_color = frame_border_color,
  border_right_color = frame_border_color,
  border_top_color = frame_border_color,
  border_bottom_color = frame_border_color,

  active_titlebar_bg = tab_bar_strip_bg,
  inactive_titlebar_bg = tab_bar_strip_bg,
  active_titlebar_border_bottom = tab_bar_strip_bg,
  inactive_titlebar_border_bottom = tab_bar_strip_bg,
}

-- 透明度 < 1 のとき WezTerm は既定でウィンドウ影を切る。影があると縁が「浮いて」見えやすい。
config.window_decorations = "RESIZE | MACOS_FORCE_ENABLE_SHADOW"


-- retro tab bar にすると colors/voltwave.toml の [colors.tab_bar] が反映される
config.use_fancy_tab_bar = false

-- タブの追加ボタンを非表示
config.show_new_tab_button_in_tab_bar = false

-- 角丸の内側にグリッドを収める＋タブバー左端の余裕。
-- bottom は 0 にして Neovim のステータスラインと下枠の間の「空き帯」を減らす。
config.window_padding = {
  left = '0.85cell',
  right = '0.85cell',
  top = '0.55cell',
  bottom = 0,
}

-- ウィンドウ高さがセル＋padding の倍数でないと、最下行の下に背景色の細い帯が残ることがある。
-- macOS では true でリサイズをセル単位に寄せる（20240127 以降は padding も考慮）。
config.use_resize_increments = true

config.tab_bar_at_bottom = true

-- ime
config.use_ime = true

-- Cmd 等の修飾キーを nvim から識別できるように kitty keyboard protocol を有効化
config.enable_kitty_keyboard = true



-- smart-splits.nvim keymaps
config.keys = require 'keys'

-- 検索モードを Esc で抜けてもパターンがペインに残り、次にコピーモードへ入ると
-- 検索プロンプト付きのオーバーレイが開いてしまう。Esc で破棄してから閉じる。
-- wezterm.gui は GUI プロセスでのみ存在する（mux サーバや wezterm cli の評価文脈では nil）。
if wezterm.gui then
  local key_tables = wezterm.gui.default_key_tables()
  local search_mode = {}
  for _, mapping in ipairs(key_tables.search_mode) do
    if mapping.key ~= 'Escape' then
      table.insert(search_mode, mapping)
    end
  end
  table.insert(search_mode, {
    key = 'Escape',
    mods = 'NONE',
    action = wezterm.action.Multiple {
      wezterm.action.CopyMode 'ClearPattern',
      wezterm.action.CopyMode 'Close',
    },
  })
  key_tables.search_mode = search_mode
  config.key_tables = key_tables
end

-- smart-splits.nvim との連携。Ctrl+hjkl / Alt+hjkl を nvim 内なら送出、
-- wezterm シェルペインなら ActivatePaneDirection / AdjustPaneSize に自動分岐する。
local smart_splits = wezterm.plugin.require 'https://github.com/mrjones2014/smart-splits.nvim'
smart_splits.apply_to_config(config, {
  direction_keys = { 'h', 'j', 'k', 'l' },
  modifiers = { move = 'CTRL', resize = 'META' },
})


-- タブ配色。voltwave.toml の [colors.tab_bar] active_tab/inactive_tab と同じ値。
local TAB_ACTIVE_BG   = '#2A1340'
local TAB_INACTIVE_BG = '#241B2F'
local TAB_ACTIVE_FG   = '#72F1B8'
local TAB_INACTIVE_FG = '#6B7A8F'
local TAB_ACCENT      = '#38daff' -- voltwave ansi cyan

-- ステータス色を付けたタブでも「選択中かどうか」が分かるように。
-- 背景差だけでは彩度の強いステータス色に負けて見分けづらく、retro tab bar
-- では Underline 属性も効かなかったため、選択中タブの左端に nf-fa-hand_o_right
-- を「枠線」代わりに立てて明示する。通常タブにも共通で適用する。
--
-- fgを省略すると通常タブと同じ配色（選択中=TAB_ACTIVE_FG／非選択=TAB_INACTIVE_FG）になる。
local function tab_elements(tab_is_active, text, fg)
  local bg = tab_is_active and TAB_ACTIVE_BG or TAB_INACTIVE_BG
  fg = fg or (tab_is_active and TAB_ACTIVE_FG or TAB_INACTIVE_FG)
  local elements = { { Background = { Color = bg } } }
  if tab_is_active then
    table.insert(elements, { Foreground = { Color = TAB_ACCENT } })
    table.insert(elements, { Text = ' \u{f0a4}' }) -- nf-fa-hand_o_right
    table.insert(elements, { Background = { Color = bg } })
  end
  table.insert(elements, { Foreground = { Color = fg } })
  table.insert(elements, { Text = text })
  return elements
end

-- Copilot CLIはtitleにthinkingスピナーを出さない代わりに、画面最終行に
-- "◉ Working ..." のようなステータス行を描画する。get_lines_as_text(1)は
-- 最下1行だけを返す（実測確認済み）ので、毎描画呼んでもコストは軽い。
-- 後ろのテキストは固定ではなく、skill実行中は "◉ [plan/step Loop 1/3]" の
-- ように変わる（実機で確認済み）。"Working"という文字列ではなく、先頭の
-- 円形マーカーの有無で判定する。0.1秒間隔で80サンプル実測したところ、
-- ○ ◎ ◉ ● の4フレームを回転するスピナーだった（円が満ちていくアニメーション）。
-- ▄▀などの罫線ブロック文字(U+2580-259F)とはUTF-8の2バイト目が異なる
-- (E2 96 vs E2 97)ため、アイドル時の枠線行を誤検知する心配はない。
-- 許可待ち・中断・完了はどれもこの行が消えるだけで区別できないため、
-- waiting/doneは引き続きhookに任せ、working（今動いているか）だけをこれで見る。
local COPILOT_SPINNER_FRAMES = { '○', '◎', '◉', '●' }
local function copilot_is_working(pane_id)
  local ok, mp = pcall(wezterm.mux.get_pane, pane_id)
  if not ok or not mp then
    return false
  end
  local ok2, last_line = pcall(function() return mp:get_lines_as_text(1) end)
  if not ok2 or not last_line then
    return false
  end
  for _, frame in ipairs(COPILOT_SPINNER_FRAMES) do
    if last_line:find(frame, 1, true) then
      return true
    end
  end
  return false
end

-- タブタイトル: アイコン + 末尾ディレクトリ名
wezterm.on('format-tab-title', function(tab, tabs, panes, config, hover, max_width)
  local pane = tab.active_pane

  local cwd = ''
  if pane.current_working_dir then
    local path = pane.current_working_dir.file_path
    cwd = path:match('[^/]+/?$') or path
    cwd = cwd:gsub('/$', '')
  end

  local process = pane.foreground_process_name:match('[^/]+$') or ''
  local pane_title = (pane.title or ''):lower()
  local icons = {
    nvim    = ' ',
    vim     = ' ',
    zsh     = '  ',
    bash    = '  ',
    ssh     = '󰣀 ',
    git     = '󰊢 ',
    lazygit = '󰊢 ',
    claude  = '󱚤 ',
    node    = ' ',
  }

  local icon = icons[process] or '  '
  if process == 'node' and pane_title:find('copilot', 1, true) then
    icon = '  '
  end

  local title = string.format(' %d. %s%s ', tab.tab_index + 1, icon, cwd)

  -- Claude Code / GitHub Copilot CLI の状態表示。
  -- working（思考中）はどちらもhooksを使わず、エージェント自身が画面に出す
  -- 合図の有無を毎描画チェックする方式（Claudeはtitleの点字スピナー、
  -- Copilotは最終行の"Working"表示）。hookに頼らないので、Esc中断のような
  -- 「終了系hookが一切発火しないケース」でも合図が消えた瞬間に追従できる。
  --
  -- waiting/doneは画面上に現れない状態（許可待ち・応答完了）なので、
  -- 引き続きhooks経由でOSC 1337 SetUserVarに書き込まれた値を見る。
  local user_var_key, status_colors
  local has_copilot_status = pane.user_vars and pane.user_vars.copilot_status ~= nil
  if process == 'claude' then
    user_var_key = 'claude_status'
    status_colors = { waiting = '#FE4450', done = '#50fa7b' } -- voltwave red/green
  elseif has_copilot_status or process == 'copilot' or process == 'copilot-cli' or (process == 'node' and pane_title:find('copilot', 1, true)) then
    user_var_key = 'copilot_status'
    status_colors = { waiting = '#FE4450', done = '#50fa7b' } -- voltwave red/green
  end

  if user_var_key then
    local raw_title = pane.title or ''
    local b1, b2, b3 = raw_title:byte(1, 3)
    -- 点字スピナー U+2800-28FF（旧Claude Code）。このブロックは2バイト目
    -- (A0-A3)だけで全256コードポイントを覆うので3バイト目は見なくてよい。
    local is_thinking = b1 == 0xE2 and b2 and b2 >= 0xA0 and b2 <= 0xA3
    -- 円形スピナー ◐◓◑◒ = U+25D0-25D3（現行Claude Code、2.1.233で確認）。
    -- 実行ファイル中の frame 定義 `["◐","◓","◑","◒"]` より。
    -- 同じUTF-8 2バイト目(97)を使う他の記号（●U+25CF等、別UIの状態アイコン）
    -- と誤検知しないよう3バイト目まで絞る。
    if not is_thinking then
      is_thinking = b1 == 0xE2 and b2 == 0x97 and b3 and b3 >= 0x90 and b3 <= 0x93
    end
    if not is_thinking and user_var_key == 'copilot_status' then
      is_thinking = copilot_is_working(pane.pane_id)
    end

    if is_thinking then
      local working_title = string.format(' %d. %s🤔 %s ', tab.tab_index + 1, icon, cwd)
      return tab_elements(tab.is_active, working_title, '#FFCC00') -- voltwave ansi yellow
    end

    if pane.user_vars then
      local status = pane.user_vars[user_var_key]
      -- 既読になった done は idle 扱いにして通常色へ戻す（仕様書 §3）。
      -- waiting は「実際に入力を求められている」状態なので、既読でも赤を維持する。
      if status == 'done' and agents.is_dismissed(pane.pane_id) then
        status = nil
      end
      local status_color = status_colors[status]
      if status_color then
        -- 選択中タブは指マーク(nf-fa-hand_o_right)で区別できるので、
        -- 非選択タブの減彩はもう不要。両方フル彩度のステータス色でよい。
        return tab_elements(tab.is_active, title, status_color)
      end
    end
  end

  return tab_elements(tab.is_active, title)
end)

-- claude_status/copilot_status に応じたベル通知。wezterm-notify.sh が
-- waiting/done のときだけ BEL を送ってくるので、そのままトーストとして出す
-- （working では鳴らさない）。
config.audible_bell = 'Disabled'

wezterm.on('bell', function(window, pane)
  local status_messages = {
    waiting = '承認/入力待ちです',
    done    = '応答が完了しました',
  }
  local user_vars = pane:get_user_vars()
  local label, status
  if user_vars.claude_status then
    label, status = 'Claude Code', user_vars.claude_status
  elseif user_vars.copilot_status then
    label, status = 'Copilot CLI', user_vars.copilot_status
  else
    return
  end

  local message = status_messages[status]
  if not message then
    return
  end

  local cwd_uri = pane:get_current_working_dir()
  local cwd = cwd_uri and (cwd_uri.file_path:match('[^/]+/?$') or '') or ''

  window:toast_notification(label .. ': ' .. cwd, message, nil, 5000)
end)

-- Finally, return the configuration to wezterm:
return config
