#!/usr/bin/env bash
# Garry's Count Viewer - management CLI
# Usage: garry-viewer.sh start|stop|status|open|install-autostart|uninstall-autostart

set -euo pipefail

GARRYS_DIR="${HOME}/.claude/garryscount"
CONFIG_FILE="${GARRYS_DIR}/config.json"
VIEWER_PY="${GARRYS_DIR}/viewer.py"
PLIST_LABEL="com.garryscount.viewer"
PLIST_PATH="${HOME}/Library/LaunchAgents/${PLIST_LABEL}.plist"

# Read port from config (default 7777)
VIEWER_PORT=$(jq -r '.viewer_port // 7777' "$CONFIG_FILE" 2>/dev/null || echo 7777)

# Find python3
PYTHON3=$(command -v python3 2>/dev/null || echo "/usr/bin/python3")

case "${1:-status}" in
  start)
    if ! [[ -f "$VIEWER_PY" ]]; then
      echo "Error: $VIEWER_PY not found. Run install.sh first."
      exit 1
    fi
    if lsof -ti ":${VIEWER_PORT}" >/dev/null 2>&1; then
      echo "Viewer already running at http://localhost:${VIEWER_PORT}"
    else
      nohup "$PYTHON3" "$VIEWER_PY" > "${GARRYS_DIR}/viewer.log" 2>&1 &
      disown
      sleep 0.3
      if lsof -ti ":${VIEWER_PORT}" >/dev/null 2>&1; then
        echo "Started viewer at http://localhost:${VIEWER_PORT}"
      else
        echo "Failed to start viewer. Check ${GARRYS_DIR}/viewer.log"
        exit 1
      fi
    fi
    ;;

  stop)
    PID=$(lsof -ti ":${VIEWER_PORT}" 2>/dev/null || true)
    if [[ -n "$PID" ]]; then
      kill "$PID"
      echo "Stopped viewer (pid $PID)"
    else
      echo "Viewer not running on port ${VIEWER_PORT}"
    fi
    ;;

  restart)
    PID=$(lsof -ti ":${VIEWER_PORT}" 2>/dev/null || true)
    if [[ -n "$PID" ]]; then
      kill "$PID"
    fi
    sleep 0.3
    nohup "$PYTHON3" "$VIEWER_PY" > "${GARRYS_DIR}/viewer.log" 2>&1 &
    disown
    sleep 0.3
    echo "Restarted viewer at http://localhost:${VIEWER_PORT}"
    ;;

  status)
    if lsof -ti ":${VIEWER_PORT}" >/dev/null 2>&1; then
      echo "Running at http://localhost:${VIEWER_PORT}"
    else
      echo "Not running"
    fi
    ;;

  open)
    if ! lsof -ti ":${VIEWER_PORT}" >/dev/null 2>&1; then
      echo "Viewer not running. Starting..."
      nohup "$PYTHON3" "$VIEWER_PY" > "${GARRYS_DIR}/viewer.log" 2>&1 &
      disown
      sleep 0.5
    fi
    open "http://localhost:${VIEWER_PORT}"
    ;;

  install-autostart)
    if ! [[ -f "$VIEWER_PY" ]]; then
      echo "Error: $VIEWER_PY not found. Run install.sh first."
      exit 1
    fi
    mkdir -p "${HOME}/Library/LaunchAgents"
    cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${PLIST_LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${PYTHON3}</string>
    <string>${VIEWER_PY}</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>${GARRYS_DIR}/viewer.log</string>
  <key>StandardErrorPath</key>
  <string>${GARRYS_DIR}/viewer.log</string>
</dict>
</plist>
EOF
    launchctl load "$PLIST_PATH" 2>/dev/null || true
    # Also start immediately
    if ! lsof -ti ":${VIEWER_PORT}" >/dev/null 2>&1; then
      launchctl start "$PLIST_LABEL" 2>/dev/null || true
      sleep 0.5
    fi
    echo "Auto-start installed. Viewer will run on login at http://localhost:${VIEWER_PORT}"
    ;;

  uninstall-autostart)
    if [[ -f "$PLIST_PATH" ]]; then
      launchctl unload "$PLIST_PATH" 2>/dev/null || true
      rm -f "$PLIST_PATH"
      echo "Removed auto-start LaunchAgent"
    else
      echo "Auto-start not installed"
    fi
    ;;

  *)
    echo "Usage: garry-viewer.sh <command>"
    echo ""
    echo "Commands:"
    echo "  start               Start the viewer server"
    echo "  stop                Stop the viewer server"
    echo "  restart             Restart the viewer server"
    echo "  status              Show whether the viewer is running"
    echo "  open                Open the viewer in your browser"
    echo "  install-autostart   Set up LaunchAgent to auto-start on login"
    echo "  uninstall-autostart Remove the LaunchAgent"
    exit 1
    ;;
esac
