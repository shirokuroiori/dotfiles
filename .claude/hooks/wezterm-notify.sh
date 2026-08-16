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
agent=claude
status_dir=/tmp/wezterm-agent-status

[ -n "${WEZTERM_PANE:-}" ] || exit 0
command -v wezterm >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

# tty_name とペインタイトルを1回のCLI呼び出しでまとめて取る。
# タイトルはイベントログの task 欄に使う（Claude Code / Copilot CLIとも会話
# サマリを自分でペインタイトルに書くため、追加のプラグイン無しで
# 「何をしていたか」が残る）。
IFS=$'\t' read -r tty_path pane_title <<<"$(wezterm cli list --format json 2>/dev/null \
  | jq -r --arg pid "$WEZTERM_PANE" \
      '.[] | select((.pane_id|tostring)==$pid) | [.tty_name, (.title // "")] | @tsv' 2>/dev/null)" || exit 0
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
mkdir -p "$status_dir" 2>/dev/null || true
printf '%s' "$status" > "$status_dir/$WEZTERM_PANE" 2>/dev/null || true

# --- イベントログ（仕様書 §2.2）---------------------------------------------
# 上の1行ファイルは状態を上書きするだけなので、通知の発生時刻も履歴も残らない。
# TUIが未読件数（.readより新しい通知の数）と通知履歴を出せるように、
# 追記型のJSON Linesも書く。このファイルの書き手はhookだけなので、
# 4KB未満のO_APPEND追記は行が混ざらずロックも要らない。
# workingは画面ポーリングで検知する状態であって通知ではないため記録しない。
case "$status" in
  waiting) event_text='承認/入力待ちです' ;;
  done)    event_text='応答が完了しました' ;;
  *)       event_text='' ;;
esac

if [ -n "$event_text" ]; then
  jsonl="$status_dir/$WEZTERM_PANE.jsonl"
  # 時刻はLua側(.read)と文字列比較するのでRFC3339で揃える。
  # BSD dateに-Iが無い環境向けにコロン無しの%zへフォールバックする。
  at=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z)
  # タイトルは引用符・バックスラッシュを含みうるので、jqに組み立てさせる。
  jq -nc --arg at "$at" --arg agent "$agent" --arg kind "$status" \
        --arg text "$event_text" --arg task "$pane_title" \
        '{at:$at,agent:$agent,kind:$kind,text:$text,task:$task}' \
    >> "$jsonl" 2>/dev/null || true

  # ローテーション。単一書き手なので mv の原子的置換だけで足りる。
  lines=$(wc -l < "$jsonl" 2>/dev/null || echo 0)
  if [ "${lines:-0}" -gt 200 ]; then
    tail -n 100 "$jsonl" > "$jsonl.tmp.$$" 2>/dev/null \
      && mv -f "$jsonl.tmp.$$" "$jsonl" 2>/dev/null || true
  fi
fi
