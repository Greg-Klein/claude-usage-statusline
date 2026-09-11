#!/usr/bin/env bash
# claude-usage-statusline installer
#
#   curl -fsSL https://raw.githubusercontent.com/Greg-Klein/claude-usage-statusline/main/install.sh | bash
#
# Installs statusline.sh into the Claude Code config directory and registers it
# in settings.json. Safe to re-run: it overwrites the script and rewrites only
# the "statusLine" key, keeping a timestamped backup of settings.json.
#
# Env overrides:
#   CLAUDE_CONFIG_DIR   config dir            (default ~/.claude)
#   BRANCH              branch to install     (default main)
#   BAR_WIDTH           bar length in cells   (default: script default, 24)
#   REFRESH             refreshInterval, secs (default 10, 0 disables)
#
# License: MIT
set -euo pipefail

REPO="Greg-Klein/claude-usage-statusline"
BRANCH="${BRANCH:-main}"
RAW_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/statusline.sh"

CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
TARGET="$CONFIG_DIR/statusline.sh"
SETTINGS="$CONFIG_DIR/settings.json"
REFRESH="${REFRESH:-10}"

if [ -t 1 ]; then
    BOLD=$'\033[1m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'
    DIM=$'\033[2m'; RESET=$'\033[0m'
else
    BOLD=""; GREEN=""; YELLOW=""; RED=""; DIM=""; RESET=""
fi

say()  { printf '%s\n' "$*"; }
ok()   { printf '%s✓%s %s\n' "$GREEN" "$RESET" "$*"; }
warn() { printf '%s!%s %s\n' "$YELLOW" "$RESET" "$*"; }
die()  { printf '%s✗%s %s\n' "$RED" "$RESET" "$*" >&2; exit 1; }

# 1. Dependencies
command -v jq >/dev/null 2>&1 || die "jq is required. Install it first: brew install jq / apt install jq"

# 2. Get statusline.sh: prefer the copy sitting next to this script, else download
SELF_DIR=""
case "${BASH_SOURCE[0]:-}" in
    ""|bash|/dev/fd/*|/proc/self/fd/*) ;;
    *) SELF_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd) ;;
esac

TMP=$(mktemp) || die "cannot create a temp file"
trap 'rm -f "$TMP"' EXIT

if [ -n "$SELF_DIR" ] && [ -f "$SELF_DIR/statusline.sh" ]; then
    cp "$SELF_DIR/statusline.sh" "$TMP"
    say "${DIM}using local statusline.sh${RESET}"
else
    command -v curl >/dev/null 2>&1 || die "curl is required to download statusline.sh"
    curl -fsSL "$RAW_URL" -o "$TMP" || die "download failed: $RAW_URL"
    say "${DIM}downloaded $BRANCH/statusline.sh${RESET}"
fi

head -n 1 "$TMP" | grep -q '^#!' || die "downloaded file does not look like a shell script"

# 3. Install the script
mkdir -p "$CONFIG_DIR"
install -m 755 "$TMP" "$TARGET" 2>/dev/null || { cp "$TMP" "$TARGET" && chmod 755 "$TARGET"; }
ok "installed $TARGET"

# 4. Register it in settings.json
COMMAND="$TARGET"
[ -n "${BAR_WIDTH:-}" ] && COMMAND="CLAUDE_BAR_WIDTH=$BAR_WIDTH $TARGET"

STATUSLINE_JSON=$(jq -n --arg cmd "$COMMAND" --argjson refresh "$REFRESH" '
    { type: "command", command: $cmd, padding: 0 }
    + (if $refresh > 0 then { refreshInterval: $refresh } else {} end)
')

if [ -f "$SETTINGS" ]; then
    jq -e . "$SETTINGS" >/dev/null 2>&1 || die "$SETTINGS is not valid JSON. Fix or move it, then re-run."

    PREVIOUS=$(jq -c '.statusLine // empty' "$SETTINGS")
    if [ "$PREVIOUS" = "$(printf '%s' "$STATUSLINE_JSON" | jq -c .)" ]; then
        ok "settings.json already points at it"
    else
        BACKUP="$SETTINGS.bak-$(date +%Y%m%d%H%M%S)"
        cp "$SETTINGS" "$BACKUP"
        jq --argjson sl "$STATUSLINE_JSON" '.statusLine = $sl' "$SETTINGS" > "$SETTINGS.tmp" \
            && mv "$SETTINGS.tmp" "$SETTINGS"
        ok "updated $SETTINGS ${DIM}(backup: $(basename "$BACKUP"))${RESET}"
        [ -n "$PREVIOUS" ] && warn "replaced an existing statusLine setting"
    fi
else
    printf '%s\n' "$STATUSLINE_JSON" | jq '{ statusLine: . }' > "$SETTINGS"
    ok "created $SETTINGS"
fi

# 5. Done
say ""
say "${BOLD}Done.${RESET} Start or resume a Claude Code session to see the bars."
say "${DIM}Preview without Claude Code:${RESET} echo '{}' | $TARGET"
