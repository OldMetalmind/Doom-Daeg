# Quickstart

Doom Deag turns Doom Emacs into an agent orchestration console. ECA agents plan and delegate work; long-running commands run in docked `*Agent: <name>*` terminals that report their status through OSC 7501 instead of requiring you to read raw terminal output.

This guide takes you from a working Doom Emacs install to a running terminal agent. For the full key and command list, see [Keybindings and Commands](KEYBINDINGS-AND-COMMANDS.md).

## Prerequisites

- Doom Emacs installed, with `vterm` uncommented under `:term` in `init.el`
- `emacsclient` available on `PATH`
- Network access: the installer adds the `eca-emacs` package recipe and downloads the external `eca` server binary if they are not already present

## 1. Install

```bash
git clone <repository-url> ~/.local/share/doom-deag
cd ~/.local/share/doom-deag
./install.sh
```

The installer:

- detects `$DOOMDIR` (or `~/.config/doom`, or `~/.doom.d`) and the `doom` CLI
- symlinks the ECA config, agents, rules, skills, and commands into `~/.config/eca` (or `$XDG_CONFIG_HOME/eca`)
- symlinks `doom/lisp/doom-deag.el` into `$DOOMDIR/lisp/`
- adds `(load! "lisp/doom-deag")` to `config.el` and the `eca` package recipe to `packages.el`, inside managed fenced blocks
- runs `doom sync` if `eca-emacs` is not installed, and installs `~/.local/bin/eca` if the server binary is missing

Pass `--no-sync` to skip `doom sync` if you want to run it yourself later.

## 2. Restart Emacs and open the orchestrator

```text
SPC q r    restart Doom Emacs
SPC a a    open Doom Deag (starts ECA)
```

`SPC a` is the Doom Deag agent prefix. It takes over the prefix that stock Doom uses for "apps".

## 3. Give the orchestrator a goal

In the ECA chat, run:

```text
/deag Fix the failing tests in this project and report what changed
```

The orchestrator clarifies ambiguous constraints, delegates Emacs UI work to `doom-architect`, delegates shell/build work to `terminal-worker`, and watches for blocked agents.

For a single-purpose request you can skip the orchestrator:

```text
/build-ui Add a modeline badge for my current test suite
/spawn-agent tester "npm test -- --watch"
/agent-status
```

## 4. Spawn a terminal agent yourself

From ECA:

```text
/spawn-agent builder "cargo build --watch"
```

Or from Emacs: press `SPC a s`, enter an agent name, then enter the command.

The command runs in `*Agent: builder*` docked at the bottom 30% of the frame. `osc7501-wrap.sh` wraps it and emits:

| State | When | Badge |
| --- | --- | --- |
| `working` | command starts | `builder:⏳` |
| `done` | exit code 0 | `builder:✅` |
| `failed` | any other exit code | `builder:❌` |
| `blocked` | exit code 2, or interrupt | `builder:🛑` |
| `idle` | terminal spawned, nothing running | no badge |

## 5. Monitor and unblock

```text
SPC a l    list tracked agents and their live states
SPC a b    jump to the first blocked or failed agent
SPC a t    toggle the ECA chat window
```

From a shell you can query the same state:

```bash
emacsclient -e '(doom-deag-status-report)'
emacsclient -e '(doom-deag-read-agent-tail "builder" 40)'
```

When a wrapper reports `state=blocked`, Doom Deag shows an error badge and asks ECA to inspect the buffer tail. `doom-architect` gets the same treatment for Elisp work: snippets are evaluated through `eval-elisp.sh` before anything is written into `$DOOMDIR`.

## 6. Uninstall

```bash
cd ~/.local/share/doom-deag
./uninstall.sh
doom sync
```

This removes the symlinks and the managed fenced blocks from `config.el` and `packages.el`. It does not remove the downloaded `eca` binary or the `eca-emacs` package; `doom sync` prunes the latter.

## Troubleshooting

- **Agent terminals do not render:** enable `vterm` under `:term` in `init.el`, then restart Emacs.
- **`ECA server binary not found`:** check that `~/.local/bin/eca` exists and is on `PATH`, or reinstall.
- **`SPC a` no longer opens the apps menu:** expected; Doom Deag uses that prefix. Run `SPC h SPC` and search for `doom-deag` to find every command.
- **`/build-ui` cannot load its skill:** the repository currently ships `doom-self-build/scripts/` but no `eca/skills/doom-self-build/SKILL.md`. The scripts still work directly; see [Keybindings and Commands](KEYBINDINGS-AND-COMMANDS.md).
- **`XDG_CONFIG_HOME` is set:** `install.sh` honours it, but the shell scripts hardcode `~/.config/eca`. Keep the ECA config there or adjust the paths in those scripts.
