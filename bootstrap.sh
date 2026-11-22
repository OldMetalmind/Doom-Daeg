#!/usr/bin/env bash
set -euo pipefail

# Bootstrap a fresh Doom Deag checkout. Set DOOM_DEAG_REPO to use a fork.
REPO_URL="${DOOM_DEAG_REPO:-https://github.com/OldMetalmind/Doom-Daeg}"

usage() {
  cat <<EOF
Usage: ${0##*/} [target-dir]

Clone the Doom Deag repository into TARGET-DIR (default: ./doom-deag).

Environment:
  DOOM_DEAG_REPO   Override the clone URL (useful for forks).
                   Default: $REPO_URL
EOF
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
esac

TARGET_DIR="${1:-./doom-deag}"

if ! command -v git >/dev/null 2>&1; then
  echo "❌ git is required to bootstrap Doom Deag." >&2
  exit 1
fi

if [[ -e "$TARGET_DIR" && -n "$(ls -A "$TARGET_DIR" 2>/dev/null)" ]]; then
  echo "❌ '$TARGET_DIR' already exists and is not empty. Choose a different path." >&2
  exit 1
fi

mkdir -p "$(dirname "$TARGET_DIR")"
echo "🚀 Cloning Doom Deag from $REPO_URL into: $TARGET_DIR"
git clone "$REPO_URL" "$TARGET_DIR"

for required in install.sh uninstall.sh doom/lisp/doom-deag.el eca/config.json; do
  if [[ ! -f "$TARGET_DIR/$required" ]]; then
    echo "❌ Clone finished but '$required' is missing — is $REPO_URL the right repository?" >&2
    exit 1
  fi
done

chmod +x "$TARGET_DIR"/install.sh \
         "$TARGET_DIR"/uninstall.sh \
         "$TARGET_DIR"/bootstrap-doom-deag.sh \
         "$TARGET_DIR"/eca/skills/*/scripts/*.sh

cat <<EOF
✅ Doom Deag bootstrapped at: $TARGET_DIR

Next steps:
  cd "$TARGET_DIR"
  ./install.sh              # symlinks ECA config, copies skills, wires \$DOOMDIR
  SPC a a                   # inside Doom Emacs: start the ECA orchestrator
  /deag "your goal"         # in the ECA chat: plan + delegate + monitor

See README.md and QUICKSTART.md for the full workflow.
EOF
