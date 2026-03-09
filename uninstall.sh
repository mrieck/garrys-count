#!/usr/bin/env bash
# Garry's Count - Uninstall script

set -euo pipefail

GARRYS_DIR="${HOME}/.claude/garryscount"
SETTINGS_FILE="${HOME}/.claude/settings.json"
HOOK_CMD="$GARRYS_DIR/count-hook.sh"

echo "Uninstalling Garry's Count..."

# Remove statusLine from settings
if [[ -f "$SETTINGS_FILE" ]] && jq -e '.statusLine' "$SETTINGS_FILE" >/dev/null 2>&1; then
  CURRENT_CMD=$(jq -r '.statusLine.command // empty' "$SETTINGS_FILE")
  if [[ "$CURRENT_CMD" == *"garryscount"* ]]; then
    TEMP=$(mktemp)
    jq 'del(.statusLine)' "$SETTINGS_FILE" > "$TEMP"
    mv "$TEMP" "$SETTINGS_FILE"
    echo "Removed statusLine from $SETTINGS_FILE"
  fi
fi

# Remove our hook from settings
if [[ -f "$SETTINGS_FILE" ]] && jq -e '.hooks.PostToolUse' "$SETTINGS_FILE" >/dev/null 2>&1; then
  TEMP=$(mktemp)
  jq --arg cmd "$HOOK_CMD" '.hooks.PostToolUse = [.hooks.PostToolUse[] | select(.hooks | all(.command != $cmd))]' "$SETTINGS_FILE" > "$TEMP"
  mv "$TEMP" "$SETTINGS_FILE"
  # Clean up empty hooks object
  TEMP=$(mktemp)
  jq 'if .hooks.PostToolUse == [] then del(.hooks.PostToolUse) else . end | if .hooks == {} then del(.hooks) else . end' "$SETTINGS_FILE" > "$TEMP"
  mv "$TEMP" "$SETTINGS_FILE"
  echo "Removed hook from $SETTINGS_FILE"
fi

# Ask about data
echo ""
read -p "Delete daily count history? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  rm -rf "$GARRYS_DIR"
  echo "Removed $GARRYS_DIR"
else
  # Just remove scripts, keep data
  rm -f "$GARRYS_DIR/count-hook.sh"
  rm -f "$GARRYS_DIR/statusline.sh"
  rm -f "$GARRYS_DIR/report.sh"
  echo "Removed scripts, kept daily count data in $GARRYS_DIR"
fi

# Remove skill
SKILLS_DIR="${HOME}/.claude/skills/garryscount"
if [[ -d "$SKILLS_DIR" ]]; then
  rm -rf "$SKILLS_DIR"
  echo "Removed /garryscount skill"
fi

echo ""
echo "Garry's Count uninstalled. Restart Claude Code to clear the status bar."
