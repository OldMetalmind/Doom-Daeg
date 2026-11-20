#!/usr/bin/env bash
set -uo pipefail

APP_NAME="${1:?Usage: osc7501-wrap.sh <app-name> <command>}"
shift
CMD="$*"

emit_osc7501() {
  local state="$1"
  local msg="$2"
  local b64_msg
  b64_msg=$(printf '%s' "$msg" | base64 | tr -d '\n')

  # 1. Emit standard Mitchell Hashimoto OSC 7501 escape sequence to the PTY
  printf '\033]7501;state=%s:app=%s:msg=%s\033\\' "$state" "$APP_NAME" "$b64_msg"

  # 2. Push state directly to Doom Deag via emacsclient (guarantees libvterm compatibility)
  if command -v emacsclient >/dev/null 2>&1; then
    local escaped_app escaped_msg
    escaped_app=$(printf '%s' "$APP_NAME" | tr '\n' ' ' | sed 's/\\/\\\\/g; s/"/\\"/g')
    escaped_msg=$(printf '%s' "$msg" | tr '\n' ' ' | sed 's/\\/\\\\/g; s/"/\\"/g')
    emacsclient -n -e "(doom-deag-update-status \"$escaped_app\" \"$state\" \"$escaped_msg\")" >/dev/null 2>&1 || true
  fi
}

trap 'emit_osc7501 "blocked" "Interrupted or awaiting input"; exit 130' INT TERM

emit_osc7501 "working" "Running: $CMD"
bash -lc "$CMD"
EXIT_CODE=$?

if [[ $EXIT_CODE -eq 0 ]]; then
  emit_osc7501 "done" "Completed: $CMD"
elif [[ $EXIT_CODE -eq 2 ]]; then
  emit_osc7501 "blocked" "Action required (exit 2): $CMD"
else
  emit_osc7501 "failed" "Failed with exit $EXIT_CODE: $CMD"
fi

exit $EXIT_CODE
