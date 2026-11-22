---
name: doom-self-build
description: Safely test, persist, and load Doom Emacs Lisp UI changes in Doom Deag.
---
# Doom Emacs Self-Build Lifecycle

Use this skill for every Doom Emacs UI change requested through `/build-ui` or `doom-architect`: window layouts, keybindings, modeline segments, commands, and editor automation. It implements the self-building contract in `~/.config/eca/AGENTS.md` and the conventions in `~/.config/eca/rules/doom-elisp-safety.md`.

## Tools

`install.sh` copies this skill and its scripts to `~/.config/eca/skills/doom-self-build/` (or `$XDG_CONFIG_HOME/eca/skills/doom-self-build/`). Both scripts are pre-approved in `config.json`.

- `scripts/eval-elisp.sh '<elisp-expression>'` — evaluates a single expression in the live Emacs via `emacsclient -e`; falls back to `emacs --batch --eval "(progn <expr>)"` when no server is running.
- `scripts/doom-sync.sh` — locates the `doom` CLI and runs `doom sync`, wrapped in OSC 7501 telemetry when available.

Resolve the Doom config dir from `$DOOMDIR`, else `~/.config/doom`, else `~/.doom.d`.

## Lifecycle (strict order)

1. **Inspect first.** Read the relevant files under the Doom config dir. Check existing `SPC a` bindings (`doom-deag.el` owns `a t i s l b c`) and any module you may be replacing.
2. **Write Doom-idiomatic Elisp.** Use `after!`, `use-package!`, `map!`, `setq!`, `add-hook!`. Never raw `global-set-key`, never blocking `shell-command-to-string` in hooks or modeline segments, and use `make-process` or `run-at-time` for asynchronous work. Prefix custom functions and variables with `doom-deag-`. Agent terminal buffers must match `^\*Agent:.*\*`.
3. **Live-test before writing to `$DOOMDIR`.** Evaluate a candidate expression in the running Emacs:
   `~/.config/eca/skills/doom-self-build/scripts/eval-elisp.sh '(progn ...)'`
   For multi-form modules, stage the code in a temporary file outside `$DOOMDIR` and evaluate `(progn (load "/tmp/<module>.el") ...)`. Confirm the command, binding, or modeline segment actually behaves. A non-zero exit means the test failed — fix and re-evaluate before continuing.
4. **Persist a module.** Write the verified code to `$DOOMDIR/lisp/<module>.el`. Never paste untested Elisp into `config.el`.
5. **Load it.** Add `(load! "lisp/<module>")` to `$DOOMDIR/config.el`, labelled `;; doom-self-build: <module>`. Place it **outside** the installer's `;; >>> doom-deag >>>` fenced block: `install.sh` and `uninstall.sh` rewrite that block.
6. **If you added a package** to `$DOOMDIR/packages.el` (also outside the installer's fenced block), run `scripts/doom-sync.sh` **before** evaluating anything that depends on it. Wait for `state=done` before continuing.
7. **Verify.** Reload in the live Emacs with `emacsclient -e '(load "<module path>")'`, or ask the user to restart with `SPC q r`. Check that new commands are `commandp`, keybindings resolve, the modeline renders, and existing `SPC a` bindings still work. If you touched telemetry UI, confirm with `emacsclient -e '(doom-deag-status-report)'`.
8. **Report.** Summarize the module path, the exact new commands and keybindings, and whether a sync or restart is required.

## Pitfalls

- `eval-elisp.sh` takes one expression: shell-quote with single quotes outside and double quotes inside for Elisp strings.
- Do not edit files under `$DOOMDIR` that are symlinks into this repository — edit the repository copy instead and re-run `install.sh`.
- The ECA skill scripts hardcode `~/.config/eca`. When `$XDG_CONFIG_HOME` is set elsewhere, call scripts by their actual installed paths and note the mismatch.
- Keep new `SPC a` keys distinct from the seven existing ones; reuse of a bound key silently shadows the Doom Deag command.
- Do not put your own code inside the installer's fenced blocks; it will be stripped on reinstall or uninstall.

## Verification

- `eval-elisp.sh '(progn ...)'` exits 0 and produces the expected result in the live Emacs.
- `$DOOMDIR/lisp/<module>.el` exists, `config.el` contains its `load!` line, and `emacsclient -e '(commandp <new-command>)'` returns non-nil.
- `doom sync` completed before any package-dependent evaluation.
- The user received the exact keybindings and a reload/restart note.
