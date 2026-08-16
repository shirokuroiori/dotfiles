-- マルチエージェント一覧（docs/plans/wezterm-multi-agent-spec.md）向けの
-- WezTerm 側ハンドラ。役割は2つ。
--
-- 1. ペインジャンプ
--    TUI が OSC 1337 SetUserVar=wezterm_agents_jump=<pane_id> を送ると、
--    ここで受けて対象ペインへフォーカスを移す。
--    これは `wezterm cli activate-pane` が別ネイティブウィンドウを前面に
--    出せない既知バグ（https://github.com/wezterm/wezterm/issues/5536）の
--    ワークアラウンドでもある。バグは `wezterm cli` 経路に固有で、
--    GUI プロセス内の gui_window:focus() は影響を受けない。実測で別ウィンドウの
--    前面化に成功することを確認済み（102ms。対照実験では cli 経路は
--    フォーカスイベントすら発生しなかった）。詳細は仕様書 §9.1。
--
-- 2. 既読管理（仕様書 §3）
--    「応答完了(done)の緑タブは、そのタブを見たら通常色に戻る」を実現する。
--    user var は Lua から削除できないため、値を消すのではなく
--    「既読フラグ」を持って format-tab-title の描画時に上書き判定する。
--
-- 【実装上の必須制約】format-tab-title はタブバーの再描画のたびに、タブの数だけ、
-- GUI のレンダースレッド上で呼ばれる。そこからは M.is_dismissed()（テーブル
-- 参照のみ）だけを呼ぶこと。ファイル I/O を持ち込むと端末全体の描画が
-- ディスクに引きずられる。詳細と責務分担の表は仕様書 §3.2.1。
--
-- DEBUG = true にすると各ステップの成否を /tmp/wezterm-agents-spike.log に残す。
-- 切り分け用で通常は false。
local wezterm = require 'wezterm'

local M = {}

local DEBUG = false
local SPIKE_LOG = '/tmp/wezterm-agents-spike.log'
local STATUS_DIR = '/tmp/wezterm-agent-status'

local function log(fmt, ...)
  if not DEBUG then
    return
  end
  local ok, msg = pcall(string.format, fmt, ...)
  if not ok then
    msg = tostring(fmt)
  end
  pcall(function()
    local f = io.open(SPIKE_LOG, 'a')
    if not f then
      return
    end
    f:write(os.date('%H:%M:%S') .. ' ' .. msg .. '\n')
    f:close()
  end)
end

-- hook 側の `date -Iseconds` と同じ書式に揃える。
-- os.date('%z') は "+0900" とコロン無しで返すので補う。
-- .read と .jsonl の時刻は文字列比較するため、書式を一致させておく必要がある。
local function rfc3339(t)
  local z = os.date('%z', t)
  return os.date('%Y-%m-%dT%H:%M:%S', t) .. z:sub(1, 3) .. ':' .. z:sub(4, 5)
end

local function read_file(path)
  local ok, body = pcall(function()
    local f = io.open(path, 'r')
    if not f then
      return nil
    end
    local content = f:read('a')
    f:close()
    return content
  end)
  return ok and body or nil
end

local function write_file(path, body)
  pcall(function()
    local f = io.open(path, 'w')
    if not f then
      return
    end
    f:write(body)
    f:close()
  end)
end

--------------------------------------------------------------------------
-- 既読管理
--------------------------------------------------------------------------

-- dismissed[pane_id] = true なら「そのペインの done は既読」。
-- GUI プロセスのメモリ上にだけ持つ。
local dismissed = {}

-- window_id -> 直近に観測したアクティブ pane_id。
-- update-status は約1秒ごとに発火するので、変化したときだけ書き込むための差分用。
local last_active = {}

-- format-tab-title から呼ばれる唯一の関数。テーブル参照のみ。
function M.is_dismissed(pane_id)
  return dismissed[pane_id] == true
end

local function mark_read(pane_id)
  dismissed[pane_id] = true
  write_file(STATUS_DIR .. '/' .. pane_id .. '.read', rfc3339(os.time()))
end

-- 設定をリロードすると Lua state ごと dismissed が消えるが、ペインは生き残る。
-- そのままだと既読にしたはずのタブが一斉に緑へ戻るので、.read と .jsonl の
-- 最終イベント時刻を突き合わせて復元する。
-- （WezTerm 本体の再起動ではペインごと消えて pane_id も振り直されるため、
--  これが効くのは実質「設定リロード」のケース）
-- 起動時に1回だけ実行する。
local function restore_dismissed()
  local ok, paths = pcall(wezterm.glob, STATUS_DIR .. '/*.read')
  if not ok or type(paths) ~= 'table' then
    return
  end
  local restored = 0
  for _, read_path in ipairs(paths) do
    local pane_id = tonumber(tostring(read_path):match('(%d+)%.read$'))
    if pane_id then
      local read_at = (read_file(read_path) or ''):gsub('%s+$', '')
      local last_at
      local jsonl = read_file(STATUS_DIR .. '/' .. pane_id .. '.jsonl')
      if jsonl then
        for line in jsonl:gmatch('[^\n]+') do
          local at = line:match('"at"%s*:%s*"([^"]+)"')
          if at then
            last_at = at
          end
        end
      end
      -- 通知が無い、または最後の通知より既読の方が新しければ既読
      if read_at ~= '' and (last_at == nil or read_at >= last_at) then
        dismissed[pane_id] = true
        restored = restored + 1
      end
    end
  end
  log('restore_dismissed: %d panes', restored)
