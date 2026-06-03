#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

case "${1:-status}" in
  init|status|test|simulate|fix|solve|queue|mine|report|cycle)
    bin/cybra-conformation8 "$@"
    ;;
  start-watch)
    mkdir -p logs/cybra_conformation8 runtime
    nohup bash cybra_conformation8.sh watch "${2:-120}" > logs/cybra_conformation8/watch.log 2>&1 &
    echo $! > runtime/cybra_conformation8.pid
    echo "✅ CYBRA Conformation8 watcher started"
    echo "PID: $(cat runtime/cybra_conformation8.pid)"
    ;;
  watch)
    termux-wake-lock 2>/dev/null || true
    while true; do
      date
      bin/cybra-conformation8 cycle || true
      sleep "${2:-120}"
    done
    ;;
  stop-watch)
    if [ -f runtime/cybra_conformation8.pid ]; then
      kill "$(cat runtime/cybra_conformation8.pid)" 2>/dev/null || true
      rm -f runtime/cybra_conformation8.pid
    fi
    termux-wake-unlock 2>/dev/null || true
    echo "✅ CYBRA Conformation8 watcher stopped"
    ;;
  log)
    tail -f logs/cybra_conformation8/watch.log
    ;;
  proof)
    cat proofs/cybra_conformation8.sha256
    ;;
  *)
    echo "Usage:"
    echo "  bash cybra_conformation8.sh status"
    echo "  bash cybra_conformation8.sh cycle"
    echo "  bash cybra_conformation8.sh start-watch 120"
    echo "  bash cybra_conformation8.sh stop-watch"
    ;;
esac
