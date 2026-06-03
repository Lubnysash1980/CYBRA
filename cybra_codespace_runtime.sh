#!/usr/bin/env bash
set +e

if [ -n "$CYBRA_WORKDIR" ]; then
  cd "$CYBRA_WORKDIR" || exit 1
else
  cd "$HOME/CYBRA" || exit 1
fi

case "${1:-status}" in
  status)
    python3 cybra_codespace_runtime.py status
    ;;
  cycle)
    python3 cybra_codespace_runtime.py cycle "${2:-manual}"
    ;;
  dashboard)
    python3 cybra_codespace_runtime.py dashboard
    ;;
  start-watch)
    mkdir -p logs/codespace_runtime runtime
    nohup bash cybra_codespace_runtime.sh watch "${2:-120}" > logs/codespace_runtime/watch.log 2>&1 &
    echo $! > runtime/codespace_runtime_watchdog.pid
    echo "✅ Codespace Runtime Watchdog started"
    echo "PID: $(cat runtime/codespace_runtime_watchdog.pid)"
    ;;
  watch)
    while true; do
      date
      python3 cybra_codespace_runtime.py cycle "watchdog" || true
      sleep "${2:-120}"
    done
    ;;
  stop-watch)
    if [ -f runtime/codespace_runtime_watchdog.pid ]; then
      kill "$(cat runtime/codespace_runtime_watchdog.pid)" 2>/dev/null || true
      rm -f runtime/codespace_runtime_watchdog.pid
    fi
    echo "✅ Codespace Runtime Watchdog stopped"
    ;;
  log)
    tail -f logs/codespace_runtime/watch.log
    ;;
  proof)
    cat proofs/cybra_codespace_runtime.sha256
    ;;
  *)
    echo "Usage:"
    echo "  bash cybra_codespace_runtime.sh status"
    echo "  bash cybra_codespace_runtime.sh cycle"
    echo "  bash cybra_codespace_runtime.sh dashboard"
    echo "  bash cybra_codespace_runtime.sh start-watch 120"
    echo "  bash cybra_codespace_runtime.sh stop-watch"
    ;;
esac
