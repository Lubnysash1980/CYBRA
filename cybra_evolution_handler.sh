#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA" || exit 0
bash cybra_evolution.sh today >/dev/null 2>&1 || true
