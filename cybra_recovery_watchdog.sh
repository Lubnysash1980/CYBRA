#!/data/data/com.termux/files/usr/bin/bash
set -e

cd "$HOME/CYBRA"

mkdir -p logs/recovery runtime

INTERVAL="${1:-1800}"

while true; do
  if ! pgrep -f "cybra_autoheal_recovery_pack.sh auto" >/dev/null; then
    echo "$(date -Iseconds) restarting recovery auto pack" >> logs/recovery/watchdog.log
    nohup bash "$HOME/CYBRA/cybra_autoheal_recovery_pack.sh" auto "$INTERVAL" > logs/recovery/auto_loop.log 2>&1 &
    echo $! > runtime/recovery_auto.pid
  fi

  sleep 60
done
