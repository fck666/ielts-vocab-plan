#!/bin/zsh
set -euo pipefail
ROOT="${0:A:h:h}"
CHECK_DIR="$(mktemp -d)"
trap 'rm -rf "$CHECK_DIR"' EXIT

plutil -lint "$ROOT/mac/IELTSVocabularyLab.xcodeproj/project.pbxproj" \
  "$ROOT/mac/App-Info.plist" "$ROOT/mac/Widget-Info.plist" "$ROOT/mac/App.entitlements" \
  "$ROOT/mac/Widget.entitlements" "$ROOT/mac/PrivacyInfo.xcprivacy"
swiftc "$ROOT/mac/WidgetVocabularyStore.swift" "$ROOT/mac/tests/WidgetVocabularyStoreChecks.swift" \
  -parse-as-library -o "$CHECK_DIR/store-checks"
"$CHECK_DIR/store-checks" "$ROOT/data/words.json"
for ARCH in arm64 x86_64; do
  swiftc -typecheck -parse-as-library -application-extension "$ROOT/mac/WidgetVocabularyStore.swift" "$ROOT/mac/VocabularyWidget.swift" \
    "$ROOT/mac/VocabularySpeech.swift" "$ROOT/mac/VocabularySpeechIntent.swift" \
    -framework AppIntents -framework Foundation -framework SwiftUI -framework WidgetKit \
    -target "$ARCH-apple-macosx14.0"
done
echo "Widget source checks passed. Full Xcode build, metadata generation, signing and Widget Gallery acceptance still require separate verification."
