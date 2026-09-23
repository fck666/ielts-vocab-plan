#!/bin/zsh

set -e
PROJECT_DIR="${0:A:h}"
cd "$PROJECT_DIR"

if ! command -v python3 >/dev/null 2>&1; then
  print "Python 3 is required to start the local site."
  read "?Press Return to close..."
  exit 1
fi

exec python3 "$PROJECT_DIR/serve.py"
