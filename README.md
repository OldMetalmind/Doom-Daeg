<div align="center">

# Doom Deag (`doom-deag`)

**An agent-development workbench built into Doom Emacs: ECA plans and delegates, OSC 7501 reports process state, and your editor is the live control surface.**

Inspired by [Herdr](https://herdr.dev/) · Powered by [ECA](https://eca.dev/) · Telemetry via [OSC 7501](https://mitchellh.com/writing/program-status-osc7501)

[![Doom Emacs](https://img.shields.io/badge/Doom-Emacs-blueviolet?logo=gnuemacs&logoColor=white)](https://github.com/doomemacs/doomemacs)
[![ECA](https://img.shields.io/badge/Runtime-ECA.dev-00ADD8)](https://eca.dev/)
[![OSC 7501](https://img.shields.io/badge/Telemetry-OSC_7501-orange)](https://mitchellh.com/writing/program-status-osc7501)
[![License: EUPL 1.2](https://img.shields.io/badge/License-EUPL_1.2-blue.svg)](LICENSE)

</div>

---

## Why this exists

If you build AI-native tools, you end up wiring the same three pieces together: an agent runtime that plans and delegates, a process layer that runs long-lived commands, and a UI where a human can see and intervene. Doom Deag is a working reference implementation of that wiring, with one unusual choice: **the UI is Doom Emacs**.

That gives agent developers:

- **A real control surface, not a log tail.** Agents run in docked `*Agent: <name>*` vterm buffers; their state appears as modeline badges.
- **Evidence-based status.** Processes emit structured OSC 7501 events (`working`, `blocked`, `done`, `failed`, `idle`) instead of making the agent guess from terminal text.
- **Blocker escalation.** A `blocked` alert is pushed into the ECA chat, which can read the buffer tail and ask you a precise question.
- **A self-building editor.** New UI commands are live-tested in the running Emacs before being persisted as modules — the same "test, then commit" discipline you would apply to application code.
- **Small, legible extension points.** Skills, subagents, slash commands, and editor modules are each a single file with a clear contract.

## Architecture

**Component view — who owns what and how they talk:**

```mermaid
flowchart TB
    User([👤 Developer / Agent])

    subgraph EMACS["Doom Emacs — host UI ($DOOMDIR)"]
        direction TB
        UI["🖥️ doom-deag.el<br/>state registry · OSC handler · modeline · SPC a map"]
        Server["🔌 Emacs server<br/>emacsclient RPC endpoint"]
        Chat["💬 eca-emacs chat<br/>slash commands · ECA client"]
        VT["📺 Agent buffer vterm<br/>bottom 30% · dedicated"]
    end

    subgraph ECARUNTIME["ECA runtime (~/.config/eca)"]
        direction TB
        Config["⚙️ config.json<br/>default agent · approvals · rules"]
        Orch["🎯 deag-orchestrator"]
        Architect["🧱 doom-architect<br/>Elisp / UI"]
        Worker["🛠️ terminal-worker<br/>shell / CLI"]
        Skills["📦 skills/<br/>osc-agent-spawn · doom-self-build"]
        Commands["⌘ /deag · /build-ui<br/>/spawn-agent · /agent-status"]
    end

    subgraph PROCESS["Process layer"]
        Wrap["🔄 osc7501-wrap.sh<br/>working → done / failed / blocked"]
        CLI["⚙️ cargo · pytest · claude · aider<br/>standalone apps"]
    end

    User -->|"SPC a a · /deag · /spawn-agent"| Chat
    Chat <-->|"JSON-RPC"| Orch
    Config --> Orch
    Commands --> Chat
    Orch --> Architect
    Orch --> Worker
    Architect -->|"eval-elisp.sh · emacsclient -e"| Server
    Worker -->|"spawn-terminal.sh"| Server
    Worker --> Wrap
    Skills -.->|"used by"| Architect
    Skills -.->|"used by"| Worker
    Server --> UI
    Server -->|"create / dock"| VT
    Wrap -->|"bash -lc"| CLI
    Wrap -->|"OSC 7501 + emacsclient"| UI
    UI -->|"blocked → alert"| Chat
    Chat -->|"read-agent-tail"| VT

    classDef ui fill:#90EE90,stroke:#333,stroke-width:2px,color:#0B3D0B
    classDef runtime fill:#87CEEB,stroke:#333,stroke-width:2px,color:#0B2E4B
    classDef process fill:#FFE66D,stroke:#F08C00,stroke-width:2px,color:#3A2B00
    classDef user fill:#FFB6C1,stroke:#DC143C,stroke-width:2px,color:#3A0008

    class User user
    class UI,Server,Chat,VT ui
    class Config,Orch,Architect,Worker,Skills,Commands runtime
    class Wrap,CLI process
```

**Sequence view — one command from spawn to blocker escalation:**

```mermaid
sequenceDiagram
    actor Dev as 👤 Developer
    participant Chat as 💬 ECA chat
    participant Orch as 🎯 Orchestrator
    participant Worker as 🛠️ terminal-worker
    participant Wrap as 🔄 osc7501-wrap
    participant Term as 📺 Agent: builder
    participant Emacs as 🖥️ doom-deag.el

    Dev->>Chat: /spawn-agent builder "cargo test --watch"
    Chat->>Orch: goal + context
    Orch->>Worker: delegate shell work
    Worker->>Emacs: spawn-terminal.sh → emacsclient -e
    Emacs->>Term: create vterm, dock bottom 30%
    Worker->>Wrap: wrapped command
    Wrap->>Emacs: state=working (OSC + emacsclient)
    Emacs->>Emacs: registry + modeline badge ⏳
    Wrap->>Term: bash -lc command
    Term-->>Wrap: exit code / interrupt

    alt exit 0
        Wrap->>Emacs: state=done
        Emacs->>Emacs: badge ✅, clear escalation dedup
    else exit 2 or interrupt
        Wrap->>Emacs: state=blocked
        Emacs->>Chat: eca-chat-send-prompt alert
        Chat->>Orch: diagnose blocker
        Orch->>Emacs: doom-deag-read-agent-tail "builder" 40
        Emacs-->>Orch: last 40 lines
        Orch->>Dev: crisp question / fix
    else other non-zero
        Wrap->>Emacs: state=failed
        Emacs->>Emacs: badge ❌
    end

    Note over Wrap,Emacs: No viewport scraping — status comes from OSC 7501 events
```

The boundary is deliberate: **ECA owns planning, delegation, tool approvals, and LLM context**; **Doom Emacs owns window rules, keybindings, modeline segments, and terminal buffers**. See [`AGENTS.md`](AGENTS.md) for the full contract.

## Install

Requires an existing Doom Emacs install with `vterm` enabled under `:term`, `emacsclient` on `PATH`, and network access for the `eca-emacs` recipe and the `eca` server binary.

```bash
git clone https://github.com/OldMetalmind/Doom-Daeg.git ~/.local/share/doom-deag
cd ~/.local/share/doom-deag
./install.sh          # add --no-sync to run `doom sync` yourself
```

The installer symlinks ECA config/agents/rules/commands and the `doom-deag.el` module, **copies** `eca/skills/` as ordinary files into `~/.config/eca/skills/`, injects fenced loader blocks into `config.el` and `packages.el`, and installs `~/.local/bin/eca` if missing. Restart Emacs with `SPC q r`, then press `SPC a a`.

Alternatively, `./bootstrap-doom-deag.sh [target-dir]` clones the repo into a fresh directory for you. Use `DOOM_DEAG_REPO` to bootstrap from a fork.

## Your first agents

In the ECA chat:

```text
/deag Fix the failing tests in this project and report what changed
/spawn-agent builder "cargo build --watch"
/build-ui Add a modeline badge for my current test suite
/agent-status
```

From Emacs: `SPC a s` spawns a named terminal, `SPC a l` lists agents with live states, `SPC a b` jumps to the first blocked one, and `SPC a t` toggles the chat. Full key reference: [`KEYBINDINGS-AND-COMMANDS.md`](KEYBINDINGS-AND-COMMANDS.md).

| State | Meaning | Badge |
| --- | --- | --- |
| `working` | command started | `app:⏳` |
| `blocked` | awaiting input, interrupt, or exit code 2 | `app:🛑` (+ ECA escalation) |
| `failed` | any other non-zero exit | `app:❌` |
| `done` | exit code 0 | `app:✅` |
| `idle` | terminal open, nothing running | none |

## Extending it (for agent developers)

### Extension points

| What you're adding | Where | Contract |
| --- | --- | --- |
| Skill | `eca/skills/<name>/SKILL.md` + `scripts/` | Frontmatter `name`/`description`; ECA discovers it by directory name. `install.sh` copies the tree. |
| Subagent | `eca/agents/<name>.md` | Frontmatter `name`, `mode: subagent`, `spawnableBy`, `description`. |
| Slash command | `eca/commands/<name>.md` | Frontmatter `description`, optional `arguments`; body is the prompt template. |
| Editor module | `doom/lisp/<module>.el` | Live-test with `eval-elisp.sh`, persist under `$DOOMDIR/lisp/`, load with `(load! "lisp/<module>")`. |
| Terminal command | `osc7501-wrap.sh <app> <cmd>` | Emits state transitions; run it inside a docked `*Agent:*` terminal. |

A minimal skill skeleton:

```markdown
---
name: my-agent-skill
description: One line telling ECA exactly when to use this skill.
---
# My Agent Skill

1. Do the first step.
2. Emit status with osc7501-wrap.sh instead of scraping terminal output.
3. Report a concise result.
```

### The telemetry contract

Both emitters feed the same registry:

```text
ESC ] 7501 ; state=working:app=builder:msg=<base64> ESC \
```

`msg` is base64-encoded UTF-8; the five valid states are listed above. Any language can emit it: print the escape sequence on a PTY, or call the direct bridge (the reliable path in vterm and on Emacs builds without `osc.el`):

```bash
emacsclient -n -e '(doom-deag-update-status "builder" "blocked" "Needs approval")'
```

Do not scrape the viewport to infer state. That rule is in `AGENTS.md` for a reason: terminal text is ambiguous, OSC events are not.

### Emacs RPC surface

Your agents and skills can call these through `emacsclient -e`:

| Function | Purpose |
| --- | --- |
| `doom-deag-spawn-agent` | Create and dock a `*Agent: <name>*` vterm, optionally sending a command. |
| `doom-deag-update-status` | Set state/message, refresh the modeline, escalate `blocked` to ECA. |
| `doom-deag-status-report` | Newline-delimited state of every tracked agent. |
| `doom-deag-read-agent-tail` | Last N lines of an agent buffer, for diagnosis without viewport scraping. |
| `doom-deag-list-agents`, `doom-deag-jump-blocked`, `doom-deag-clear-finished` | Interactive navigation/maintenance. |

```bash
emacsclient -e '(doom-deag-status-report)'
emacsclient -e '(doom-deag-read-agent-tail "builder" 40)'
```

`emacsclient -e` evaluates arbitrary Elisp, so treat it as a privileged API: `eca/config.json` pre-approves a small set of skill scripts and `emacsclient -e *`, and new capabilities should be exposed as narrow functions rather than more raw eval.

### Self-building safety loop

`doom-architect` follows a strict lifecycle: inspect existing bindings → write Doom-flavoured Elisp (`use-package!`, `after!`, `map!`, `setq!`) → **live-test via `eval-elisp.sh` before writing to disk** → persist to `$DOOMDIR/lisp/` → load from `config.el` → run `doom-sync.sh` first if a package was added. Installer-managed fenced blocks (`;; >>> doom-deag >>>`) are rewritten on install/uninstall, so your own code belongs outside them.

## Repository layout

| Path | Contents |
| --- | --- |
| `doom/lisp/doom-deag.el` | State registry, OSC handler, modeline segment, vterm docking, `SPC a` map, ECA launcher. |
| `eca/agents/` | `deag-orchestrator`, `doom-architect`, `terminal-worker`. |
| `eca/commands/` | `/deag`, `/build-ui`, `/spawn-agent`, `/agent-status`. |
| `eca/skills/` | `osc-agent-spawn` and `doom-self-build` (copied into ECA config by the installer). |
| `eca/config.json` | Default agent, rules, pre-approved tool calls. |
| `install.sh` / `uninstall.sh` | Link/copy config, manage fenced blocks, install the `eca` binary. |
| `bootstrap-doom-deag.sh` | Clone the repo into a target directory. |
| `QUICKSTART.md`, `KEYBINDINGS-AND-COMMANDS.md`, `gaps.md` | Setup guide, full reference, and the current gap list. |

## Docs

- [Quickstart](QUICKSTART.md) — install, first agent, monitoring, uninstall.
- [Keybindings and commands](KEYBINDINGS-AND-COMMANDS.md) — every command, API function, script, and state.
- [Architecture contract](AGENTS.md) — the runtime/UI boundary and self-building protocol.
- [Known gaps](gaps.md) — open issues, including a weak OSC path on Emacs builds without `osc.el` and the `$XDG_CONFIG_HOME` path mismatch.

## License

[EUPL 1.2](LICENSE)
