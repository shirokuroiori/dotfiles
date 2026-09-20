#!/bin/bash
# Mirrors ~/.config/starship.toml (directory, git branch/status, git user scope,
# python/node/aws indicators, right-aligned time).
input=$(cat)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // empty')
[ -z "$cwd" ] && cwd="$PWD"
cd "$cwd" 2>/dev/null

RESET=$'\033[0m'
BOLD=$'\033[1m'
PURPLE=$'\033[38;5;98m'
GRAY=$'\033[38;5;248m'
GREEN_UNTRACKED=$'\033[38;5;41m'
CYAN_MODIFIED=$'\033[38;5;51m'
RED_DELETED=$'\033[38;5;203m'
BLUE_PY=$'\033[38;5;27m'
ORANGE_AWS=$'\033[38;5;208m'
BLUE_SCOPE=$'\033[38;5;33m'
GREEN_NODE=$'\033[38;5;83m'
YELLOW_EFFORT=$'\033[38;5;220m'
TEAL_TOKENS=$'\033[38;5;80m'
GREEN_OK=$'\033[38;5;41m'
YELLOW_WARN=$'\033[38;5;220m'
RED_CRIT=$'\033[38;5;203m'

# directory (truncate_to_repo = false, truncation_length effectively unbounded)
dir="${cwd/#$HOME/~}"
left="${dir}"

# git branch + status (skip optional locks; only runs inside a work tree)
if git --no-optional-locks rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git --no-optional-locks branch --show-current 2>/dev/null)
  if [ -n "$branch" ]; then
    left="${left} ${BOLD}${PURPLE}󰊢 ${branch}${RESET}"
  fi

  porcelain=$(git --no-optional-locks status --porcelain 2>/dev/null)
  untracked=$(printf '%s\n' "$porcelain" | grep -c '^??')
  staged=$(printf '%s\n' "$porcelain" | grep -Ec '^[MADRC]')
  modified=$(printf '%s\n' "$porcelain" | grep -Ec '^.M')
  deleted=$(printf '%s\n' "$porcelain" | grep -Ec '^.D')

  status_str=""
  [ "$untracked" -gt 0 ] 2>/dev/null && status_str="${status_str}${GREEN_UNTRACKED} +${untracked}${RESET}"
  [ "$modified" -gt 0 ] 2>/dev/null && status_str="${status_str}${CYAN_MODIFIED} 󱇨 ${modified}${RESET}"
  [ "$staged" -gt 0 ] 2>/dev/null && status_str="${status_str}${CYAN_MODIFIED} 󱇧 ${staged}${RESET}"
  [ "$deleted" -gt 0 ] 2>/dev/null && status_str="${status_str}${RED_DELETED} 󱀷 ${deleted}${RESET}"

  upstream=$(git --no-optional-locks rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)
  if [ -n "$upstream" ]; then
    ahead_behind=$(git --no-optional-locks rev-list --left-right --count HEAD..."$upstream" 2>/dev/null)
    ahead=$(echo "$ahead_behind" | awk '{print $1}')
    behind=$(echo "$ahead_behind" | awk '{print $2}')
    [ -n "$ahead" ] && [ "$ahead" -gt 0 ] 2>/dev/null && status_str="${status_str}${BOLD}${PURPLE} ↑${ahead}${RESET}"
    [ -n "$behind" ] && [ "$behind" -gt 0 ] 2>/dev/null && status_str="${status_str}${BOLD}${PURPLE} ↓${behind}${RESET}"
  fi

  left="${left}${status_str}"

  scope=$(git config user.name 2>/dev/null)
  [ -n "$scope" ] && left="${left} ${BOLD}${BLUE_SCOPE}@${scope}${RESET}"
fi

# python (pyenv), shown only when the project looks like a python project
if command -v pyenv >/dev/null 2>&1 && { [ -f "pyproject.toml" ] || [ -f "requirements.txt" ] || [ -f ".python-version" ] || ls -- *.py >/dev/null 2>&1; }; then
  pyver=$(pyenv version-name 2>/dev/null)
  [ -n "$pyver" ] && left="${left} ${BOLD}${BLUE_PY}󰌠 ${pyver}${RESET}"
fi

# node, shown only when a package.json is present
if [ -f "package.json" ] && command -v node >/dev/null 2>&1; then
  nodever=$(node --version 2>/dev/null)
  [ -n "$nodever" ] && left="${left} ${BOLD}${GREEN_NODE}󰎙 ${nodever}${RESET}"
fi

# aws profile
if [ -n "$AWS_PROFILE" ]; then
  left="${left} ${BOLD}${ORANGE_AWS}󰸏 ${AWS_PROFILE}${RESET}"
fi

# model / effort / token usage (right side)
model_name=$(echo "$input" | jq -r '.model.display_name // empty')
effort_level=$(echo "$input" | jq -r '.effort.level // empty')
in_tokens=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')
out_tokens=$(echo "$input" | jq -r '.context_window.total_output_tokens // empty')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

right=""
[ -n "$model_name" ] && right="${GRAY}${model_name}${RESET}"
[ -n "$effort_level" ] && right="${right}${right:+ }${YELLOW_EFFORT}${effort_level}${RESET}"
if [ -n "$in_tokens" ] && [ -n "$out_tokens" ]; then
  total_tokens=$(( in_tokens + out_tokens ))
  tokens_str="${TEAL_TOKENS}${total_tokens}tok"
  [ -n "$used_pct" ] && tokens_str="${tokens_str} (${used_pct%.*}%)"
  tokens_str="${tokens_str}${RESET}"
  right="${right}${right:+ }${tokens_str}"
