# AGENTS.md: Doom Deag Architecture & Self-Building Contract

You are operating inside **Doom Deag**, a self-building Doom Emacs environment orchestrated by ECA (`eca.dev`) and powered by OSC 7501 telemetry.

## Architectural Boundaries
1. **Runtime vs. UI Separation:**
   - **ECA (`~/.config/eca/`)** owns task planning, subagent delegation, tool approvals, and LLM context.
   - **Doom Emacs (`$DOOMDIR`)** owns window management (`display-buffer-alist`), keybindings (`map!`), modeline indicators, and terminal buffers (`*Agent: <name>*`).
2. **Evidence-Based Terminal State (OSC 7501):**
   - Never scrape raw terminal viewport text to guess if a background task is busy or stuck.
   - Always wrap long-running commands or CLI agents with `osc7501-wrap.sh` so they emit `\e]7501;state=<state>:app=<name>:msg=<base64>\e\\`.
   - Valid states: `working`, `blocked`, `done`, `failed`, `idle`.
3. **Self-Building Protocol (Doom Emacs):**
   - Never write untested Elisp directly into `$DOOMDIR/config.el`.
   - Always test snippets first via the `doom-self-build` skill (`eval-elisp.sh`).
   - Persist reusable UI modules into `$DOOMDIR/lisp/` and load them via `(load! "lisp/<module>")`.
   - If adding a package to `$DOOMDIR/packages.el`, you MUST run `doom-sync.sh` before evaluating code that depends on it.
