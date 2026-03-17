#!/bin/zsh

set -euo pipefail

PROJECT_NAME="CPUUsageWidget"
DERIVED_DATA_PATH="$HOME/Library/Developer/Xcode/DerivedData/${PROJECT_NAME}Local"
APP_EXECUTABLE="$DERIVED_DATA_PATH/Build/Products/Debug/CPU Usage.app/Contents/MacOS/CPU Usage"

if pgrep -f "$APP_EXECUTABLE" >/dev/null 2>&1; then
  pkill -f "$APP_EXECUTABLE"
  echo "Stopped CPU Usage.app"
else
  echo "CPU Usage.app is not running"
fi
