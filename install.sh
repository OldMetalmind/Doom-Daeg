#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ECA_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/eca"
NO_SYNC=false

for arg in "$@"; do
  case "$arg" in
    --no-sync) NO_SYNC=true ;;
  esac
done

# 1. Detect existing Doom Emacs user config directory
if [[ -n "${DOOMDIR:-}" && -d "$DOOMDIR" ]]; then
  TARGET_DOOMDIR="$DOOMDIR"
elif [[ -d "$HOME/.config/doom" ]]; then
  TARGET_DOOMDIR="$HOME/.config/doom"
elif [[ -d "$HOME/.doom.d" ]]; then
  TARGET_DOOMDIR="$HOME/.doom.d"
else
  echo "❌ Could not find an existing Doom Emacs config (~/.config/doom or ~/.doom.d)." >&2
  exit 1
fi

# 2. Detect existing Doom CLI binary
if [[ -x "$HOME/.config/emacs/bin/doom" ]]; then
  DOOM_BIN="$HOME/.config/emacs/bin/doom"
elif [[ -x "$HOME/.emacs.d/bin/doom" ]]; then
  DOOM_BIN="$HOME/.emacs.d/bin/doom"
elif command -v doom >/dev/null 2>&1; then
  DOOM_BIN="$(command -v doom)"
else
  echo "❌ Could not find the 'doom' CLI binary in ~/.config/emacs/bin/doom or ~/.emacs.d/bin/doom." >&2
  exit 1
fi

echo "📂 Detected DOOMDIR: $TARGET_DOOMDIR"
echo "🛠️  Detected Doom CLI: $DOOM_BIN"

# 3. Link ECA configuration, agents, rules, skills, and commands
mkdir -p "$ECA_DIR" "$TARGET_DOOMDIR/lisp"

ln -sfn "$REPO_DIR/AGENTS.md" "$ECA_DIR/AGENTS.md"
ln -sfn "$REPO_DIR/eca/config.json" "$ECA_DIR/config.json"
ln -sfn "$REPO_DIR/eca/agents" "$ECA_DIR/agents"
ln -sfn "$REPO_DIR/eca/rules" "$ECA_DIR/rules"
# Skills are copied (not symlinked) so ECA sees ordinary files in its config dir.
if [[ -L "$ECA_DIR/skills" ]]; then
  rm -f "$ECA_DIR/skills"  # replace a symlink left by an older install
