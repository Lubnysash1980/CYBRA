#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

case "${1:-status}" in
  status)
    python3 cybra_finance_redis_committee.py status
    ;;
  ensure|start)
    python3 cybra_finance_redis_committee.py ensure
    ;;
  report)
    python3 cybra_finance_redis_committee.py report
    cat posts/finance_redis_committee_report.md
    ;;
  submit-ai)
    python3 cybra_finance_redis_committee.py submit-ai
    bash cybra_ai_block_enforcer.sh enforce 3 >/dev/null 2>&1 || true
    ;;
  task)
    python3 cybra_finance_redis_committee.py ensure
    if command -v cybra >/dev/null 2>&1; then
      cybra parliament '{"topic":"Finance Department Redis Committee","type":"finance_redis_committee_task","priority":"critical","payload":{"redis_watchdog":true,"auto_start_redis":true,"protect_finance_queues":true,"protect_ai_task_blocks":true,"manual_OWNER_approval_required":false}}' || true
    else
      redis-cli LPUSH cybra:parliament:queue '{"topic":"Finance Department Redis Committee","type":"finance_redis_committee_task","priority":"critical","payload":{"redis_watchdog":true,"auto_start_redis":true,"protect_finance_queues":true,"protect_ai_task_blocks":true,"manual_OWNER_approval_required":false}}' >/dev/null
    fi
    ;;
  cycle)
    python3 cybra_finance_redis_committee.py ensure
    python3 cybra_finance_redis_committee.py submit-ai
    bash cybra_closed_sha_bridge.sh cycle || true
    python3 parliament_executor_v6.py || true
    python3 cybra_finance_redis_committee.py report
    ;;
  watch)
    termux-wake-lock 2>/dev/null || true
    while true; do
      date
      python3 cybra_finance_redis_committee.py ensure || true
      sleep "${2:-10}"
    done
    ;;
  start-watch)
    mkdir -p logs/finance_redis_committee runtime
    nohup bash cybra_redis_committee.sh watch "${2:-10}" > logs/finance_redis_committee/watch.log 2>&1 &
    echo $! > runtime/finance_redis_committee.pid
    echo "✅ Redis Committee watchdog started"
    echo "PID: $(cat runtime/finance_redis_committee.pid)"
    echo "LOG: logs/finance_redis_committee/watch.log"
    ;;
  stop-watch)
    if [ -f runtime/finance_redis_committee.pid ]; then
      kill "$(cat runtime/finance_redis_committee.pid)" 2>/dev/null || true
      rm -f runtime/finance_redis_committee.pid
    fi
    termux-wake-unlock 2>/dev/null || true
    echo "✅ Redis Committee watchdog stopped"
    ;;
  log)
    tail -f logs/finance_redis_committee/watch.log
    ;;
  proof)
    cat proofs/finance_redis_committee.sha256
    ;;
  *)
    echo "Usage:"
    echo "  bash cybra_redis_committee.sh status"
    echo "  bash cybra_redis_committee.sh ensure"
    echo "  bash cybra_redis_committee.sh report"
    echo "  bash cybra_redis_committee.sh submit-ai"
    echo "  bash cybra_redis_committee.sh task"
    echo "  bash cybra_redis_committee.sh cycle"
    echo "  bash cybra_redis_committee.sh start-watch 10"
    echo "  bash cybra_redis_committee.sh stop-watch"
    echo "  bash cybra_redis_committee.sh log"
    ;;
esac
