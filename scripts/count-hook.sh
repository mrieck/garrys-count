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
COUNT_MODE="default"
EDITOR_TYPE="none"
if [[ -f "$CONFIG_FILE" ]]; then
  RESET_HOUR=$(echo "$CONFIG_FILE" | xargs cat | jq -r '.reset_hour // 5')
  COUNT_MODE=$(echo "$CONFIG_FILE" | xargs cat | jq -r '.count_mode // "default"')
  EDITOR_TYPE=$(echo "$CONFIG_FILE" | xargs cat | jq -r '.editor // "none"')
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

# Extract tool name and file path
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Plan files appear in the viewer but don't count toward LOC
SKIP_COUNT=0
if [[ "$FILE_PATH" == *"/.claude/plans/"* ]]; then
  SKIP_COUNT=1
fi

# Extract file extension for per-language tracking
EXT=""
if [[ -n "$FILE_PATH" ]]; then
  BASENAME="${FILE_PATH##*/}"
  if [[ "$BASENAME" == *.* ]]; then
    EXT=".${BASENAME##*.}"
  fi
fi

# Detect git repo root for this file
GIT_REPO=""
if [[ -n "$FILE_PATH" ]]; then
  GIT_REPO=$(git -C "$(dirname "$FILE_PATH")" rev-parse --show-toplevel 2>/dev/null || true)
fi

# Count lines based on tool type and counting mode
LINES=0

case "$TOOL_NAME" in
  Write)
    LINES=$(echo "$INPUT" | jq -r '.tool_input.content // empty' | wc -l | tr -d ' ')
    ;;
  Edit)
    if [[ "$COUNT_MODE" == "yc-mode" ]]; then
      # YC mode: count all new lines written
      LINES=$(echo "$INPUT" | jq -r '.tool_input.new_string // empty' | wc -l | tr -d ' ')
    else
      # Default mode: net new lines only
      NEW_LINES=$(echo "$INPUT" | jq -r '.tool_input.new_string // empty' | wc -l | tr -d ' ')
      OLD_LINES=$(echo "$INPUT" | jq -r '.tool_input.old_string // empty' | wc -l | tr -d ' ')
      LINES=$((NEW_LINES - OLD_LINES))
    fi
    ;;
  MultiEdit)
    if [[ "$COUNT_MODE" == "yc-mode" ]]; then
      # YC mode: count all new lines
      LINES=$(echo "$INPUT" | jq -r '
        [.tool_input.edits[] |
          ((.new_string // "") | split("\n") | length)
        ] | add // 0
      ')
    else
      # Default mode: net new lines only
      LINES=$(echo "$INPUT" | jq -r '
        [.tool_input.edits[] |
          ((.new_string // "") | split("\n") | length) -
          ((.old_string // "") | split("\n") | length)
        ] | add // 0
      ')
    fi
    ;;
  *)
    exit 0
    ;;
esac

# Plan files: don't count lines but still record the file entry
if [[ "$SKIP_COUNT" -eq 1 ]]; then
  LINES=0
fi

# Nothing to record
if [[ "$LINES" -eq 0 ]] && [[ -z "$GIT_REPO" ]] && [[ "$SKIP_COUNT" -eq 0 ]]; then
  exit 0
fi

# Ensure directory exists
mkdir -p "$GARRYS_DIR"

# Atomic update: read current tally, add lines, write to temp, mv into place
CURRENT_TOTAL=0
CURRENT_BY_EXT='{}'
CURRENT_REPOS='[]'
CURRENT_FILES='[]'
if [[ -f "$TALLY_FILE" ]]; then
  CURRENT_TOTAL=$(jq -r '.total_lines // 0' "$TALLY_FILE" 2>/dev/null || echo 0)
  CURRENT_BY_EXT=$(jq -r '.by_extension // {}' "$TALLY_FILE" 2>/dev/null || echo '{}')
  CURRENT_REPOS=$(jq -c '.repos // []' "$TALLY_FILE" 2>/dev/null || echo '[]')
  CURRENT_FILES=$(jq -c '.files_edited // []' "$TALLY_FILE" 2>/dev/null || echo '[]')
fi

# Build file entry for tracking
FILE_ENTRY=""
if [[ -n "$FILE_PATH" ]]; then
  FILE_ENTRY=$(jq -n \
    --arg path "$FILE_PATH" \
    --arg project "${GIT_REPO:-}" \
    --arg time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{"path":$path,"project":$project,"time":$time}')
fi

NEW_TOTAL=$((CURRENT_TOTAL + LINES))

# Floor at 0 (net mode could go negative across edits)
if [[ "$NEW_TOTAL" -lt 0 ]]; then
  NEW_TOTAL=0
fi

# Update per-extension breakdown
if [[ -n "$EXT" ]]; then
  NEW_BY_EXT=$(echo "$CURRENT_BY_EXT" | jq --arg ext "$EXT" --argjson lines "$LINES" '
    .[$ext] = ((.[$ext] // 0) + $lines) |
    with_entries(select(.value > 0))
  ')
else
  NEW_BY_EXT="$CURRENT_BY_EXT"
fi

# Update repos list (deduplicated)
NEW_REPOS="$CURRENT_REPOS"
if [[ -n "$GIT_REPO" ]]; then
  NEW_REPOS=$(printf '%s' "$CURRENT_REPOS" | jq --arg repo "$GIT_REPO" \
    'if any(. == $repo) then . else . + [$repo] end')
fi

# Update files_edited list (upsert by path, cap at 500)
NEW_FILES="$CURRENT_FILES"
if [[ -n "$FILE_ENTRY" ]]; then
  NEW_FILES=$(printf '%s' "$CURRENT_FILES" | jq \
    --argjson entry "$FILE_ENTRY" \
    'map(select(.path != $entry.path)) + [$entry] | .[-500:]')
fi

TEMP_FILE=$(mktemp "${GARRYS_DIR}/.tally.XXXXXX")
jq -n \
  --arg date "$EFFECTIVE_DATE" \
  --argjson total "$NEW_TOTAL" \
  --arg mode "$COUNT_MODE" \
  --arg updated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson by_ext "$NEW_BY_EXT" \
  --argjson repos "$NEW_REPOS" \
  --argjson files "$NEW_FILES" \
  '{"date":$date,"total_lines":$total,"count_mode":$mode,"last_updated":$updated,"by_extension":$by_ext,"repos":$repos,"files_edited":$files}' \
  > "$TEMP_FILE"

mv "$TEMP_FILE" "$TALLY_FILE"

# Auto-start garry-viewer if configured and not running
if [[ "$EDITOR_TYPE" == "garry-viewer" ]] && [[ -f "${GARRYS_DIR}/viewer.py" ]]; then
  VIEWER_PORT=$(jq -r '.viewer_port // 7777' "$CONFIG_FILE" 2>/dev/null || echo 7777)
  if ! lsof -ti ":${VIEWER_PORT}" >/dev/null 2>&1; then
    nohup python3 "${GARRYS_DIR}/viewer.py" > "${GARRYS_DIR}/viewer.log" 2>&1 &
    disown
  fi
fi
