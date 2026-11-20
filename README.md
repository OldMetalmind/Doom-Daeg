# Doom Deag (`doom-deag`)

Self-building AI workspace and **OSC 7501** multi-agent orchestration for **Doom Emacs**, combining Herdr's terminal-agent architecture with **ECA (`eca.dev`)**.

## Prerequisites

- An existing **Doom Emacs** installation (`~/.config/doom` or `~/.doom.d`) with `:term vterm` enabled in `init.el`.
- `emacsclient` available in your `$PATH`.

## Installation

```bash
git clone [https://github.com/](https://github.com/)<your-username>/doom-deag.git ~/.local/share/doom-deag
cd ~/.local/share/doom-deag
./install.sh
```

cp vim doom/lisp/doom-deag.el to your 

## Keybindings (SPC a)

Key	Command	Action
SPC a a	eca	Open Doom Deag Orchestrator chat
SPC a t	eca-chat-toggle-window	Toggle ECA chat window
SPC a s	doom-deag-spawn-agent	Spawn a docked *Agent:* vterm buffer
SPC a l	doom-deag-list-agents	Jump to an active OSC 7501 agent
SPC a b	doom-deag-jump-blocked	Focus the first blocked or failed agent
SPC a i	eca-chat-inline-prompt	Inline ECA prompt at point
SPC a c	doom-deag-clear-finished	Clear done/idle badges from modeline

## ECA Slash Commands
/deag <goal> — Plan and dispatch parallel doom-architect and terminal-worker agents.
/build-ui <feature> — Self-build, live-test, and persist a new Doom Emacs UI feature.
/spawn-agent <name> <command> — Launch a docked terminal agent tracked via OSC 7501.
/agent-status — Inspect live OSC 7501 states and auto-diagnose blocked workers.
