#!/bin/bash
# claude-usage-statusline
# ASCII loader bars for Claude Code usage, shown in the status line.
#
# The filled part of each bar = quota you've BURNED (it fills up as you go):
#   Sonnet 5 · ~/dev/project
#   5h  [▉▉▉▉▉▉▉▋░░░░░░░░░░░░░░░░]  32%  eta 2h0m
#   7d  [▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉░░░]  88%  eta 3d22h
#
# Lines shown:
#   - model name + current directory (relative to $HOME)
#   - 5-hour rate-limit window   (Pro/Max subscribers, after 1st API call)
#   - 7-day rate-limit window    (Pro/Max subscribers, after 1st API call)
#   - context-window fallback    (shown only when rate limits aren't available)
#
# Requires: bash, jq
# Optional env overrides:
#   CLAUDE_BAR_WIDTH   bar length in cells         (default 24)
#   CLAUDE_BAR_WARN    % consumed -> yellow        (default 60)
#   CLAUDE_BAR_CRIT    % consumed -> red           (default 85)
#
# License: MIT

input=$(cat)

command -v jq >/dev/null 2>&1 || { echo "statusline: jq not found"; exit 0; }

MODEL=$(echo "$input"   | jq -r '.model.display_name // "?"')
CWD=$(echo "$input"     | jq -r '.workspace.current_dir // .cwd // empty')
CTX_USED=$(echo "$input"  | jq -r '.context_window.used_percentage // empty')
FIVE_USED=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
FIVE_RESET=$(echo "$input"| jq -r '.rate_limits.five_hour.resets_at // empty')
WEEK_USED=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
WEEK_RESET=$(echo "$input"| jq -r '.rate_limits.seven_day.resets_at // empty')

GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'
DIM=$'\033[2m'; CYAN=$'\033[36m'; RESET=$'\033[0m'

WIDTH=${CLAUDE_BAR_WIDTH:-24}
WARN=${CLAUDE_BAR_WARN:-60}
CRIT=${CLAUDE_BAR_CRIT:-85}
FULL="▉"          # 7/8 block: leaves a hairline gap between cells
PARTIALS=(" " "▏" "▎" "▍" "▌" "▋" "▊" "▉")

# draw_bar <used_pct> -> "[▉▉▉▉▉▊░░░░]" colored by how full it is
draw_bar() {
    local used=${1%.*}
    [ -z "$used" ] && used=0
    [ "$used" -lt 0 ] && used=0
    [ "$used" -gt 100 ] && used=100

    local color="$GREEN"
    [ "$used" -ge "$WARN" ] && color="$YELLOW"
    [ "$used" -ge "$CRIT" ] && color="$RED"

    # eighth-of-a-cell resolution for a smooth leading edge
    local eighths=$((used * WIDTH * 8 / 100))
    local full=$((eighths / 8))
    local rem=$((eighths % 8))
    [ "$full" -gt "$WIDTH" ] && { full=$WIDTH; rem=0; }

    local bar=""
    [ "$full" -gt 0 ] && { printf -v f "%${full}s"; bar="${f// /$FULL}"; }
    local cells=$full
    if [ "$rem" -gt 0 ] && [ "$cells" -lt "$WIDTH" ]; then
        bar="${bar}${PARTIALS[$rem]}"; cells=$((cells + 1))
    fi
    local empty=$((WIDTH - cells))
    [ "$empty" -gt 0 ] && { printf -v e "%${empty}s"; bar="${bar}${e// /░}"; }

    printf '%s[%s%s%s]%s' "$DIM" "$color" "$bar" "$DIM" "$RESET"
}

# eta_str <epoch> -> loader-style time remaining until that instant
eta_str() {
    local now diff
    now=$(date +%s)
    diff=$(( $1 - now ))
    [ "$diff" -lt 0 ] && { echo "0s"; return; }
    if   [ "$diff" -lt 3600 ];  then echo "$((diff / 60))m"
    elif [ "$diff" -lt 86400 ]; then echo "$((diff / 3600))h$((diff % 3600 / 60))m"
    else echo "$((diff / 86400))d$((diff % 86400 / 3600))h"
    fi
}

pct_fmt() { printf '%3d%%' "${1%.*}"; }

DIR_LABEL=""
if [ -n "$CWD" ]; then
    SHORT="${CWD/#$HOME/~}"
    DIR_LABEL="  ${DIM}·${RESET} ${DIM}${SHORT}${RESET}"
fi
echo -e "${CYAN}${MODEL}${RESET}${DIR_LABEL}"

if [ -n "$FIVE_USED" ]; then
    LINE="5h  $(draw_bar "$FIVE_USED") $(pct_fmt "$FIVE_USED")"
    [ -n "$FIVE_RESET" ] && LINE="$LINE  ${DIM}eta $(eta_str "$FIVE_RESET")${RESET}"
    echo -e "$LINE"
fi

if [ -n "$WEEK_USED" ]; then
    LINE="7d  $(draw_bar "$WEEK_USED") $(pct_fmt "$WEEK_USED")"
    [ -n "$WEEK_RESET" ] && LINE="$LINE  ${DIM}eta $(eta_str "$WEEK_RESET")${RESET}"
    echo -e "$LINE"
fi

# Fallback when subscription rate limits are not exposed yet
if [ -z "$FIVE_USED" ] && [ -z "$WEEK_USED" ] && [ -n "$CTX_USED" ]; then
    echo -e "ctx $(draw_bar "$CTX_USED") $(pct_fmt "$CTX_USED")  ${DIM}context${RESET}"
fi
