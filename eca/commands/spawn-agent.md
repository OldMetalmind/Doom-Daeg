---
description: Spawn a docked *Agent:* vterm terminal in Doom Deag wrapped with OSC 7501 status tracking.
arguments:
  - name: name
    description: Short name for the agent (e.g. tester, builder, claude)
    required: true
  - name: command
    description: Shell command or CLI agent to execute inside the terminal
    required: true
---
Use the `osc-agent-spawn` skill to immediately launch a tracked terminal agent:

- **Agent Name:** {{name}}
- **Command:** {{command}}

Run `~/.config/eca/skills/osc-agent-spawn/scripts/spawn-terminal.sh "{{name}}" "{{command}}"` and confirm to the user that `*Agent: {{name}}*` is docked at the bottom of Emacs with OSC 7501 modeline tracking enabled.
