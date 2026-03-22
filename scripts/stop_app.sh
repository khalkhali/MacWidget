#!/bin/zsh

set -euo pipefail

PROJECT_NAME="CPUUsageWidget"
DERIVED_DATA_PATH="$HOME/Library/Developer/Xcode/DerivedData/${PROJECT_NAME}Local"
APP_EXECUTABLE="$DERIVED_DATA_PATH/Build/Products/Debug/MacWidget.app/Contents/MacOS/MacWidget"

if pgrep -f "$APP_EXECUTABLE" >/dev/null 2>&1; then
  pkill -f "$APP_EXECUTABLE"
  echo "Stopped MacWidget.app"
else
  echo "MacWidget.app is not running"
fi
