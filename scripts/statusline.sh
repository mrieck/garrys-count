#!/usr/bin/env bash
# Garry's Count - Status line script
# Reads daily tally and displays LOC count in Claude Code status bar.
# Receives session JSON on stdin from Claude Code.

set -euo pipefail

GARRYS_DIR="${HOME}/.claude/garryscount"
CONFIG_FILE="${GARRYS_DIR}/config.json"

# Load config
RESET_HOUR=5
LABEL="lines of hand-written source code"
SHOW_DIRECTORY="true"
if [[ -f "$CONFIG_FILE" ]]; then
  RESET_HOUR=$(jq -r '.reset_hour // 5' "$CONFIG_FILE" 2>/dev/null || echo 5)
  LABEL=$(jq -r '.label // "lines of hand-written source code"' "$CONFIG_FILE" 2>/dev/null || echo "lines of hand-written source code")
  SHOW_DIRECTORY=$(jq -r '.show_directory // true' "$CONFIG_FILE" 2>/dev/null || echo "true")
fi

# Compute effective date
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

# Read daily total
TOTAL=0
if [[ -f "$TALLY_FILE" ]]; then
  TOTAL=$(jq -r '.total_lines // 0' "$TALLY_FILE" 2>/dev/null || echo 0)
fi

# Format with comma separators (portable)
format_number() {
  local n=$1
  if command -v printf >/dev/null 2>&1; then
    printf "%'d" "$n" 2>/dev/null || echo "$n"
  else
    echo "$n"
  fi
}

FORMATTED=$(format_number "$TOTAL")

# ANSI color based on count
RESET='\033[0m'
if [[ "$TOTAL" -ge 10000 ]]; then
  COLOR='\033[1;35m'  # bright magenta - legendary
elif [[ "$TOTAL" -ge 5000 ]]; then
  COLOR='\033[1;31m'  # bright red - on fire
elif [[ "$TOTAL" -ge 1000 ]]; then
  COLOR='\033[1;33m'  # bright yellow - cooking
else
  COLOR='\033[1;32m'  # bright green - warming up
fi

# Drain stdin (Claude Code sends session JSON but we don't need it)
cat >/dev/null 2>&1 || true

# Optionally append current directory in orange
ORANGE='\033[38;5;208m'
DIR_SUFFIX=""
if [[ "$SHOW_DIRECTORY" != "false" ]]; then
  DIR_DISPLAY="${PWD/#$HOME/~}"
  DIR_SUFFIX=" ${ORANGE}${DIR_DISPLAY}${RESET}"
fi

printf "${COLOR}Garry's Count: %s %s${RESET}${DIR_SUFFIX}" "$FORMATTED" "$LABEL"
