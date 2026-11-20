#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="${1:-./doom-deag}"

echo "🚀 Bootstrapping Doom Deag repository at: $TARGET_DIR"

mkdir -p \
  "$TARGET_DIR/eca/agents" \
  "$TARGET_DIR/eca/rules" \
  "$TARGET_DIR/eca/skills/doom-self-build/scripts" \
  "$TARGET_DIR/eca/skills/osc-agent-spawn/scripts" \
  "$TARGET_DIR/eca/commands" \
  "$TARGET_DIR/doom/lisp"

# ------------------------------------------------------------------------------
# 1. README.md
# ------------------------------------------------------------------------------
cat <<'EOF' > "$TARGET_DIR/README.md"
# Doom Deag (`doom-deag`)

Self-building AI workspace and **OSC 7501** multi-agent orchestration for **Doom Emacs**, combining Herdr's terminal-agent architecture with **ECA (`eca.dev`)**.

## Prerequisites
- An existing **Doom Emacs** installation (`~/.config/doom` or `~/.doom.d`) with `:term vterm` enabled in `init.el`.
- `emacsclient` available in your `$PATH`.

## Installation
```bash
git clone [https://github.com/](https://github.com/)<your-username>/doom-deag.git ~/.local/share/doom-deag
cd ~/.local/share/doom-deag
./install.sh
