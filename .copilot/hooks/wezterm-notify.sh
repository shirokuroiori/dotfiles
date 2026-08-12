#!/usr/bin/env bash
# GitHub Copilot CLI hook -> WezTerm 通知
# 使い方: wezterm-notify.sh <waiting|working|done|pretool>
#
# ~/.claude/hooks/wezterm-notify.sh と同一ロジック（エージェントの種類に依存しない
# 汎用スクリプト）。Copilot CLI用に user_var名だけ copilot_status に変えてある。
#
# hookはCopilot CLIのサブプロセスとして実行され、制御端末(/dev/tty)を持たない
# ことがあるため、/dev/ttyへの直書きには頼らない。代わりに `wezterm cli`
# （Unixソケット経由でmuxサーバと通信）で pane_id から実tty(tty_name)を逆引きし、
# そこにエスケープシーケンスを書き込む。
# 通常は $WEZTERM_PANE を使うが、notification hook などでは未設定のことがあるため、
# 直前に記録した pane_id か現在の active pane にフォールバックする。
# - OSC 1337 SetUserVar: WezTerm側で pane.user_vars.copilot_status として読める
# - BEL: WezTerm の `bell` イベントを発火させ、トースト通知のトリガーにする
#
set -euo pipefail

status="${1:?usage: wezterm-notify.sh <waiting|working|done|pretool>}"

command -v wezterm >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

hooks_home="${COPILOT_HOME:-$HOME/.copilot}/hooks"
pane_cache_file="$hooks_home/.last-wezterm-pane"
session_pane_map_file="$hooks_home/.wezterm-session-pane-map.json"
debug_log_file="$hooks_home/wezterm-notify.log"
mkdir -p "$hooks_home"

payload="$(cat 2>/dev/null || true)"
hook_cwd=''
hook_session_id=''
if [ -n "$payload" ]; then
  hook_cwd="$(jq -r '.cwd // empty' <<<"$payload" 2>/dev/null || true)"
  hook_session_id="$(jq -r '.sessionId // .session_id // empty' <<<"$payload" 2>/dev/null || true)"
fi

if [ "$status" = "pretool" ]; then
  if [ -n "$payload" ] && jq -e '
      .toolName == "ask_user"
      or .tool_name == "ask_user"
      or .tool_name == "AskUserQuestion"
      or any(.toolCalls[]?; .name == "ask_user")
      or any(.tool_calls[]?; .tool_name == "AskUserQuestion" or .tool_name == "ask_user")
    ' >/dev/null 2>&1 <<<"$payload"; then
    status="waiting"
  else
    status="working"
  fi
fi

pane_id="${WEZTERM_PANE:-}"
if [ -n "$pane_id" ]; then
  printf '%s' "$pane_id" > "$pane_cache_file" 2>/dev/null || true
  if [ -n "$hook_session_id" ]; then
    map_json='{}'
    if [ -r "$session_pane_map_file" ]; then
      map_json="$(cat "$session_pane_map_file" 2>/dev/null || echo '{}')"
    fi
    updated_map="$(jq -c --arg sid "$hook_session_id" --arg pid "$pane_id" '.[$sid]=$pid' <<<"$map_json" 2>/dev/null || echo '{}')"
    printf '%s' "$updated_map" > "$session_pane_map_file" 2>/dev/null || true
  fi
elif [ -n "$hook_session_id" ] && [ -r "$session_pane_map_file" ]; then
  pane_id="$(jq -r --arg sid "$hook_session_id" '.[$sid] // empty' "$session_pane_map_file" 2>/dev/null || true)"
elif [ -r "$pane_cache_file" ]; then
  pane_id="$(cat "$pane_cache_file" 2>/dev/null || true)"
fi

pane_list_json="$(wezterm cli list --format json 2>/dev/null)" || exit 0

tty_path=''
if [ -n "$pane_id" ]; then
  tty_path="$(jq -r --arg pid "$pane_id" '.[] | select((.pane_id|tostring)==$pid) | .tty_name' <<<"$pane_list_json" | head -n1)"
fi
if [ -z "$tty_path" ]; then
  tty_path="$(jq -r '.[] | select(.is_active == true) | .tty_name' <<<"$pane_list_json" | head -n1)"
fi
[ -n "$tty_path" ] || exit 0

{
  b64=$(printf '%s' "$status" | base64 | tr -d '\n')
  ts_b64=$(printf '%s' "$(date +%s)" | base64 | tr -d '\n')
  printf '\033]1337;SetUserVar=copilot_status=%s\007' "$b64"
  printf '\033]1337;SetUserVar=copilot_status_at=%s\007' "$ts_b64"
  [ "$status" != "working" ] && printf '\a'
  true
} > "$tty_path" 2>/dev/null || true

printf '%s status=%s pane_env=%s pane_resolved=%s session=%s cwd=%s tty=%s\n' \
  "$(date '+%Y-%m-%d %H:%M:%S')" \
  "$status" \
  "${WEZTERM_PANE:-}" \
  "$pane_id" \
  "$hook_session_id" \
  "$hook_cwd" \
  "$tty_path" >> "$debug_log_file" 2>/dev/null || true

if [ "${1:-}" = "pretool" ]; then
  tool_probe="$(jq -c '{toolName,tool_name,toolCalls,tool_calls}' <<<"$payload" 2>/dev/null || true)"
  if [ -z "$tool_probe" ]; then
    tool_probe="$(printf '%s' "$payload" | tr '\n' ' ' | cut -c1-240)"
  fi
  printf '%s pretool_probe=%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$tool_probe" >> "$debug_log_file" 2>/dev/null || true
fi
