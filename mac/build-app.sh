#!/bin/zsh

set -euo pipefail
ROOT="${0:A:h:h}"
exec "$ROOT/mac/build-widget-app.sh" "$@"
