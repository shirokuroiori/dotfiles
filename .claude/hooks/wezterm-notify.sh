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

# tty_name・ペインタイトル・tab_idを1回のCLI呼び出しでまとめて取る。
# タイトルはイベントログの task 欄とメモのログ行に使う（Claude Code /
# Copilot CLIとも会話サマリを自分でペインタイトルに書くため、追加の
# プラグイン無しで「何をしていたか」が残る）。tab_idはメモファイルの
# 紐付けキー（~/.weztermemo/tab-<tab_id>.md）に使う。
IFS=$'\t' read -r tty_path pane_title tab_id <<<"$(wezterm cli list --format json 2>/dev/null \
  | jq -r --arg pid "$WEZTERM_PANE" \
      '.[] | select((.pane_id|tostring)==$pid) | [.tty_name, (.title // ""), (.tab_id|tostring)] | @tsv' 2>/dev/null)" || exit 0
[ -n "$tty_path" ] || exit 0

{
  b64=$(printf '%s' "$status" | base64 | tr -d '\n')
  printf '\033]1337;SetUserVar=claude_status=%s\007' "$b64"
  [ "$status" != "working" ] && printf '\a'
  true
} > "$tty_path" 2>/dev/null || true

# 状態ディレクトリを用意する。この下に書く .jsonl / .read を
# tools/wezterm-agents（Rust製TUI）と wezterm.lua が読む。
# 旧bash版(bin/wezterm-agents)が読んでいた1行ファイル（$status_dir/$WEZTERM_PANE
# への上書き）はPhase 4でbash版ごと廃止したので、もう書かない。
mkdir -p "$status_dir" 2>/dev/null || true

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

# --- メモへの自動追記（仕様書 §5.3 / §6）------------------------------------
# done のときだけ、tab のメモファイルの `## ログ` 直後に1行挿入する。
# サマリの出所はペインタイトル。先頭のスピナー文字・✳マーカーを取り除いた
# ものが「意味のある文字列」（zsh 等の裸のプロセス名でない）ときだけ書く。
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
      # `## ログ` の直後に新しい行を挿入する（新しい行が先頭に来る）。
      # 見出しの次には元々1行だけ空行があるので、挿入時に自前で足す空行の
      # 分だけ元の空行を読み飛ばして二重にならないようにする。
      # `## ログ` が無いファイル（人間が消した等）なら末尾に節ごと作る。
      # 単一書き手ではない（人間がエディタで同時に編集しうる）ため、
      # awk で全文を読んでから一時ファイルへ原子的に書き出す。
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
