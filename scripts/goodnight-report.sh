#!/usr/bin/env bash
# Garry's Count - Goodnight report
# Reads today's tally and outputs the repos worked on, for the /goodnight-garry skill.

set -euo pipefail

GARRYS_DIR="${HOME}/.claude/garryscount"
CONFIG_FILE="${GARRYS_DIR}/config.json"

# Load config
RESET_HOUR=5
if [[ -f "$CONFIG_FILE" ]]; then
  RESET_HOUR=$(jq -r '.reset_hour // 5' "$CONFIG_FILE" 2>/dev/null || echo 5)
fi

# Compute effective date (before reset_hour = yesterday's date)
CURRENT_HOUR=$(date +%H | sed 's/^0//')
if [[ "$CURRENT_HOUR" -lt "$RESET_HOUR" ]]; then
  if date -v-1d >/dev/null 2>&1; then
    EFFECTIVE_DATE=$(date -v-1d +%Y-%m-%d)
  else
    EFFECTIVE_DATE=$(date -d 'yesterday' +%Y-%m-%d)
  fi
else
  EFFECTIVE_DATE=$(date +%Y-%m-%d)
fi

TALLY_FILE="${GARRYS_DIR}/${EFFECTIVE_DATE}.json"

# Read repos from tally (empty array if missing or no repos tracked yet)
REPOS='[]'
if [[ -f "$TALLY_FILE" ]]; then
  REPOS=$(jq -c '.repos // []' "$TALLY_FILE" 2>/dev/null || echo '[]')
fi

jq -n \
  --arg date "$EFFECTIVE_DATE" \
  --argjson repos "$REPOS" \
  '{"effective_date": $date, "repos": $repos}'
