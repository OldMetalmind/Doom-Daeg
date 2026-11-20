# Keybindings and Commands

Reference for everything Doom Deag exposes. Source of truth: `doom/lisp/doom-deag.el`, `eca/commands/`, `eca/agents/`, and `eca/skills/`.

## Leader keybindings

All bindings live under the `SPC a` prefix, labelled `agents (doom-deag)`.

| Key | Command | Action |
| --- | --- | --- |
| `SPC a a` | `doom-deag-open` | Load and launch the ECA orchestrator |
| `SPC a t` | `eca-chat-toggle-window` | Toggle the ECA chat window |
| `SPC a i` | `eca-chat-inline-prompt` | Open an inline ECA prompt |
| `SPC a s` | `doom-deag-spawn-agent` | Spawn a docked terminal agent; prompts for name and command |
| `SPC a l` | `doom-deag-list-agents` | Select an agent by live OSC 7501 state and jump to its buffer |
| `SPC a b` | `doom-deag-jump-blocked` | Jump to the first agent in `blocked` or `failed` state |
| `SPC a c` | `doom-deag-clear-finished` | Drop `done` and `idle` agents from the tracker and modeline |

`SPC a` replaces Doom's stock "apps" prefix. `eca-chat-toggle-window` and `eca-chat-inline-prompt` come from the `eca-emacs` package, which the installer declares.

## Emacs Lisp commands

Call these with `M-x` or through `emacsclient -e`. Functions marked *interactive* can be invoked directly from Emacs.

| Function | Arguments | Purpose |
| --- | --- | --- |
| `doom-deag-open` | none | Find the `eca` binary, set `eca-custom-command`, load `eca`, start the orchestrator; interactive |
| `doom-deag-spawn-agent` | `agent-name`, optional `command` | Create `*Agent: <name>*` in `vterm-mode`, dock it, mark it `idle`, and optionally send a command after 0.15 s; interactive |
| `doom-deag-list-agents` | none | Completing-read over tracked agents, showing state, name, and message; interactive |
| `doom-deag-jump-blocked` | none | Focus the first `blocked`/`failed` agent buffer; interactive |
| `doom-deag-clear-finished` | none | Remove `done`/`idle` entries; interactive |
| `doom-deag-status-report` | none | Return a newline-delimited string of `app \| state=… \| buffer=… \| msg=…` for all tracked agents |
| `doom-deag-read-agent-tail` | `agent-name`, optional `lines` (default 40) | Return the last N lines of `*Agent: <name>*`, or a "not active" message |
| `doom-deag-update-status` | `app`, `state`, optional `msg` | Set an agent's state, refresh the modeline, and escalate `blocked` states to ECA |
| `doom-deag-osc-7501-handler` | `_cmd`, `text` | Parse `state=…:app=…:msg=<base64>` payloads and delegate to `doom-deag-update-status` |

Examples:

```bash
emacsclient -e '(doom-deag-status-report)'
emacsclient -e '(doom-deag-read-agent-tail "builder" 40)'
emacsclient -e '(doom-deag-update-status "builder" "blocked" "Needs approval")'
```

### Customisation

| Variable | Default | Meaning |
| --- | --- | --- |
| `doom-deag-auto-escalate-blocked` | `t` | Send a blocked agent's message to `eca-chat-send-prompt`, once per distinct message |
| `doom-deag-agent-states` | hash table | Runtime registry: app name → `:state`, `:msg`, `:buffer`, `:updated` |
| `doom-deag--last-escalated` | hash table | Dedup state for blocker escalations; cleared when an agent reports `done` |

## ECA slash commands

| Command | Arguments | Action |
| --- | --- | --- |
| `/deag` | `goal` (required) | Run the 3-phase orchestrator loop: clarify, dispatch `doom-architect` and `terminal-worker` in parallel, report agent status |
| `/build-ui` | `feature` (required) | Delegate to `doom-architect` through `doom-self-build`: live-test Elisp, persist under `$DOOMDIR/lisp/`, load from `config.el`, bind keys under `SPC a` |
| `/spawn-agent` | `name`, `command` (both required) | Run `spawn-terminal.sh` and confirm the docked buffer and OSC 7501 tracking |
| `/agent-status` | none | Query live states with `emacsclient -e '(doom-deag-status-report)'` |

## ECA agents

| Agent | Mode | Role |
| --- | --- | --- |
| `deag-orchestrator` | primary (default) | Plans, delegates UI work and terminal work, reacts to `state=blocked` alerts, inspects buffer tails |
| `doom-architect` | subagent | Writes Doom-flavoured Elisp, tests via `eval-elisp.sh` before persisting modules |
| `terminal-worker` | subagent | Dispatches long-lived processes into `*Agent:*` terminals via `spawn-terminal.sh` |

## Shell scripts

| Script | Usage | Notes |
| --- | --- | --- |
| `./install.sh [--no-sync]` | repo root | Link ECA/Doom config, inject managed fenced blocks, optionally `doom sync`, install `eca` binary |
| `./uninstall.sh` | repo root | Remove links and managed config blocks; run `doom sync` afterwards |
| `~/.config/eca/skills/osc-agent-spawn/scripts/spawn-terminal.sh` | `<agent-name> <command>` | Calls `doom-deag-spawn-agent` in the running Emacs via `emacsclient -e` |
| `~/.config/eca/skills/osc-agent-spawn/scripts/osc7501-wrap.sh` | `<app-name> <command>` | Emits OSC 7501 escape sequences and calls `doom-deag-update-status`; runs the command with `bash -lc` |
| `~/.config/eca/skills/doom-self-build/scripts/eval-elisp.sh` | `'<elisp-expression>'` | Evaluates in the live Emacs server via `emacsclient`, falling back to `emacs --batch` |
| `~/.config/eca/skills/doom-self-build/scripts/doom-sync.sh` | no args | Locates the `doom` CLI and runs `doom sync` through the OSC 7501 wrapper when available |

The four ECA skill scripts hardcode `~/.config/eca`, even though `install.sh` respects `$XDG_CONFIG_HOME`.

## OSC 7501 state vocabulary

| State | Meaning | Modeline badge | Escalation |
| --- | --- | --- | --- |
| `working` | Process started | `app:⏳` (warning face) | none |
| `blocked` | Awaiting input, interrupted, or exit code 2 | `app:🛑` (error face) | message + optional ECA prompt |
| `failed` | Exit code other than 0 or 2 | `app:❌` (error face) | message |
| `done` | Exit code 0 | `app:✅` (success face) | clears escalation dedup |
| `idle` | Terminal ready, no command running | none | none |

Status is delivered two ways: an OSC 7501 escape sequence on the PTY, and a direct `emacsclient -e '(doom-deag-update-status …)'` call for libvterm compatibility.

## Pre-approved tool calls

`eca/config.json` grants approval for:

- the `eca__skill` tool
- `eval-elisp.sh*`, `doom-sync.sh*`, `spawn-terminal.sh*`, `osc7501-wrap.sh*`
- `emacsclient -e *`

The default agent is `deag-orchestrator`, and `~/.config/eca/AGENTS.md` is loaded as a rule.

## Known gap

`eca/skills/doom-self-build/SKILL.md` is referenced by `AGENTS.md` and `doom-architect` but is not present in the repository; only its two scripts ship. The `doom-self-build` scripts remain usable directly.
