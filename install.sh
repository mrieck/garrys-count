#!/usr/bin/env bash
# Garry's Count - Install script
# Sets up the status line and hooks for Claude Code.

set -euo pipefail

GARRYS_DIR="${HOME}/.claude/garryscount"
SETTINGS_FILE="${HOME}/.claude/settings.json"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "🔢 Installing Garry's Count..."
echo ""

# Check for jq
if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required but not installed."
  echo "  macOS:  brew install jq"
  echo "  Linux:  sudo apt install jq"
  exit 1
fi

# Create data directory
mkdir -p "$GARRYS_DIR"

# Copy scripts
cp "$SCRIPT_DIR/scripts/count-hook.sh" "$GARRYS_DIR/count-hook.sh"
cp "$SCRIPT_DIR/scripts/statusline.sh" "$GARRYS_DIR/statusline.sh"
chmod +x "$GARRYS_DIR/count-hook.sh"
chmod +x "$GARRYS_DIR/statusline.sh"

# Create default config if it doesn't exist
if [[ ! -f "$GARRYS_DIR/config.json" ]]; then
  cat > "$GARRYS_DIR/config.json" <<'EOF'
{
  "reset_hour": 5,
  "count_mode": "garry"
}
EOF
  echo "Created config at $GARRYS_DIR/config.json"
fi

# Add statusLine to settings.json
if [[ ! -f "$SETTINGS_FILE" ]]; then
  echo '{}' > "$SETTINGS_FILE"
fi

# Check if statusLine already configured
if jq -e '.statusLine' "$SETTINGS_FILE" >/dev/null 2>&1; then
  echo "Warning: statusLine already configured in $SETTINGS_FILE"
  echo "Current value:"
  jq '.statusLine' "$SETTINGS_FILE"
  echo ""
  read -p "Overwrite? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Skipping statusLine config. You can manually set it to:"
    echo "  \"statusLine\": {\"command\": \"$GARRYS_DIR/statusline.sh\"}"
    echo ""
  else
    TEMP=$(mktemp)
    jq --arg cmd "$GARRYS_DIR/statusline.sh" '.statusLine = {"type": "command", "command": $cmd}' "$SETTINGS_FILE" > "$TEMP"
    mv "$TEMP" "$SETTINGS_FILE"
    echo "Updated statusLine in $SETTINGS_FILE"
  fi
else
  TEMP=$(mktemp)
  jq --arg cmd "$GARRYS_DIR/statusline.sh" '.statusLine = {"type": "command", "command": $cmd}' "$SETTINGS_FILE" > "$TEMP"
  mv "$TEMP" "$SETTINGS_FILE"
  echo "Added statusLine to $SETTINGS_FILE"
fi

# Add hooks to settings.json
HOOK_CMD="$GARRYS_DIR/count-hook.sh"
if jq -e '.hooks.PostToolUse' "$SETTINGS_FILE" >/dev/null 2>&1; then
  # Check if our hook is already there
  EXISTING=$(jq --arg cmd "$HOOK_CMD" '[.hooks.PostToolUse[].hooks[]? | select(.command == $cmd)] | length' "$SETTINGS_FILE" 2>/dev/null || echo 0)
  if [[ "$EXISTING" -gt 0 ]]; then
    echo "Hook already configured in $SETTINGS_FILE"
  else
    TEMP=$(mktemp)
    jq --arg cmd "$HOOK_CMD" '.hooks.PostToolUse += [{"matcher": "Write|Edit|MultiEdit", "hooks": [{"type": "command", "command": $cmd}]}]' "$SETTINGS_FILE" > "$TEMP"
    mv "$TEMP" "$SETTINGS_FILE"
    echo "Added hook to existing PostToolUse hooks in $SETTINGS_FILE"
  fi
else
  TEMP=$(mktemp)
  jq --arg cmd "$HOOK_CMD" '.hooks = (.hooks // {}) + {"PostToolUse": [{"matcher": "Write|Edit|MultiEdit", "hooks": [{"type": "command", "command": $cmd}]}]}' "$SETTINGS_FILE" > "$TEMP"
  mv "$TEMP" "$SETTINGS_FILE"
  echo "Added PostToolUse hook to $SETTINGS_FILE"
fi

echo ""
echo "Done! Garry's Count is installed."
echo ""
echo "Configuration: $GARRYS_DIR/config.json"
echo "  count_mode: \"garry\" (overcounts, funnier) or \"net\" (realistic)"
echo "  reset_hour: 5 (daily count resets at 5am)"
echo ""
echo "Restart Claude Code to see your count in the status bar."
