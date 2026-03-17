#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_NAME="CPUUsageWidget"
DERIVED_DATA_PATH="$HOME/Library/Developer/Xcode/DerivedData/${PROJECT_NAME}Local"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/Debug/CPU Usage.app"

if [[ ! -d "$APP_PATH" ]]; then
  "$ROOT_DIR/scripts/build_widgetkit_app.sh"
  exit 0
fi

open "$APP_PATH"

echo "Opened:"
echo "  $APP_PATH"