fi
mkdir -p "$ECA_DIR/skills"
cp -R "$REPO_DIR/eca/skills/." "$ECA_DIR/skills/"
chmod +x "$ECA_DIR"/skills/*/scripts/*.sh

ln -sfn "$REPO_DIR/eca/commands" "$ECA_DIR/commands"

# 4. Link Doom Deag runtime module
ln -sfn "$REPO_DIR/doom/lisp/doom-deag.el" "$TARGET_DOOMDIR/lisp/doom-deag.el"

# Helpers to idempotently manage fenced Elisp blocks
strip_fenced_block() {
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

inject_fenced_block() {
  local file="$1"
  local content="$2"
  local start_marker=";; >>> doom-deag >>>"
  local end_marker=";; <<< doom-deag <<<"

  touch "$file"
  strip_fenced_block "$file"
  printf '\n%s\n%s\n%s\n' "$start_marker" "$content" "$end_marker" >> "$file"
}

# 5. Check if eca.dev (eca-emacs) is already declared or installed in Doom Emacs
NEEDS_SYNC=false
touch "$TARGET_DOOMDIR/packages.el"
strip_fenced_block "$TARGET_DOOMDIR/packages.el"

USER_HAS_ECA_DECL=false
if grep -Eq '^[[:space:]]*\(package![[:space:]]+eca\b' "$TARGET_DOOMDIR/packages.el"; then
  USER_HAS_ECA_DECL=true
fi

ECA_PKG_INSTALLED=false
for doom_local in "$HOME/.config/emacs/.local" "$HOME/.emacs.d/.local"; do
  if [[ -d "$doom_local" ]] && find "$doom_local" -maxdepth 5 -name "eca.el" 2>/dev/null | grep -q .; then
    ECA_PKG_INSTALLED=true
    break
  fi
done

if [[ "$USER_HAS_ECA_DECL" == "true" ]]; then
  echo "✅ Found existing (package! eca ...) declaration in $TARGET_DOOMDIR/packages.el."
else
  echo "📦 Adding eca.dev package recipe to $TARGET_DOOMDIR/packages.el..."
  inject_fenced_block "$TARGET_DOOMDIR/packages.el" '(package! eca
  :recipe (:host github
           :repo "editor-code-assistant/eca-emacs"
           :files ("*.el")))'
fi

if [[ "$ECA_PKG_INSTALLED" == "false" ]]; then
  NEEDS_SYNC=true
else
  echo "✅ eca-emacs is already installed in Doom Emacs."
fi

# 6. Inject loader into config.el
inject_fenced_block "$TARGET_DOOMDIR/config.el" '(load! "lisp/doom-deag")'

# 7. Verify :term vterm is enabled in init.el
if [[ -f "$TARGET_DOOMDIR/init.el" ]] && ! grep -Eq '^[[:space:]]*vterm\b' "$TARGET_DOOMDIR/init.el"; then
  echo "⚠️  Warning: 'vterm' appears commented out in $TARGET_DOOMDIR/init.el."
  echo "   Uncomment 'vterm' under :term in init.el so *Agent:* terminals render properly."
fi

# 8. Run doom sync only if eca wasn't already installed
if [[ "$NO_SYNC" == "false" && "$NEEDS_SYNC" == "true" ]]; then
  echo "🔄 Installing eca-emacs via doom sync..."
  "$DOOM_BIN" sync
elif [[ "$NEEDS_SYNC" == "false" ]]; then
  echo "⏭️  Skipping doom sync (eca-emacs already installed)."
else
  echo "⏭️  Skipping doom sync (--no-sync)."
fi

# 9. Ensure the external `eca` server binary is installed
if ! command -v eca >/dev/null 2>&1 && [[ ! -x "$HOME/.local/bin/eca" ]]; then
  echo "⬇️  Installing external 'eca' server binary to ~/.local/bin/eca..."
  mkdir -p "$HOME/.local/bin"
  OS_NAME="$(uname -s | tr '[:upper:]' '[:lower:]')"
  ARCH_NAME="$(uname -m)"
  case "$OS_NAME" in
    darwin) OS_TAG="macos" ;;
    linux)  OS_TAG="linux" ;;
    *)      OS_TAG="" ;;
  esac
  case "$ARCH_NAME" in
    x86_64|amd64)  ARCH_TAG="amd64" ;;
    arm64|aarch64) ARCH_TAG="aarch64" ;;
    *)             ARCH_TAG="" ;;
  esac

  if [[ -n "$OS_TAG" && -n "$ARCH_TAG" ]]; then
    ZIP_URL="https://github.com/editor-code-assistant/eca/releases/latest/download/eca-native-${OS_TAG}-${ARCH_TAG}.zip"
    if curl -fsSL "$ZIP_URL" -o /tmp/eca-server.zip && unzip -oq /tmp/eca-server.zip -d "$HOME/.local/bin/"; then
      chmod +x "$HOME/.local/bin/eca"
      rm -f /tmp/eca-server.zip
      echo "✅ Installed eca binary to $HOME/.local/bin/eca"
    else
      echo "⚠️  Could not auto-download eca binary from $ZIP_URL. Download manually from GitHub Releases."
    fi
  fi
else
  echo "✅ External 'eca' server binary is already installed."
fi

echo "✅ Doom Deag installed! Restart Doom Emacs (SPC q r) and press SPC a a to start."
