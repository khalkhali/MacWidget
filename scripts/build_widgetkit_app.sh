#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_NAME="CPUUsageWidget"
PROJECT_PATH="$ROOT_DIR/${PROJECT_NAME}.xcodeproj"
DERIVED_DATA_PATH="$HOME/Library/Developer/Xcode/DerivedData/${PROJECT_NAME}Local"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/Debug/CPU Usage.app"

cd "$ROOT_DIR"

# Clear Desktop/iCloud metadata from source files so WidgetKit signing stays valid.
xattr -cr App WidgetExtension Shared Resources project.yml Package.swift README.md 2>/dev/null || true

xcodegen generate

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "CPUUsage" \
  -configuration Debug \
  -destination "platform=macOS" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="-" \
  DEVELOPMENT_TEAM="" \
  build

if pgrep -f "$APP_PATH/Contents/MacOS/CPU Usage" >/dev/null 2>&1; then
  pkill -f "$APP_PATH/Contents/MacOS/CPU Usage" || true
  sleep 1
fi

open "$APP_PATH"

echo
echo "Built and launched:"
echo "  $APP_PATH"
echo
echo "Widget registered bundle id:"
pluginkit -m -A -D | rg 'local\.ariarahimi\.cpuusage\.widget' || true
