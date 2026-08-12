#!/usr/bin/env bash
# GitHub Copilot CLI hook -> WezTerm 通知
# 使い方: wezterm-notify.sh <waiting|done|pretool>
#
# ~/.claude/hooks/wezterm-notify.sh と同一ロジック（エージェントの種類に依存しない
# 汎用スクリプト）。Copilot CLI用に user_var名だけ copilot_status に変えてある。
#
# hookはCopilot CLIのサブプロセスとして実行され、制御端末(/dev/tty)を持たない
# ことがあるため、/dev/ttyへの直書きには頼らない。代わりに `wezterm cli`
# （Unixソケット経由でmuxサーバと通信）で $WEZTERM_PANE から実tty(tty_name)を
# 逆引きし、そこにエスケープシーケンスを書き込む。
# $WEZTERM_PANEがhookサブプロセスで空になるケースは実機検証（waiting(notification)/
# waiting(pretool ask_user)/doneの全パターン、複数セッション）で一度も観測
# されなかったため、Claude Code側と同じ単純な解決方法で足りると判断した。
#
# working（思考中）はこのスクリプトでは扱わない。Copilot CLIは画面最終行に
# ステータス行を描画するため、wezterm.lua側でそれを毎描画ポーリングして検知する
# （Claude Codeのtitleスピナー検知と同じ考え方）。hookに頼らないぶん、Esc中断でも
# 表示が消えた瞬間に追従できる。
#
# pretoolではask_userツール呼び出しだけをwaiting扱いにする。実機ペイロードで
# 確認したフィールドは toolName のみ（他の想定フィールド名はヒットしなかった）。
# ask_user以外のツールはworking検知が画面ポーリング側の役目なので何もしない。
#
# - OSC 1337 SetUserVar: WezTerm側で pane.user_vars.copilot_status として読める
# - BEL: WezTerm の `bell` イベントを発火させ、トースト通知のトリガーにする
set -euo pipefail

status="${1:?usage: wezterm-notify.sh <waiting|done|pretool>}"

command -v wezterm >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

payload="$(cat 2>/dev/null || true)"

if [ "$status" = "pretool" ]; then
  if [ -n "$payload" ] && jq -e '.toolName == "ask_user"' >/dev/null 2>&1 <<<"$payload"; then
    status="waiting"
  else
    exit 0
  fi
fi

[ -n "${WEZTERM_PANE:-}" ] || exit 0

tty_path=$(wezterm cli list --format json 2>/dev/null \
  | jq -r --arg pid "$WEZTERM_PANE" '.[] | select((.pane_id|tostring)==$pid) | .tty_name' 2>/dev/null) || exit 0
[ -n "$tty_path" ] || exit 0

{
  b64=$(printf '%s' "$status" | base64 | tr -d '\n')
  printf '\033]1337;SetUserVar=copilot_status=%s\007' "$b64"
  printf '\a'
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
