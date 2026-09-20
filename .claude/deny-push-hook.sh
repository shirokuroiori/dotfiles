#!/usr/bin/env bash
# PreToolUse(Bash) フック。push / 公開系のコマンドを検出して deny する。
#
# 承認前に外部公開されるのを防ぐのが目的。permissions.deny の
# "Bash(git push:*)" は先頭一致なので `git -C <dir> push` のような形を
# 取りこぼす。ここではコマンド文字列を構文的に分解して塞ぐ。
#
# stdin : Claude Code のフック入力 JSON
# stdout: deny するときだけ permissionDecision を含む JSON

set -uo pipefail

input=$(cat)
command=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -n "$command" ] || exit 0

# FOO="a b" のような代入がクォート内で語分割されたかを判定する
quotes_balanced() {
  local s=$1 dq sq
  dq=${s//[^\"]/}
  sq=${s//[^\']/}
  [ $((${#dq} % 2)) -eq 0 ] && [ $((${#sq} % 2)) -eq 0 ]
}

deny() {
  jq -n --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

# && || は先に潰してから、残りの区切り文字を改行へ。クォート内は考慮しない
# （分割しすぎる方向にしか倒れないので、検出漏れにはつながらない）。
normalized=${command//&&/$'\n'}
normalized=${normalized//||/$'\n'}
normalized=$(printf '%s' "$normalized" | tr ';|&(){}`' '\n\n\n\n\n\n\n\n')

while IFS= read -r segment; do
  [ -n "${segment// /}" ] || continue
  read -ra tokens <<< "$segment"
  [ "${#tokens[@]}" -gt 0 ] || continue

  # 先頭の環境変数代入とラッパーコマンドを読み飛ばす
  i=0
  while [ "$i" -lt "${#tokens[@]}" ]; do
    case "${tokens[$i]}" in
      -*)
        break ;;
      *=*)
        # FOO="ssh -i key" が語分割されている場合、閉じクォートまで読み飛ばす
        tok=${tokens[$i]}
        i=$((i + 1))
        while [ "$i" -lt "${#tokens[@]}" ] && ! quotes_balanced "$tok"; do
          tok="$tok ${tokens[$i]}"
          i=$((i + 1))
        done ;;
      sudo|env|command|time|nohup|exec|builtin)
        i=$((i + 1)) ;;
      *)
        break ;;
    esac
  done
  [ "$i" -lt "${#tokens[@]}" ] || continue

  prog=${tokens[$i]##*/}   # /usr/bin/git -> git

  if [ "$prog" = "git" ]; then
    # git 自身のオプションを飛ばしてサブコマンドを見つける。
    # 値を取るオプション（-C <dir> など）は次のトークンも飛ばす。
    sub=""
    j=$((i + 1))
    while [ "$j" -lt "${#tokens[@]}" ]; do
      case "${tokens[$j]}" in
        -C|-c|--git-dir|--work-tree|--namespace|--exec-path|--config-env)
          j=$((j + 2)) ;;
        -*)
          j=$((j + 1)) ;;
        *)
          sub=${tokens[$j]}; break ;;
      esac
    done

    case "$sub" in
      push)
        deny "git push は禁止されています。公開前にユーザーのレビューと許可が必要です（.claude/deny-push-hook.sh）。コミットまでで止め、差分を提示して承認を得てください。" ;;
      subtree)
        for ((k = j + 1; k < ${#tokens[@]}; k++)); do
          [ "${tokens[$k]}" = "push" ] && \
            deny "git subtree push は禁止されています。公開前にユーザーのレビューと許可が必要です（.claude/deny-push-hook.sh）。"
        done ;;
    esac
  fi

  if [ "$prog" = "gh" ]; then
    subs=()
    for ((j = i + 1; j < ${#tokens[@]}; j++)); do
      case "${tokens[$j]}" in
        -*) ;;
        *)  subs+=("${tokens[$j]}") ;;
      esac
    done
    case "${subs[0]:-} ${subs[1]:-}" in
      "repo create"|"pr create"|"release create"|"gist create"|"repo edit")
        deny "gh ${subs[0]:-} ${subs[1]:-} は外部公開を伴うため禁止されています。ユーザーのレビューと許可が必要です（.claude/deny-push-hook.sh）。" ;;
    esac
  fi
done <<< "$normalized"

exit 0
