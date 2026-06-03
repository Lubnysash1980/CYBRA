#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

case "${1:-status}" in
  init|status|health|snapshot|repair|seal|dispatch|mine|report|cycle)
    bin/cybra-autoheal "$@"
    ;;
  start-watch)
    mkdir -p logs/cybra_autoheal_7lvl runtime
    nohup bash cybra_autoheal.sh watch "${2:-30}" > logs/cybra_autoheal_7lvl/watch.log 2>&1 &
    echo $! > runtime/cybra_autoheal_7lvl.pid
    echo "✅ CYBRA AutoHeal 7LVL watcher started"
    echo "PID: $(cat runtime/cybra_autoheal_7lvl.pid)"
    ;;
  watch)
    termux-wake-lock 2>/dev/null || true
    while true; do
      date
      bin/cybra-autoheal cycle || true
      sleep "${2:-30}"
    done
    ;;
  stop-watch)
    if [ -f runtime/cybra_autoheal_7lvl.pid ]; then
      kill "$(cat runtime/cybra_autoheal_7lvl.pid)" 2>/dev/null || true
      rm -f runtime/cybra_autoheal_7lvl.pid
    fi
    termux-wake-unlock 2>/dev/null || true
    echo "✅ CYBRA AutoHeal 7LVL watcher stopped"
    ;;
  log)
    tail -f logs/cybra_autoheal_7lvl/watch.log
    ;;
  proof)
    cat proofs/cybra_autoheal_7lvl.sha256
    ;;
  *)
    echo "Usage:"
    echo "  bash cybra_autoheal.sh status"
    echo "  bash cybra_autoheal.sh cycle"
    echo "  bash cybra_autoheal.sh start-watch 30"
    echo "  bash cybra_autoheal.sh stop-watch"
    echo "  bash cybra_autoheal.sh report"
    ;;
esac
