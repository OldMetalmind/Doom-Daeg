#!/usr/bin/env bash
set -euo pipefail

WRAPPER="$HOME/.config/eca/skills/osc-agent-spawn/scripts/osc7501-wrap.sh"

if [[ -x "$HOME/.config/emacs/bin/doom" ]]; then
  DOOM_BIN="$HOME/.config/emacs/bin/doom"
elif [[ -x "$HOME/.emacs.d/bin/doom" ]]; then
  DOOM_BIN="$HOME/.emacs.d/bin/doom"
elif command -v doom >/dev/null 2>&1; then
  DOOM_BIN="$(command -v doom)"
else
  echo "❌ Could not locate 'doom' binary." >&2
  exit 1
fi

if [[ -x "$WRAPPER" ]]; then
  exec "$WRAPPER" "doom-sync" "$DOOM_BIN sync"
else
  exec "$DOOM_BIN" sync
fi
