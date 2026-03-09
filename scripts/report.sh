#!/usr/bin/env bash
# Garry's Count - Report generator
# Reads daily tally files and outputs a JSON report for the /garryscount skill.

set -euo pipefail

GARRYS_DIR="${HOME}/.claude/garryscount"
CONFIG_FILE="${GARRYS_DIR}/config.json"

# Load config
RESET_HOUR=5
COUNT_MODE="default"
if [[ -f "$CONFIG_FILE" ]]; then
  RESET_HOUR=$(jq -r '.reset_hour // 5' "$CONFIG_FILE" 2>/dev/null || echo 5)
  COUNT_MODE=$(jq -r '.count_mode // "default"' "$CONFIG_FILE" 2>/dev/null || echo "default")
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

# Read today's tally (normalize: ensure by_extension always present)
TODAY_FILE="${GARRYS_DIR}/${EFFECTIVE_DATE}.json"
TODAY_DATA='{"date":"'"$EFFECTIVE_DATE"'","total_lines":0,"by_extension":{}}'
if [[ -f "$TODAY_FILE" ]]; then
  TODAY_DATA=$(jq '.by_extension //= {}' "$TODAY_FILE" 2>/dev/null || echo "$TODAY_DATA")
fi

# Collect last 7 days of data
WEEK_DAYS='[]'
WEEK_TOTAL=0
DAYS_WITH_DATA=0

# Convert effective date to epoch for reliable date arithmetic
if date -j -v-0d -f "%Y-%m-%d" "$EFFECTIVE_DATE" +%s >/dev/null 2>&1; then
  IS_MACOS=true
else
  IS_MACOS=false
fi

for i in $(seq 0 6); do
  if [[ "$IS_MACOS" == true ]]; then
    DAY_DATE=$(date -j -v-${i}d -f "%Y-%m-%d" "$EFFECTIVE_DATE" +%Y-%m-%d)
  else
    DAY_DATE=$(date -d "$EFFECTIVE_DATE - ${i} days" +%Y-%m-%d)
  fi

  DAY_FILE="${GARRYS_DIR}/${DAY_DATE}.json"
  if [[ -f "$DAY_FILE" ]]; then
    DAY_TOTAL=$(jq -r '.total_lines // 0' "$DAY_FILE" 2>/dev/null || echo 0)
    WEEK_DAYS=$(echo "$WEEK_DAYS" | jq --arg date "$DAY_DATE" --argjson total "$DAY_TOTAL" '. + [{"date": $date, "total_lines": $total}]')
    WEEK_TOTAL=$((WEEK_TOTAL + DAY_TOTAL))
    DAYS_WITH_DATA=$((DAYS_WITH_DATA + 1))
  else
    WEEK_DAYS=$(echo "$WEEK_DAYS" | jq --arg date "$DAY_DATE" '. + [{"date": $date, "total_lines": 0}]')
  fi
done

HAS_FULL_WEEK="false"
if [[ "$DAYS_WITH_DATA" -ge 7 ]]; then
  HAS_FULL_WEEK="true"
fi

# Build final report JSON
jq -n \
  --argjson today "$TODAY_DATA" \
  --argjson week_days "$WEEK_DAYS" \
  --argjson week_total "$WEEK_TOTAL" \
  --argjson has_full_week "$HAS_FULL_WEEK" \
  --argjson days_with_data "$DAYS_WITH_DATA" \
  --arg count_mode "$COUNT_MODE" \
  --argjson reset_hour "$RESET_HOUR" \
  '{
    "today": $today,
    "week": {
      "days": $week_days,
      "total_lines": $week_total,
      "has_full_week": $has_full_week,
      "days_with_data": $days_with_data
    },
    "config": {
      "count_mode": $count_mode,
      "reset_hour": $reset_hour
    }
  }'
