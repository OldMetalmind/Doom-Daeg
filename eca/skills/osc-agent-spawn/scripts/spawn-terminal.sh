#!/usr/bin/env bash
set -euo pipefail

AGENT_NAME="${1:?Usage: spawn-terminal.sh <agent-name> <command>}"
shift
CMD="$*"
WRAPPER="$HOME/.config/eca/skills/osc-agent-spawn/scripts/osc7501-wrap.sh"

ESCAPED_CMD=$(printf '%s' "$WRAPPER \"$AGENT_NAME\" \"$CMD\"" | sed 's/\\/\\\\/g; s/"/\\"/g')
ESCAPED_NAME=$(printf '%s' "$AGENT_NAME" | sed 's/\\/\\\\/g; s/"/\\"/g')

emacsclient -e "(doom-deag-spawn-agent \"$ESCAPED_NAME\" \"$ESCAPED_CMD\")"
