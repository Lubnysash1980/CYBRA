#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA"

bash github_autonomous_cycle.sh parliament-handler >/dev/null 2>&1 || true
