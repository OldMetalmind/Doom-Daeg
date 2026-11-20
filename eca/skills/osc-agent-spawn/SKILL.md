---
name: osc-agent-spawn
description: Spawn docked *Agent:* terminal buffers in Doom Deag and wrap commands with OSC 7501 status reporting.
---
# OSC 7501 Agent Spawning & Telemetry

Use the scripts in `~/.config/eca/skills/osc-agent-spawn/scripts/` to run background tasks and CLI agents inside Doom Deag:

1. **Spawn a Docked Terminal Agent:**
   Run `~/.config/eca/skills/osc-agent-spawn/scripts/spawn-terminal.sh "<AgentName>" "<command>"`
   This opens `*Agent: <AgentName>*` in the bottom 30% dock and executes `<command>` wrapped in OSC 7501 telemetry.
2. **Wrap Standalone Commands:**
   Run `~/.config/eca/skills/osc-agent-spawn/scripts/osc7501-wrap.sh "<AgentName>" "<command>"`
   This emits `\e]7501;state=working:app=<AgentName>:msg=<base64>\e\\` on start, `state=done` on success, and `state=failed` (or `state=blocked` on exit code 2 / interrupt) on error.
