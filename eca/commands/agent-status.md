---
description: Inspect live OSC 7501 states across all running Doom Deag terminal agents and unblock stalled workers.
---
Query the live Emacs session for all tracked OSC 7501 agent states by running:

```bash
emacsclient -e '(doom-deag-status-report)'