fi

# remaining rate-limit usage (5h / 7d), same numbers as /usage.
# rate_limits is account-wide, but each session only sees the value from
# its own last API response. Other sessions' consumption doesn't show up
# here until this session's next call. To close that gap, every session
# reads/writes a shared cache file and displays whichever observation
# (its own vs. other sessions') is newest per window. Usage only rises
# within a window, so "higher used_percentage" == "more recent".
RATE_LIMIT_CACHE="$HOME/.claude/statusline-rate-limits.json"
now_epoch=$(date +%s)

own_five_used=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
own_five_resets=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
own_week_used=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
own_week_resets=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

cached_json=$(cat "$RATE_LIMIT_CACHE" 2>/dev/null)
echo "$cached_json" | jq -e . >/dev/null 2>&1 || cached_json='{}'

merge_window() {
  # args: own_used own_resets cached_used cached_resets -> prints "used resets"
  local ou="$1" or="$2" cu="$3" cr="$4"
  # a cached value from an already-elapsed window is stale; ignore it
  if [ -n "$cr" ] && [ "$cr" -le "$now_epoch" ] 2>/dev/null; then
    cu=""; cr=""
  fi
  if [ -z "$cu" ]; then
    echo "$ou $or"; return
  fi
  if [ -z "$ou" ]; then
    echo "$cu $cr"; return
  fi
  if [ "$cr" = "$or" ]; then
    # same window: keep the higher (= more recently observed) usage
    if awk -v a="$cu" -v b="$ou" 'BEGIN{exit !(a>b)}'; then echo "$cu $cr"; else echo "$ou $or"; fi
  elif [ -n "$cr" ] && [ -n "$or" ] && [ "$cr" -gt "$or" ] 2>/dev/null; then
    # cache is already tracking a newer window than this session knows about
    echo "$cu $cr"
  else
    echo "$ou $or"
  fi
}

cached_five_used=$(echo "$cached_json" | jq -r '.five_hour.used_percentage // empty')
cached_five_resets=$(echo "$cached_json" | jq -r '.five_hour.resets_at // empty')
cached_week_used=$(echo "$cached_json" | jq -r '.seven_day.used_percentage // empty')
cached_week_resets=$(echo "$cached_json" | jq -r '.seven_day.resets_at // empty')

read -r five_h_used five_h_resets <<<"$(merge_window "$own_five_used" "$own_five_resets" "$cached_five_used" "$cached_five_resets")"
read -r week_used week_resets <<<"$(merge_window "$own_week_used" "$own_week_resets" "$cached_week_used" "$cached_week_resets")"

if [ -n "$five_h_used" ] || [ -n "$week_used" ]; then
  jq -n \
    --arg fu "$five_h_used" --arg fr "$five_h_resets" \
    --arg wu "$week_used" --arg wr "$week_resets" \
    '{
      five_hour: (if $fu == "" then null else {used_percentage: ($fu|tonumber), resets_at: ($fr|tonumber)} end),
      seven_day: (if $wu == "" then null else {used_percentage: ($wu|tonumber), resets_at: ($wr|tonumber)} end)
    }' > "${RATE_LIMIT_CACHE}.tmp.$$" 2>/dev/null && mv "${RATE_LIMIT_CACHE}.tmp.$$" "$RATE_LIMIT_CACHE" 2>/dev/null
fi

remaining_color() {
  # $1 = remaining percentage (integer)
  if [ "$1" -le 10 ]; then echo "$RED_CRIT"
  elif [ "$1" -le 30 ]; then echo "$YELLOW_WARN"
  else echo "$GREEN_OK"; fi
}

usage_str=""
if [ -n "$five_h_used" ]; then
  five_h_remaining=$(printf '%.0f' "$(echo "100 - $five_h_used" | bc)")
  usage_str="${usage_str}$(remaining_color "$five_h_remaining")5h残${five_h_remaining}%${RESET}"
fi
if [ -n "$week_used" ]; then
  week_remaining=$(printf '%.0f' "$(echo "100 - $week_used" | bc)")
  usage_str="${usage_str}${usage_str:+ }$(remaining_color "$week_remaining")7d残${week_remaining}%${RESET}"
fi
[ -n "$usage_str" ] && right="${right}${right:+ }${usage_str}"

time_str="${GRAY}$(date '+%F %T')${RESET}"
right="${right}${right:+  }${time_str}"

cols="${COLUMNS:-$(tput cols 2>/dev/null)}"
plain_left=$(printf '%s' "$left" | sed -E 's/\x1b\[[0-9;]*m//g')
plain_right=$(printf '%s' "$right" | sed -E 's/\x1b\[[0-9;]*m//g')
if [ -n "$cols" ] && [ "$cols" -gt 0 ] 2>/dev/null; then
  pad=$(( cols - ${#plain_left} - ${#plain_right} - 1 ))
  [ "$pad" -lt 1 ] && pad=1
  printf '%s%*s%s\n' "$left" "$pad" "" "$right"
else
  printf '%s  %s\n' "$left" "$right"
fi
