#!/bin/zsh

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Run TinySnapper
# @raycast.mode silent
#
# Optional parameters:
# @raycast.icon ✂️
# @raycast.packageName TinySnapper
# @raycast.argument1 { "type": "dropdown", "placeholder": "Action", "data": [ { "title": "Start", "value": "start" }, { "title": "Restart", "value": "restart" }, { "title": "Stop", "value": "stop" } ] }

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LABEL="com.andreprado.tinysnapper"
PLIST_PATH="$HOME/Library/LaunchAgents/$LABEL.plist"
APP_PATH="/Applications/TinySnapper.app"
APP_BIN_PATH="$APP_PATH/Contents/MacOS/tinysnapper"
ACTION="${1:-start}"

start_agent() {
  if [[ -f "$PLIST_PATH" ]]; then
    if launchctl print "gui/$(id -u)/$LABEL" >/dev/null 2>&1; then
      exit 0
    fi

    launchctl bootstrap "gui/$(id -u)" "$PLIST_PATH"
    launchctl enable "gui/$(id -u)/$LABEL" >/dev/null 2>&1 || true
    exit 0
  fi

  if [[ ! -d "$APP_PATH" ]]; then
    "$REPO_ROOT/scripts/install-app.sh" >/dev/null
  fi

  if pgrep -f "$APP_BIN_PATH" >/dev/null 2>&1; then
    exit 0
  fi

  open "$APP_PATH"
}

case "$ACTION" in
  start)
    start_agent
    ;;
  restart)
    launchctl bootout "gui/$(id -u)/$LABEL" >/dev/null 2>&1 || true
    start_agent
    ;;
  stop)
    launchctl bootout "gui/$(id -u)/$LABEL" >/dev/null 2>&1 || true
    pkill -f "$APP_BIN_PATH" >/dev/null 2>&1 || true
    ;;
  *)
    echo "Usage: $0 [start|restart|stop]" >&2
    exit 1
    ;;
esac
