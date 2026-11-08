#!/bin/zsh

set -euo pipefail

ROOT="${0:A:h:h}"
APP="$ROOT/mac/.build/widget/Build/Products/Release/IELTS Vocabulary Lab.app"
DEST="$HOME/Applications/IELTS Vocabulary Lab.app"
APP_EXECUTABLE="$DEST/Contents/MacOS/IELTS Vocabulary Lab"
OPEN_AFTER_INSTALL=1

for OPTION in "$@"; do
  case "$OPTION" in
    --widget) APP="$ROOT/mac/.build/widget/Build/Products/Release/IELTS Vocabulary Lab.app" ;;
    --no-open) OPEN_AFTER_INSTALL=0 ;;
    *) echo "Usage: $0 [--widget] [--no-open]" >&2; exit 2 ;;
  esac
done

if [[ ! -d "$APP" ]]; then
  echo "App not found: $APP. Build it before installing." >&2
  exit 1
fi
codesign --verify --deep --strict "$APP"

# Prepare and verify the replacement before touching the installed app.
mkdir -p "$HOME/Applications"
STAGING_ROOT="$(mktemp -d "$HOME/Applications/.ielts-install.XXXXXX")"
STAGED_APP="$STAGING_ROOT/IELTS Vocabulary Lab.app"
trap 'rm -rf "$STAGING_ROOT"' EXIT
ditto "$APP" "$STAGED_APP"
codesign --verify --deep --strict "$STAGED_APP"

RUNNING_PID="$(pgrep -f "$APP_EXECUTABLE" | head -n 1 || true)"
if [[ -n "$RUNNING_PID" ]]; then
  /usr/bin/osascript -e 'tell application id "local.ielts.vocabulary.lab.menubar" to quit' >/dev/null 2>&1 || kill -TERM "$RUNNING_PID"
  for _ in {1..30}; do
    if ! kill -0 "$RUNNING_PID" 2>/dev/null; then break; fi
    sleep 0.2
  done
  if kill -0 "$RUNNING_PID" 2>/dev/null; then
    echo "The running app did not quit. Quit it from the menu bar and retry." >&2
    exit 1
  fi
fi

if [[ -d "$DEST" ]]; then
  PREVIOUS_APP="$STAGING_ROOT/previous.app"
  mv "$DEST" "$PREVIOUS_APP"
  if ! mv "$STAGED_APP" "$DEST"; then
    mv "$PREVIOUS_APP" "$DEST"
    echo "Installation failed; restored the previous application." >&2
    exit 1
  fi
else
  mv "$STAGED_APP" "$DEST"
fi

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [[ -x "$LSREGISTER" ]]; then
  "$LSREGISTER" -f "$DEST"
fi
if [[ "$OPEN_AFTER_INSTALL" == 1 ]]; then
  open -n "$DEST"
fi
echo "Installed $DEST"
