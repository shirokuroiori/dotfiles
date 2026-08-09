#!/usr/bin/env bash
# GitHub Copilot CLI hook -> WezTerm 通知
# 使い方: wezterm-notify.sh <done>
#
# ~/.claude/hooks/wezterm-notify.sh と同一ロジック（エージェントの種類に依存しない
# 汎用スクリプト）。Copilot CLI用に user_var名だけ copilot_status に変えてある。
#
# hookはCopilot CLIのサブプロセスとして実行され、制御端末(/dev/tty)を持たない
# ことがあるため、/dev/ttyへの直書きには頼らない。代わりに `wezterm cli`
# （Unixソケット経由でmuxサーバと通信）で自分のペインID($WEZTERM_PANE、
# wezterm起動時に必ず設定される)から実tty(tty_name)を逆引きし、そこに
# エスケープシーケンスを書き込む。
# - OSC 1337 SetUserVar: WezTerm側で pane.user_vars.copilot_status として読める
# - BEL: WezTerm の `bell` イベントを発火させ、トースト通知のトリガーにする
#
# 【未検証】Copilot CLIには2026-08時点でNotification相当のhookが無いため
# waiting(承認待ち)は送出できない。呼べるのは agentStop -> done のみ。
set -euo pipefail

status="${1:?usage: wezterm-notify.sh <done>}"

[ -n "${WEZTERM_PANE:-}" ] || exit 0
command -v wezterm >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

tty_path=$(wezterm cli list --format json 2>/dev/null \
  | jq -r --arg pid "$WEZTERM_PANE" '.[] | select((.pane_id|tostring)==$pid) | .tty_name' 2>/dev/null) || exit 0
[ -n "$tty_path" ] || exit 0

{
  b64=$(printf '%s' "$status" | base64 | tr -d '\n')
  printf '\033]1337;SetUserVar=copilot_status=%s\007' "$b64"
  printf '\a'
  true
} > "$tty_path" 2>/dev/null || true
