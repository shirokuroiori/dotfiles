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
agent=copilot
status_dir=/tmp/wezterm-agent-status

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

# tty_name・ペインタイトル・tab_idを1回のCLI呼び出しでまとめて取る。
# タイトルはイベントログの task 欄とメモのログ行に使う。tab_idはメモ
# ファイルの紐付けキー（~/.weztermemo/tab-<tab_id>.md）に使う。
IFS=$'\t' read -r tty_path pane_title tab_id <<<"$(wezterm cli list --format json 2>/dev/null \
  | jq -r --arg pid "$WEZTERM_PANE" \
      '.[] | select((.pane_id|tostring)==$pid) | [.tty_name, (.title // ""), (.tab_id|tostring)] | @tsv' 2>/dev/null)" || exit 0
[ -n "$tty_path" ] || exit 0

{
  b64=$(printf '%s' "$status" | base64 | tr -d '\n')
  printf '\033]1337;SetUserVar=copilot_status=%s\007' "$b64"
  printf '\a'
  true
} > "$tty_path" 2>/dev/null || true

# 状態ディレクトリを用意する。この下に書く .jsonl / .read を
# tools/wezterm-agents（Rust製TUI）と wezterm.lua が読む。
# 旧bash版(bin/wezterm-agents)が読んでいた1行ファイル（$status_dir/$WEZTERM_PANE
# への上書き）はPhase 4でbash版ごと廃止したので、もう書かない。
mkdir -p "$status_dir" 2>/dev/null || true

# --- イベントログ（仕様書 §2.2）---------------------------------------------
# ~/.claude/hooks/wezterm-notify.sh と同一ロジック（agent 名だけが違う）。
# 上の1行ファイルは状態を上書きするだけで通知の時刻も履歴も残らないため、
# TUIが未読件数と通知履歴を出せるように追記型のJSON Linesも書く。
# 書き手がこのhookだけなので、4KB未満のO_APPEND追記は行が混ざらずロック不要。
case "$status" in
  waiting) event_text='承認/入力待ちです' ;;
  done)    event_text='応答が完了しました' ;;
  *)       event_text='' ;;
esac

if [ -n "$event_text" ]; then
  jsonl="$status_dir/$WEZTERM_PANE.jsonl"
  # 時刻はLua側(.read)と文字列比較するのでRFC3339で揃える。
  at=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z)
  jq -nc --arg at "$at" --arg agent "$agent" --arg kind "$status" \
        --arg text "$event_text" --arg task "$pane_title" \
        '{at:$at,agent:$agent,kind:$kind,text:$text,task:$task}' \
    >> "$jsonl" 2>/dev/null || true

  lines=$(wc -l < "$jsonl" 2>/dev/null || echo 0)
  if [ "${lines:-0}" -gt 200 ]; then
    tail -n 100 "$jsonl" > "$jsonl.tmp.$$" 2>/dev/null \
      && mv -f "$jsonl.tmp.$$" "$jsonl" 2>/dev/null || true
  fi
fi

# --- メモへの自動追記（仕様書 §5.3 / §6）------------------------------------
# ~/.claude/hooks/wezterm-notify.sh と同一ロジック（agent 名だけが違う）。
if [ "$status" = 'done' ] && [ -n "$tab_id" ] && [ "$tab_id" != 'null' ] \
   && command -v perl >/dev/null 2>&1; then
  task=$(printf '%s' "$pane_title" \
    | perl -CSD -pe 's/^[\x{2800}-\x{28FF}\x{25D0}-\x{25D3}\x{2733}\s]+//; s/\s+$//')
  case "$task" in
    ''|zsh|bash|nvim|vim|node|claude|copilot|wezterm-gui) task='' ;;
  esac

  if [ -n "$task" ]; then
    memo_dir="$HOME/.weztermemo"
    memo_file="$memo_dir/tab-$tab_id.md"
    mkdir -p "$memo_dir" 2>/dev/null || true
    when=$(date '+%Y-%m-%d %H:%M' 2>/dev/null || true)
    log_line="- $when $agent: $task"

    if [ ! -f "$memo_file" ]; then
      cwd_uri=$(wezterm cli list --format json 2>/dev/null \
        | jq -r --arg pid "$WEZTERM_PANE" '.[] | select((.pane_id|tostring)==$pid) | .cwd' 2>/dev/null)
      cwd=${cwd_uri#file://}
      [ "$cwd" = '/' ] || cwd=${cwd%/}
      created_at=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z)
      {
        printf -- '---\n'
        printf 'tab_id: %s\n' "$tab_id"
        printf 'cwd: %s\n' "$cwd"
        printf 'created_at: %s\n' "$created_at"
        printf -- '---\n\n# メモ\n\n## ログ\n\n%s\n' "$log_line"
      } > "$memo_file" 2>/dev/null || true
    else
      awk -v line="$log_line" '
        BEGIN { done = 0; skip_blank = 0 }
        {
          if (skip_blank && $0 == "") { skip_blank = 0; next }
          skip_blank = 0
          print
          if (!done && $0 == "## ログ") {
            print ""
            print line
            done = 1
            skip_blank = 1
          }
        }
        END {
          if (!done) { print ""; print "## ログ"; print ""; print line }
        }
      ' "$memo_file" > "$memo_file.tmp.$$" 2>/dev/null \
        && mv -f "$memo_file.tmp.$$" "$memo_file" 2>/dev/null || true
    fi
  fi
fi

# デバッグログはデフォルトでは書かない。動作確認したいときだけ
# WEZTERM_NOTIFY_DEBUG=1 を付けて呼ぶ。
if [ "${WEZTERM_NOTIFY_DEBUG:-}" = "1" ]; then
  debug_log_file="${COPILOT_HOME:-$HOME/.copilot}/hooks/wezterm-notify.log"
  mkdir -p "$(dirname "$debug_log_file")" 2>/dev/null || true
  printf '%s status=%s pane=%s tty=%s\n' \
    "$(date '+%Y-%m-%d %H:%M:%S')" "$status" "$WEZTERM_PANE" "$tty_path" \
    >> "$debug_log_file" 2>/dev/null || true
fi
