#!/bin/bash
# Preview the status line with fake data, without running Claude Code.
# Usage: ./preview.sh [5h_used_pct] [7d_used_pct]
set -e
cd "$(dirname "$0")"

FIVE=${1:-32}
WEEK=${2:-88}
NOW=$(date +%s)

printf '{
  "model": { "display_name": "Sonnet 5" },
  "workspace": { "current_dir": "%s/dev/project" },
  "context_window": { "used_percentage": 41 },
  "rate_limits": {
    "five_hour":  { "used_percentage": %s, "resets_at": %s },
    "seven_day":  { "used_percentage": %s, "resets_at": %s }
  }
}' "$HOME" "$FIVE" "$((NOW + 7200))" "$WEEK" "$((NOW + 340000))" | ./statusline.sh
