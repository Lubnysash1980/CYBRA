#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

case "${1:-status}" in
  status|scan|report|submit-ai|fix-local|cycle)
    bin/cybra-security-analytics "$@"
    ;;
  start-watch)
    mkdir -p logs/cybra_security_analytics runtime
    nohup bash cybra_security_analytics.sh watch "${2:-60}" > logs/cybra_security_analytics/watch.log 2>&1 &
    echo $! > runtime/cybra_security_analytics.pid
    echo "✅ CYBRA Security Analytics watcher started"
    echo "PID: $(cat runtime/cybra_security_analytics.pid)"
    ;;
  watch)
    termux-wake-lock 2>/dev/null || true
    while true; do
      date
      bin/cybra-security-analytics cycle || true
      sleep "${2:-60}"
    done
    ;;
  stop-watch)
    if [ -f runtime/cybra_security_analytics.pid ]; then
      kill "$(cat runtime/cybra_security_analytics.pid)" 2>/dev/null || true
      rm -f runtime/cybra_security_analytics.pid
    fi
    termux-wake-unlock 2>/dev/null || true
    echo "✅ CYBRA Security Analytics watcher stopped"
    ;;
  log)
    tail -f logs/cybra_security_analytics/watch.log
    ;;
  proof)
    cat proofs/cybra_security_analytics.sha256
    ;;
  *)
    echo "Usage:"
    echo "  bash cybra_security_analytics.sh status"
    echo "  bash cybra_security_analytics.sh scan"
    echo "  bash cybra_security_analytics.sh report"
    echo "  bash cybra_security_analytics.sh submit-ai"
    echo "  bash cybra_security_analytics.sh fix-local"
    echo "  bash cybra_security_analytics.sh cycle"
    echo "  bash cybra_security_analytics.sh start-watch 60"
    ;;
esac
