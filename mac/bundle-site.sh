#!/bin/sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
SITE="${TARGET_BUILD_DIR:?}/${UNLOCALIZED_RESOURCES_FOLDER_PATH:?}/site"
mkdir -p "$SITE"
for FILE in index.html app.js db.js styles.css; do
  cp "$ROOT/$FILE" "$SITE/$FILE"
done
ditto "$ROOT/data" "$SITE/data"
ditto "$ROOT/vendor" "$SITE/vendor"
cp "$ROOT/vendor/sql.js-LICENSE.txt" "$SITE/vendor/THIRD-PARTY-LICENSES.txt"
cp "$ROOT/vendor/sql.js-AUTHORS.txt" "$SITE/vendor/THIRD-PARTY-AUTHORS.txt"
cp "$ROOT/docs/desktop-widget-prototype.html" "$SITE/widget-prototype.html"
