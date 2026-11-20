---
description: Self-build a new Doom Emacs UI component, layout, keybinding, or modeline widget.
arguments:
  - name: feature
    description: Describe the Emacs UI or workflow feature to build
    required: true
---
Delegate to the `doom-architect` subagent using the `doom-self-build` skill to design, live-test via `emacsclient`, and persist the following Doom Emacs feature:

**Requested Feature:** {{feature}}

Requirements:
- Test the Elisp in the live Emacs instance first via `eval-elisp.sh`.
- Persist clean, modular Elisp under the user's Doom `lisp/` directory (`~/.config/doom/lisp/` or `~/.doom.d/lisp/`) and load it from `config.el`.
- Bind convenient leader keys under `SPC a` (`doom-deag`) and report the exact keybindings to the user.
