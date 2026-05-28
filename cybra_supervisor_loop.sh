#!/data/data/com.termux/files/usr/bin/bash
set -e

cd "$HOME/CYBRA"

while true; do
  bash cybra_self_healing_supervisor.sh || true
  sleep 60
done
