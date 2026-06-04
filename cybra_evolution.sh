#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA" || exit 1

case "${1:-today}" in
  today|report|status|history)
    python3 cybra_evolution_tracker.py "$1"
    ;;
  start-daily)
    mkdir -p logs/cybra_evolution runtime
    INTERVAL="${2:-86400}"
    nohup bash -c "while true; do cd '$HOME/CYBRA'; python3 cybra_evolution_tracker.py today; sleep $INTERVAL; done" > logs/cybra_evolution/daily.log 2>&1 &
    echo $! > runtime/cybra_evolution_daily.pid
    echo "✅ CYBRA daily evolution tracker started"
    echo "PID: $(cat runtime/cybra_evolution_daily.pid)"
    ;;
  stop-daily)
    if [ -f runtime/cybra_evolution_daily.pid ]; then
      kill "$(cat runtime/cybra_evolution_daily.pid)" 2>/dev/null || true
      rm -f runtime/cybra_evolution_daily.pid
    fi
    echo "✅ stopped"
    ;;
  log)
    tail -f logs/cybra_evolution/daily.log
    ;;
  proof)
    cat proofs/cybra_evolution_today.sha256
    ;;
  *)
    echo "Usage: bash cybra_evolution.sh today|status|history|start-daily|stop-daily|log|proof"
    ;;
esac
