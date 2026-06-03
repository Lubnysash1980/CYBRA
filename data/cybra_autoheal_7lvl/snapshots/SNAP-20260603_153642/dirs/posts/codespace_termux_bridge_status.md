# CYBRA Codespaces-Termux Bridge

Status: installed

Light mode:
enabled

Reason:
No git add . — avoids loading ai_network, logs, node_modules, recovery.

Commands:
- bridge/termux/push_to_codespaces.sh
- bridge/termux/pull_from_codespaces.sh
- bridge/codespaces/pull_from_termux.sh
- bridge/codespaces/push_to_termux.sh

Startup:
bash remote_queue/codespaces_startup.task
