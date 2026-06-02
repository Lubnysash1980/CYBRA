#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

case "${1:-status}" in
  enforce)
    python3 cybra_ai_block_enforcer.py enforce "${2:-3}"
    ;;
  submit)
    python3 cybra_ai_block_enforcer.py submit "$2"
    ;;
  until-done)
    for i in $(seq 1 "${2:-20}"); do
      echo "=== ENFORCER ROUND $i ==="
      python3 cybra_ai_block_enforcer.py enforce 3
      bash cybra_ai_until_done.sh run 100 || true
      python3 cybra_ai_block_enforcer.py enforce 1

      MEMPOOL="$(redis-cli LLEN cybra:kibra:task_blocks:mempool)"
      QUEUE="$(redis-cli LLEN cybra:parliament:queue)"
      FAILED="$(redis-cli LLEN cybra:parliament:failed)"

      echo "MEMPOOL=$MEMPOOL QUEUE=$QUEUE FAILED=$FAILED"

      [ "$MEMPOOL" = "0" ] && [ "$QUEUE" = "0" ] && [ "$FAILED" = "0" ] && break
      sleep 1
    done
    python3 cybra_ai_block_enforcer.py report
    ;;
  start)
    nohup bash cybra_ai_block_enforcer.sh watch "${2:-9999}" > logs/ai_block_enforcer/watch.log 2>&1 &
    echo $! > runtime/ai_block_enforcer.pid
    echo "✅ AI Block Enforcer started"
    echo "PID: $(cat runtime/ai_block_enforcer.pid)"
    echo "Log: logs/ai_block_enforcer/watch.log"
    ;;
  watch)
    ROUNDS="${2:-9999}"
    termux-wake-lock 2>/dev/null || true
    for i in $(seq 1 "$ROUNDS"); do
      echo "WATCH ROUND $i"
      python3 cybra_ai_block_enforcer.py enforce 3 || true
      sleep 5
    done
    ;;
  stop)
    if [ -f runtime/ai_block_enforcer.pid ]; then
      kill "$(cat runtime/ai_block_enforcer.pid)" 2>/dev/null || true
      rm -f runtime/ai_block_enforcer.pid
    fi
    termux-wake-unlock 2>/dev/null || true
    echo "✅ stopped"
    ;;
  log)
    tail -f logs/ai_block_enforcer/watch.log
    ;;
  status)
    python3 cybra_ai_block_enforcer.py status
    test -f runtime/ai_block_enforcer.pid && echo "PID=$(cat runtime/ai_block_enforcer.pid)" || true
    test -f posts/ai_block_enforcer_report.md && echo "REPORT=exists" || echo "REPORT=missing"
    ;;
  report)
    cat posts/ai_block_enforcer_report.md
    ;;
  proof)
    cat proofs/ai_block_enforcer.sha256
    ;;
  *)
    echo "Usage:"
    echo "  bash cybra_ai_block_enforcer.sh enforce 3"
    echo "  bash cybra_ai_block_enforcer.sh submit '<json_task>'"
    echo "  bash cybra_ai_block_enforcer.sh until-done 20"
    echo "  bash cybra_ai_block_enforcer.sh start"
    echo "  bash cybra_ai_block_enforcer.sh stop"
    echo "  bash cybra_ai_block_enforcer.sh status"
    echo "  bash cybra_ai_block_enforcer.sh log"
    ;;
esac
