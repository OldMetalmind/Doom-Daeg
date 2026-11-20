#!/usr/bin/env bash
set -euo pipefail

ELISP_CODE="${1:?Usage: eval-elisp.sh '<elisp-expression>'}"

if emacsclient -e "(+ 1 1)" >/dev/null 2>&1; then
  echo "Evaluating in live Emacs session..."
  emacsclient -e "$ELISP_CODE"
else
  echo "No live Emacs server found (run M-x server-start). Validating syntax in batch mode..."
  emacs --batch --eval "(progn $ELISP_CODE)"
fi
