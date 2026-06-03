#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

case "${1:-status}" in
  status)
    python3 cybra_closed_sha_pool_bridge.py status
    ;;
  dispatch)
    python3 cybra_closed_sha_pool_bridge.py dispatch "${2:-200}"
    ;;
  cycle)
    python3 cybra_closed_sha_pool_bridge.py cycle
    ;;
  submit)
    python3 cybra_closed_sha_pool_bridge.py submit "$2"
    ;;
  until-done)
    for i in $(seq 1 "${2:-30}"); do
      echo "=== CLOSED SHA BRIDGE ROUND $i ==="
      python3 cybra_closed_sha_pool_bridge.py cycle || true

      INBOX="$(redis-cli LLEN cybra:ai:tasks:block_inbox)"
      MEMPOOL="$(redis-cli LLEN cybra:kibra:task_blocks:mempool)"
      QUEUE="$(redis-cli LLEN cybra:parliament:queue)"
      FAILED="$(redis-cli LLEN cybra:parliament:failed)"

      echo "INBOX=$INBOX MEMPOOL=$MEMPOOL QUEUE=$QUEUE FAILED=$FAILED"

      [ "$INBOX" = "0" ] && [ "$MEMPOOL" = "0" ] && [ "$QUEUE" = "0" ] && [ "$FAILED" = "0" ] && break
      sleep 1
    done
    python3 cybra_closed_sha_pool_bridge.py report
    ;;
  start)
    nohup bash cybra_closed_sha_bridge.sh watch "${2:-9999}" > logs/kibra_closed_sha_pool_bridge/watch.log 2>&1 &
    echo $! > runtime/kibra_closed_sha_pool_bridge.pid
    echo "✅ closed SHA bridge started"
    echo "PID: $(cat runtime/kibra_closed_sha_pool_bridge.pid)"
    echo "LOG: logs/kibra_closed_sha_pool_bridge/watch.log"
    ;;
  watch)
    ROUNDS="${2:-9999}"
    termux-wake-lock 2>/dev/null || true
    for i in $(seq 1 "$ROUNDS"); do
      echo "WATCH ROUND $i"
      python3 cybra_closed_sha_pool_bridge.py cycle || true
      sleep 5
    done
    ;;
  stop)
    if [ -f runtime/kibra_closed_sha_pool_bridge.pid ]; then
      kill "$(cat runtime/kibra_closed_sha_pool_bridge.pid)" 2>/dev/null || true
      rm -f runtime/kibra_closed_sha_pool_bridge.pid
    fi
    termux-wake-unlock 2>/dev/null || true
    echo "✅ stopped"
    ;;
  log)
    tail -f logs/kibra_closed_sha_pool_bridge/watch.log
    ;;
  report)
    cat posts/kibra_closed_sha_pool_bridge_report.md
    ;;
  feed)
    cat feeds/kibra_closed_sha_pool_bridge_report.json
    ;;
  proof)
    cat proofs/kibra_closed_sha_pool_bridge.sha256
    ;;
  outbox)
    ls -lah data/kibra_closed_sha_pool_bridge/outbox
    ;;
  sealed)
    ls -lah data/kibra_closed_sha_pool_bridge/sealed
    ;;
  *)
    echo "Usage:"
    echo "  bash cybra_closed_sha_bridge.sh status"
    echo "  bash cybra_closed_sha_bridge.sh dispatch 200"
    echo "  bash cybra_closed_sha_bridge.sh cycle"
    echo "  bash cybra_closed_sha_bridge.sh submit '<json_task>'"
    echo "  bash cybra_closed_sha_bridge.sh until-done 30"
    echo "  bash cybra_closed_sha_bridge.sh start"
    echo "  bash cybra_closed_sha_bridge.sh stop"
    echo "  bash cybra_closed_sha_bridge.sh log"
    ;;
esac