end

--------------------------------------------------------------------------
-- ペインジャンプ
--------------------------------------------------------------------------

-- mux 全体を走査して pane_id から {pane, tab, window} を引く。
local function find_pane(target_id)
  for _, mux_win in ipairs(wezterm.mux.all_windows()) do
    for _, mux_tab in ipairs(mux_win:tabs()) do
      for _, mux_pane in ipairs(mux_tab:panes()) do
        if mux_pane:pane_id() == target_id then
          return mux_pane, mux_tab, mux_win
        end
      end
    end
  end
  return nil, nil, nil
end

-- 各ステップを個別に pcall する。どれが落ちたかを切り分けたいため。
local function step(name, fn)
  local ok, err = pcall(fn)
  log('  %-18s %s', name, ok and 'ok' or ('FAILED: ' .. tostring(err)))
  return ok
end

local function handle_jump(value)
  log('jump: value=%q', tostring(value))

  -- 値は pane_id。実測で user-var-changed は「同じ値の再設定」でも発火すると
  -- 分かっているので、連投用の nonce は要らない（仕様書 §9.3）。
  -- 古い形式 "<pane_id>:<nonce>" も受けられるよう先頭の数字だけを見る。
  local target_id = tonumber(tostring(value):match('^(%d+)'))
  if not target_id then
    log('  parse failed')
    return
  end

  local mux_pane, mux_tab, mux_win = find_pane(target_id)
  if not mux_pane then
    log('  pane %d not found', target_id)
    return
  end
  log('  target pane=%d tab=%d window=%d',
    target_id, mux_tab:tab_id(), mux_win:window_id())

  step('tab:activate', function() mux_tab:activate() end)
  step('pane:activate', function() mux_pane:activate() end)

  local gui_win
  step('mux:gui_window', function() gui_win = mux_win:gui_window() end)
  if gui_win then
    step('gui_window:focus', function() gui_win:focus() end)
  else
    log('  gui_window is nil (そのウィンドウに GUI が無い)')
  end

  -- 切り分け用: WezTerm 自身が「どのウィンドウがフォーカス中か」をどう
  -- 認識しているかを見る。focus() は即時反映されない可能性があるので
  -- 0.5秒後にも取る。
  if DEBUG then
    local function dump(when)
      local ok, wins = pcall(wezterm.gui.gui_windows)
      if not ok or type(wins) ~= 'table' then
        log('  [%s] gui_windows 取得失敗', when)
        return
      end
      for _, w in ipairs(wins) do
        local okf, focused = pcall(function() return w:is_focused() end)
        local oki, wid = pcall(function() return w:window_id() end)
        log('  [%s] window %s is_focused=%s', when,
          oki and tostring(wid) or '?', okf and tostring(focused) or '?')
      end
    end
    dump('直後')
    pcall(wezterm.time.call_after, 0.5, function() dump('0.5秒後') end)
  end
end

--------------------------------------------------------------------------
-- イベント登録
--------------------------------------------------------------------------

local STATUS_VARS = {
  claude_status = true,
  copilot_status = true,
}

wezterm.on('user-var-changed', function(window, pane, name, value)
  if name == 'wezterm_agents_jump' then
    handle_jump(value)
    return
  end
  if not STATUS_VARS[name] then
    return
  end
  -- working は緑にならないので既読管理の対象外
  if value == 'working' then
    return
  end

  local pane_id = pane:pane_id()

  -- 見ている最中に届いた通知は、その場で既読にする。
  -- そうしないと update-status の次のティックまで最大1秒間、
  -- 目の前のタブが無意味に緑く光る（仕様書 §3.3 の受け入れ条件4）。
  local watching = false
  pcall(function()
    watching = window:is_focused()
      and window:active_pane():pane_id() == pane_id
  end)

  if watching then
    mark_read(pane_id)
  else
    dismissed[pane_id] = false
  end
  log('status: pane=%d value=%s watching=%s', pane_id, tostring(value), tostring(watching))
end)

-- アクティブペインの変化を見て既読を打つ。
-- update-status は約1秒間隔で発火するため、前回値と同じなら即 return して
-- 毎秒のファイル書き込みを避ける。
wezterm.on('update-status', function(window, pane)
  if not window or not pane then
    return
  end
  local ok, window_id = pcall(function() return window:window_id() end)
  if not ok then
    return
  end
  local pane_id = pane:pane_id()
  if last_active[window_id] == pane_id then
    return
  end
  last_active[window_id] = pane_id
  mark_read(pane_id)
end)

-- 状態ディレクトリは hook 側でも mkdir -p しているが、Lua が先に書く場合も
-- あるのでここでも用意しておく（非同期。失敗しても実害はない）。
pcall(wezterm.background_child_process, { 'mkdir', '-p', STATUS_DIR })
restore_dismissed()

return M
