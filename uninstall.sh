#!/usr/bin/env bash
set -euo pipefail

ECA_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/eca"

if [[ -n "${DOOMDIR:-}" && -d "$DOOMDIR" ]]; then
  TARGET_DOOMDIR="$DOOMDIR"
elif [[ -d "$HOME/.config/doom" ]]; then
  TARGET_DOOMDIR="$HOME/.config/doom"
elif [[ -d "$HOME/.doom.d" ]]; then
  TARGET_DOOMDIR="$HOME/.doom.d"
else
  echo "Could not detect DOOMDIR." >&2
  exit 1
fi

remove_fenced_block() {
  local file="$1"
  local start_marker=";; >>> doom-deag >>>"
  local end_marker=";; <<< doom-deag <<<"

  if [[ -f "$file" ]] && grep -qF "$start_marker" "$file"; then
    awk -v s="$start_marker" -v e="$end_marker" '
      $0 == s { skip=1; next }
      $0 == e { skip=0; next }
      !skip { print }
    ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
  fi
}

rm -f "$ECA_DIR/AGENTS.md" "$ECA_DIR/config.json" "$ECA_DIR/agents" "$ECA_DIR/rules" "$ECA_DIR/skills" "$ECA_DIR/commands"
rm -f "$TARGET_DOOMDIR/lisp/doom-deag.el"

remove_fenced_block "$TARGET_DOOMDIR/packages.el"
remove_fenced_block "$TARGET_DOOMDIR/config.el"

echo "🧹 Removed Doom Deag links and config blocks. Run 'doom sync' to prune the eca package."
