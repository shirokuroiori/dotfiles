#!/usr/bin/env bash
# Claude Code hook -> WezTerm 通知
# 使い方: wezterm-notify.sh <waiting|working|done>
#
# hookはClaude Codeのサブプロセスとして実行され、制御端末(/dev/tty)を持たない
# ことがある（実測済み）ため、/dev/ttyへの直書きには頼らない。
# 代わりに `wezterm cli`（Unixソケット経由でmuxサーバと通信）で自分のペインID
# ($WEZTERM_PANE、wezterm起動時に必ず設定される)から実tty(tty_name)を逆引きし、
# そこにエスケープシーケンスを書き込む。
# - OSC 1337 SetUserVar: WezTerm側で pane.user_vars.claude_status として読める
# - BEL: WezTerm の `bell` イベントを発火させ、トースト通知のトリガーにする
set -euo pipefail

status="${1:?usage: wezterm-notify.sh <waiting|working|done>}"

[ -n "${WEZTERM_PANE:-}" ] || exit 0
command -v wezterm >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

tty_path=$(wezterm cli list --format json 2>/dev/null \
  | jq -r --arg pid "$WEZTERM_PANE" '.[] | select((.pane_id|tostring)==$pid) | .tty_name' 2>/dev/null) || exit 0
[ -n "$tty_path" ] || exit 0

{
  b64=$(printf '%s' "$status" | base64 | tr -d '\n')
  printf '\033]1337;SetUserVar=claude_status=%s\007' "$b64"
  [ "$status" != "working" ] && printf '\a'
  true
} > "$tty_path" 2>/dev/null || true

# user_varはWezTerm内部のLua（format-tab-title等）からしか読めず、
# `wezterm cli list` のJSON出力には含まれない。外部スクリプト（bin/wezterm-agents
# など）から状態を読めるように、同じ内容をペインID別のファイルにも書いておく。
mkdir -p /tmp/wezterm-agent-status 2>/dev/null || true
printf '%s' "$status" > "/tmp/wezterm-agent-status/$WEZTERM_PANE" 2>/dev/null || true
