-- Pull in the wezterm API
local wezterm = require 'wezterm'
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

-- font size
config.font_size = 16
config.line_height = 1.1
config.font = wezterm.font("Bizin Gothic Discord NF", { weight = 600 })
-- config.font = wezterm.font("RictyDiminishedDiscord Nerd Font", { weight = 600 })
-- config.font = wezterm.font("HackGen Console NF", { weight = 600 })


-- color schema
config.color_scheme = "voltwave"

config.window_background_opacity = 0.75
-- 大きいほど壁紙がにじむ「すりガラス」感が強くなる（1枚目の雰囲気に寄せるなら 20 前後から調整）
config.macos_window_background_blur = 25

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



-- smart-splits.nvim keymaps
config.keys = require 'keys'


-- Finally, return the configuration to wezterm:
return config
