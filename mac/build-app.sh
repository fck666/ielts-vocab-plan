#!/bin/zsh

set -euo pipefail

ROOT="${0:A:h:h}"
APP="$ROOT/IELTS Vocabulary Lab.app"

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
BUILD_DIR="$(mktemp -d)"
trap 'find "$BUILD_DIR" -type f -delete 2>/dev/null; rmdir "$BUILD_DIR" 2>/dev/null || true' EXIT

for ARCH in arm64 x86_64; do
  swiftc "$ROOT/mac/MenuBarApp.swift" \
    -o "$BUILD_DIR/IELTS Vocabulary Lab-$ARCH" \
    -framework AppKit \
    -framework Foundation \
    -target "$ARCH-apple-macosx13.0"
done

lipo -create \
  "$BUILD_DIR/IELTS Vocabulary Lab-arm64" \
  "$BUILD_DIR/IELTS Vocabulary Lab-x86_64" \
  -output "$APP/Contents/MacOS/IELTS Vocabulary Lab"

chmod +x "$APP/Contents/MacOS/IELTS Vocabulary Lab"

touch "$APP/Contents/Info.plist" "$APP/Contents/Resources/IELTSVocabularyLab.icns" "$APP"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [[ -x "$LSREGISTER" ]]; then
  "$LSREGISTER" -f "$APP"
fi

echo "Built $APP"
