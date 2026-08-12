#!/usr/bin/env bash
# GitHub Copilot CLI hook -> WezTerm 通知
# 使い方: wezterm-notify.sh <waiting|working|done|pretool>
#
# ~/.claude/hooks/wezterm-notify.sh と同一ロジック（エージェントの種類に依存しない
# 汎用スクリプト）。Copilot CLI用に user_var名だけ copilot_status に変えてある。
#
# hookはCopilot CLIのサブプロセスとして実行され、制御端末(/dev/tty)を持たない
# ことがあるため、/dev/ttyへの直書きには頼らない。代わりに `wezterm cli`
# （Unixソケット経由でmuxサーバと通信）で $WEZTERM_PANE から実tty(tty_name)を
# 逆引きし、そこにエスケープシーケンスを書き込む。
# $WEZTERM_PANEがhookサブプロセスで空になるケースは実機検証（working/
# waiting(notification)/waiting(pretool ask_user)/doneの全パターン、複数
# セッション）で一度も観測されなかったため、Claude Code側と同じ単純な解決方法
# で足りると判断した。
#
# Copilot CLIはClaude Codeと違いpane titleにthinkingスピナーを出さないため、
# working状態はhook駆動（userPromptSubmitted/preToolUse/subagentStart等）で
# 検知するしかない。そのためcopilot_status_atにタイムスタンプも書き込み、
# wezterm.lua側でTTL判定（Esc中断でhookが発火せず古いworkingが残るケースの
# 対策）に使わせる。
#
# pretoolではask_userツール呼び出しをwaiting扱いにする。実機ペイロードで
# 確認したフィールドは toolName のみ（他の想定フィールド名はヒットしなかった）。
#
# - OSC 1337 SetUserVar: WezTerm側で pane.user_vars.copilot_status として読める
# - BEL: WezTerm の `bell` イベントを発火させ、トースト通知のトリガーにする
set -euo pipefail

status="${1:?usage: wezterm-notify.sh <waiting|working|done|pretool>}"

command -v wezterm >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

payload="$(cat 2>/dev/null || true)"

if [ "$status" = "pretool" ]; then
  if [ -n "$payload" ] && jq -e '.toolName == "ask_user"' >/dev/null 2>&1 <<<"$payload"; then
    status="waiting"
  else
    status="working"
  fi
fi

[ -n "${WEZTERM_PANE:-}" ] || exit 0

tty_path=$(wezterm cli list --format json 2>/dev/null \
  | jq -r --arg pid "$WEZTERM_PANE" '.[] | select((.pane_id|tostring)==$pid) | .tty_name' 2>/dev/null) || exit 0
[ -n "$tty_path" ] || exit 0

{
  b64=$(printf '%s' "$status" | base64 | tr -d '\n')
  ts_b64=$(printf '%s' "$(date +%s)" | base64 | tr -d '\n')
  printf '\033]1337;SetUserVar=copilot_status=%s\007' "$b64"
  printf '\033]1337;SetUserVar=copilot_status_at=%s\007' "$ts_b64"
  [ "$status" != "working" ] && printf '\a'
  true
} > "$tty_path" 2>/dev/null || true

# デバッグログはデフォルトでは書かない。動作確認したいときだけ
# WEZTERM_NOTIFY_DEBUG=1 を付けて呼ぶ。
if [ "${WEZTERM_NOTIFY_DEBUG:-}" = "1" ]; then
  debug_log_file="${COPILOT_HOME:-$HOME/.copilot}/hooks/wezterm-notify.log"
  mkdir -p "$(dirname "$debug_log_file")" 2>/dev/null || true
  printf '%s status=%s pane=%s tty=%s\n' \
    "$(date '+%Y-%m-%d %H:%M:%S')" "$status" "$WEZTERM_PANE" "$tty_path" \
    >> "$debug_log_file" 2>/dev/null || true
fi
