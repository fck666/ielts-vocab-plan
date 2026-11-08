#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
MODE="${1:-build}"
if [[ "$MODE" != "build" && "$MODE" != "--check" && "$MODE" != "--unsigned" ]]; then
  echo "Usage: $0 [--check|--unsigned] (optional override: DEVELOPMENT_TEAM=TEAM_ID)" >&2
  exit 2
fi

if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

MISSING=0
if ! xcrun --find xcodebuild >/dev/null 2>&1; then
  echo "Missing full Xcode. Install Xcode, or set DEVELOPER_DIR to Xcode.app/Contents/Developer." >&2
  MISSING=1
fi
if ! xcrun --find appintentsmetadataprocessor >/dev/null 2>&1; then
  echo "Missing Xcode App Intents metadata processor; Command Line Tools alone cannot build this widget." >&2
  MISSING=1
fi
if [[ "$MISSING" == 1 ]]; then exit 2; fi
if [[ "$MODE" == "--check" ]]; then
  xcrun xcodebuild -version
  xcrun --find appintentsmetadataprocessor
  security find-identity -v -p codesigning
  exit 0
fi

SIGNING=()
if [[ "$MODE" == "--unsigned" ]]; then
  SIGNING=(CODE_SIGNING_ALLOWED=NO)
elif [[ -n "${DEVELOPMENT_TEAM:-}" ]]; then
  SIGNING=("DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM")
fi

xcrun xcodebuild \
  -project "$ROOT/mac/IELTSVocabularyLab.xcodeproj" \
  -scheme "IELTS Vocabulary Lab" \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -derivedDataPath "$ROOT/mac/.build/widget" \
  "${SIGNING[@]}" build

APP="$ROOT/mac/.build/widget/Build/Products/Release/IELTS Vocabulary Lab.app"
EXTENSION="$APP/Contents/PlugIns/IELTSVocabularyWidget.appex"
test -f "$EXTENSION/Contents/Resources/Metadata.appintents/extract.actionsdata"
test -f "$EXTENSION/Contents/Resources/words.json"
for RESOURCE in words native-speaking-plan native-writing-plan zh-CN ja ko fr es ar; do
  test -s "$APP/Contents/Resources/$RESOURCE.json"
done
if [[ "$MODE" == "--unsigned" ]]; then
  echo "Built unsigned validation bundle: $APP"
  echo "System widget installation still requires valid code signing and Gallery verification."
else
  codesign --verify --deep --strict "$APP"
  echo "Built sandboxed SwiftUI learning app and WidgetKit extension: $APP"
  echo "Install from Xcode or follow docs/native-widget-setup.md; the running app has not been replaced."
fi
