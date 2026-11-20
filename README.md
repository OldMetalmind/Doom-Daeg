<div align="center">

# Doom Deag (`doom-deag`)

**A self-building AI workspace and OSC 7501 multi-agent orchestrator for Doom Emacs.**

Inspired by [Herdr](https://herdr.dev/) · Powered by [ECA](https://eca.dev/) · Built on [OSC 7501](https://mitchellh.com/writing/program-status-osc7501)

[![Doom Emacs](https://img.shields.io/badge/Doom-Emacs-blueviolet?logo=gnuemacs&logoColor=white)](https://github.com/doomemacs/doomemacs)
[![ECA](https://img.shields.io/badge/Runtime-ECA.dev-00ADD8)](https://eca.dev/)
[![License: EUPL 1.2](https://img.shields.io/badge/License-EUPL_1.2-blue.svg)](LICENSE)

</div>

---

## Overview

**Doom Deag** brings [Herdr's](https://herdr.dev/) terminal-agent orchestration and self-building environment model directly into **Doom Emacs**:

- **Self-Building Editor (`doom-architect`):** Ask ECA to build new window layouts, keybindings, or workflow helpers. Subagents live-test Elisp via `emacsclient` before persisting clean modules to `$DOOMDIR/lisp/`.
- **Docked Terminal Swarm (`terminal-worker`):** Long-running builds, test watchers, and external CLI agents (Claude Code, Aider, `cargo`, `pytest`) run inside dedicated `*Agent: <name>*` `vterm` buffers docked to the bottom 30% of your frame.
- **Evidence-Based OSC 7501 Telemetry:** Instead of scraping raw terminal output, wrapped processes emit structured **OSC 7501** status events (`working`, `blocked`, `done`, `failed`, `idle`) straight to `doom-modeline`.
- **Automatic Blocker Escalation:** When a background terminal agent hits `state=blocked` (awaiting confirmation, missing dependency, or exit code `2`), Doom Deag alerts you in the modeline and escalates the buffer tail to ECA for diagnosis.

---

## Architecture

```text
+-------------------------------------------------------------------+
|                        DOOM EMACS (Host UI)                       |
|                                                                   |
|  +-----------------------------+  +----------------------------+  |
|  |  ECA Chat (deag-orchestrator)|  |  doom-modeline Badges      |  |
|  |  /deag  /build-ui           |  |  [coder:⏳] [tests:🛑]     |  |
|  +--------------+--------------+  +-------------+--------------+  |
|                 | JSON-RPC                      ^                 |
|                 v                               | OSC 7501 / IPC  |
|  +-----------------------------+  +-------------+--------------+  |
|  |  ECA Subagents & Skills     |  |  Docked *Agent:* vterm     |  |
|  |  - doom-architect           +->|  osc7501-wrap.sh <cmd>     |  |
|  |  - terminal-worker          |  |  (Bottom 30% split)        |  |
|  +-----------------------------+  +----------------------------+  |
+-------------------------------------------------------------------+
