#!/usr/bin/env bash
# Garry's Count - PostToolUse hook
# Counts lines of code Claude writes and tallies them per day.
# Receives JSON on stdin from Claude Code after Write/Edit/MultiEdit.

set -euo pipefail

GARRYS_DIR="${HOME}/.claude/garryscount"
CONFIG_FILE="${GARRYS_DIR}/config.json"

# Read all stdin first
INPUT=$(cat)

# Load config (defaults: reset at 5am, garry mode)
RESET_HOUR=5
COUNT_MODE="garry"
if [[ -f "$CONFIG_FILE" ]]; then
  RESET_HOUR=$(echo "$CONFIG_FILE" | xargs cat | jq -r '.reset_hour // 5')
  COUNT_MODE=$(echo "$CONFIG_FILE" | xargs cat | jq -r '.count_mode // "garry"')
fi

# Compute effective date (before reset_hour = yesterday's date)
CURRENT_HOUR=$(date +%H | sed 's/^0//')
if [[ "$CURRENT_HOUR" -lt "$RESET_HOUR" ]]; then
  # macOS compatible: yesterday's date
  if date -v-1d >/dev/null 2>&1; then
    EFFECTIVE_DATE=$(date -v-1d +%Y-%m-%d)
  else
    EFFECTIVE_DATE=$(date -d 'yesterday' +%Y-%m-%d)
  fi
else
  EFFECTIVE_DATE=$(date +%Y-%m-%d)
fi

TALLY_FILE="${GARRYS_DIR}/${EFFECTIVE_DATE}.json"

# Extract tool name
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# Count lines based on tool type and counting mode
LINES=0

case "$TOOL_NAME" in
  Write)
    LINES=$(echo "$INPUT" | jq -r '.tool_input.content // empty' | wc -l | tr -d ' ')
    ;;
  Edit)
    if [[ "$COUNT_MODE" == "net" ]]; then
      NEW_LINES=$(echo "$INPUT" | jq -r '.tool_input.new_string // empty' | wc -l | tr -d ' ')
      OLD_LINES=$(echo "$INPUT" | jq -r '.tool_input.old_string // empty' | wc -l | tr -d ' ')
      LINES=$((NEW_LINES - OLD_LINES))
      # In net mode, allow negative values (deletions reduce the count)
    else
      # Garry mode: count all new lines written
      LINES=$(echo "$INPUT" | jq -r '.tool_input.new_string // empty' | wc -l | tr -d ' ')
    fi
    ;;
  MultiEdit)
    if [[ "$COUNT_MODE" == "net" ]]; then
      LINES=$(echo "$INPUT" | jq -r '
        [.tool_input.edits[] |
          ((.new_string // "") | split("\n") | length) -
          ((.old_string // "") | split("\n") | length)
        ] | add // 0
      ')
    else
      # Garry mode: count all new lines
      LINES=$(echo "$INPUT" | jq -r '
        [.tool_input.edits[] |
          ((.new_string // "") | split("\n") | length)
        ] | add // 0
      ')
    fi
    ;;
  *)
    exit 0
    ;;
esac

# Nothing to record
if [[ "$LINES" -eq 0 ]]; then
  exit 0
fi

# Ensure directory exists
mkdir -p "$GARRYS_DIR"

# Atomic update: read current tally, add lines, write to temp, mv into place
CURRENT_TOTAL=0
if [[ -f "$TALLY_FILE" ]]; then
  CURRENT_TOTAL=$(jq -r '.total_lines // 0' "$TALLY_FILE" 2>/dev/null || echo 0)
fi

NEW_TOTAL=$((CURRENT_TOTAL + LINES))

# Floor at 0 (net mode could go negative across edits)
if [[ "$NEW_TOTAL" -lt 0 ]]; then
  NEW_TOTAL=0
fi

TEMP_FILE=$(mktemp "${GARRYS_DIR}/.tally.XXXXXX")
cat > "$TEMP_FILE" <<EOF
{"date":"${EFFECTIVE_DATE}","total_lines":${NEW_TOTAL},"count_mode":"${COUNT_MODE}","last_updated":"$(date -u +%Y-%m-%dT%H:%M:%SZ)"}
EOF

mv "$TEMP_FILE" "$TALLY_FILE"
