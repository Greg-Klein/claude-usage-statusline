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
EFFORT=$(echo "$input"    | jq -r '.effort.level // empty')
CTX_USED=$(echo "$input"  | jq -r '.context_window.used_percentage // empty')
FIVE_USED=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
FIVE_RESET=$(echo "$input"| jq -r '.rate_limits.five_hour.resets_at // empty')
WEEK_USED=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
WEEK_RESET=$(echo "$input"| jq -r '.rate_limits.seven_day.resets_at // empty')

# Explicit 256-colour codes rather than ANSI 30-37: the base colours are
# remapped by the terminal theme, and a dark theme green sinks into the grey
# of the unfilled cells.
GREEN=$'\033[38;5;46m'; YELLOW=$'\033[38;5;226m'; RED=$'\033[38;5;196m'
DIM=$'\033[2m'; CYAN=$'\033[36m'; RESET=$'\033[0m'

WIDTH=${CLAUDE_BAR_WIDTH:-24}
WARN=${CLAUDE_BAR_WARN:-60}
CRIT=${CLAUDE_BAR_CRIT:-85}
# Braille dots are round and inset on all four sides, so cells never touch
# each other and rows never touch the row above. Each cell holds two columns
# of dots, which buys back a half-cell of precision.
#
# U+2800..U+28FF is missing from several common terminal fonts (Menlo, Monaco,
# SF Mono). Terminals then fall back to another font, which may render the
# glyph at a different advance width and skew the line. CLAUDE_BAR_STYLE=blocks
# switches to block glyphs, which every terminal font carries.
case "${CLAUDE_BAR_STYLE:-braille}" in
    blocks) FULL="▉"; HALF="▌" ;;
    *)      FULL="⣿"; HALF="⡇" ;;
esac
SPENT=$'\033[38;5;235m'   # unfilled cells: same glyph, just unlit

# draw_bar <used_pct> -> "[▉▉▉▉▉▊░░░░]" colored by how full it is
draw_bar() {
    local used=${1%.*}
    local width=${2:-$WIDTH}
    [ -z "$used" ] && used=0
    [ "$used" -lt 0 ] && used=0
    [ "$used" -gt 100 ] && used=100

    local color="$GREEN"
    [ "$used" -ge "$WARN" ] && color="$YELLOW"
    [ "$used" -ge "$CRIT" ] && color="$RED"

    local halves=$(( (used * width * 2 + 50) / 100 ))
    [ "$halves" -gt $((width * 2)) ] && halves=$((width * 2))
    local cells=$((halves / 2))
    local rem=$((halves % 2))
    local empty=$((width - cells - rem))

    local filled="" blank=""
    [ "$cells" -gt 0 ] && { printf -v f "%${cells}s"; filled="${f// /$FULL}"; }
    [ "$rem" -gt 0 ] && filled="${filled}${HALF}"
    [ "$empty" -gt 0 ] && { printf -v e "%${empty}s"; blank="${e// /$FULL}"; }

    printf '%s[%s%s%s%s%s%s]%s' "$DIM" "$color" "$filled" "$SPENT" "$blank" "$RESET" "$DIM" "$RESET"
}

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
MODEL_LABEL="${CYAN}${MODEL}${RESET}"
[ -n "$EFFORT" ] && MODEL_LABEL="${MODEL_LABEL} ${DIM}${EFFORT}${RESET}"

echo -e "${MODEL_LABEL}${DIR_LABEL}"

# The context bar rides in a second column beside the first rate-limit bar, so
# all three sit in the same band instead of breaking up the header.
CTX_BAR=""
[ -n "$CTX_USED" ] && CTX_BAR="context $(draw_bar "$CTX_USED" $((WIDTH / 2))) $(pct_fmt "$CTX_USED")"

if [ -n "$FIVE_USED" ]; then
    LINE="5h  $(draw_bar "$FIVE_USED") $(pct_fmt "$FIVE_USED")"
    [ -n "$FIVE_RESET" ] && LINE="$LINE  ${DIM}eta $(eta_str "$FIVE_RESET")${RESET}"
    [ -n "$CTX_BAR" ] && { LINE="$LINE    $CTX_BAR"; CTX_BAR=""; }
    echo -e "$LINE"
fi

if [ -n "$WEEK_USED" ]; then
    LINE="7d  $(draw_bar "$WEEK_USED") $(pct_fmt "$WEEK_USED")"
    [ -n "$WEEK_RESET" ] && LINE="$LINE  ${DIM}eta $(eta_str "$WEEK_RESET")${RESET}"
    [ -n "$CTX_BAR" ] && { LINE="$LINE    $CTX_BAR"; CTX_BAR=""; }
    echo -e "$LINE"
fi

# Only reached when neither rate-limit window was present to carry it
if [ -n "$CTX_BAR" ]; then
    echo -e "$CTX_BAR"
fi

exit 0
