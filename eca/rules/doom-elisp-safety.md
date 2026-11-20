---
paths:
  - "**/*.el"
---
# Doom Deag Emacs Lisp Conventions
- Always use Doom macros: `after!`, `map!`, `use-package!`, `setq!`, `add-hook!`.
- Prefix all custom functions and variables with `doom-deag-` to prevent namespace collisions.
- Never block the main Emacs UI thread: use `make-process` or `run-at-time` instead of `shell-command-to-string` inside hooks or modeline segments.
- All agent terminal buffers MUST match `^\*Agent:.*\*` so `display-buffer-alist` docks them cleanly at the bottom of the frame.
