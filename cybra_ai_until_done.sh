#!/data/data/com.termux/files/usr/bin/bash
set -e

cd "$HOME/CYBRA"

mkdir -p logs/ai_until_done runtime posts feeds proofs

case "${1:-status}" in
  directive)
    python3 cybra_ai_until_done.py directive
    ;;

  run)
    MAX_ROUNDS="${2:-500}"
    SLEEP_SECONDS="${SLEEP_SECONDS:-2}"

    termux-wake-lock 2>/dev/null || true
    redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes || true
    sleep 1

    echo "=== OWNER DIRECTIVE ==="
    python3 cybra_ai_until_done.py directive

    echo
    echo "=== SAFE PREPARE REPORTS / AI TASKS ==="
    bash cybra_native_kibra.sh build >/dev/null 2>&1 || true
    bash cybra_finance_gap.sh submit-ai >/dev/null 2>&1 || true
    bash cybra_finance_profit_audit.sh submit-ai >/dev/null 2>&1 || true
    bash cybra_evolution_deploy.sh report >/dev/null 2>&1 || true

    echo
    echo "=== COLLECT AI TASKS TO PARLIAMENT QUEUE ==="
    python3 cybra_ai_until_done.py collect

    echo
    echo "=== WORK UNTIL DONE ==="

    for i in $(seq 1 "$MAX_ROUNDS"); do
      echo
      echo "--- ROUND $i / $MAX_ROUNDS ---"

      python3 parliament_executor_v6.py || true
      python3 cybra_ai_until_done.py collect || true

      AI_TOTAL="$(python3 cybra_ai_until_done.py ai-total || echo 0)"
      QUEUE="$(redis-cli LLEN cybra:parliament:queue)"
      FAILED="$(redis-cli LLEN cybra:parliament:failed)"
      RESULTS="$(redis-cli LLEN cybra:parliament:results)"

      echo "AI_TOTAL=$AI_TOTAL"
      echo "PARLIAMENT_QUEUE=$QUEUE"
      echo "PARLIAMENT_FAILED=$FAILED"
      echo "PARLIAMENT_RESULTS=$RESULTS"

      if [ "$FAILED" != "0" ]; then
        echo "=== FAILED DETECTED: trying safe repair ==="
        bash cybra_existing_tasks.sh repair >/dev/null 2>&1 || true
        python3 parliament_executor_v6.py || true
      fi

      AI_TOTAL="$(python3 cybra_ai_until_done.py ai-total || echo 0)"
      QUEUE="$(redis-cli LLEN cybra:parliament:queue)"
      FAILED="$(redis-cli LLEN cybra:parliament:failed)"

      if [ "$AI_TOTAL" = "0" ] && [ "$QUEUE" = "0" ] && [ "$FAILED" = "0" ]; then
        echo "✅ DONE: AI tasks completed, queue empty, failed zero"
        break
      fi

      sleep "$SLEEP_SECONDS"
    done

    echo
    echo "=== FINAL SAFE REPORTS ==="
    bash cybra_kibra_chain.sh verify >/dev/null 2>&1 || true
    bash cybra_native_kibra.sh status >/dev/null 2>&1 || true
    bash cybra_finance_gap.sh report >/dev/null 2>&1 || true
    bash cybra_finance_profit_audit.sh report >/dev/null 2>&1 || true
    bash cybra_evolution_deploy.sh report >/dev/null 2>&1 || true

    echo
    echo "=== FINALIZE ==="
    python3 cybra_ai_until_done.py finalize

    echo
    echo "=== PROOF CHECK ==="
    sha256sum -c proofs/ai_until_done_report.sha256 || true

    termux-wake-unlock 2>/dev/null || true
    ;;

  start)
    MAX_ROUNDS="${2:-500}"
    nohup bash cybra_ai_until_done.sh run "$MAX_ROUNDS" > logs/ai_until_done/worker.log 2>&1 &
    echo $! > runtime/ai_until_done.pid
    echo "✅ AI Parliament until-done worker started"
    echo "PID: $(cat runtime/ai_until_done.pid)"
    echo "Log: logs/ai_until_done/worker.log"
    ;;

  stop)
    if [ -f runtime/ai_until_done.pid ]; then
      kill "$(cat runtime/ai_until_done.pid)" 2>/dev/null || true
      rm -f runtime/ai_until_done.pid
    fi
    termux-wake-unlock 2>/dev/null || true
    echo "✅ stopped"
    ;;

  status)
    python3 cybra_ai_until_done.py status-shell
    test -f runtime/ai_until_done.pid && echo "PID=$(cat runtime/ai_until_done.pid)" || true
    test -f posts/ai_until_done_report.md && echo "REPORT=exists" || echo "REPORT=missing"
    ;;

  log)
    tail -f logs/ai_until_done/worker.log
    ;;

  report)
    cat posts/ai_until_done_report.md
    ;;

  proof)
    cat proofs/ai_until_done_report.sha256
    ;;

  *)
    echo "Usage:"
    echo "  bash cybra_ai_until_done.sh directive"
    echo "  bash cybra_ai_until_done.sh run 500"
    echo "  bash cybra_ai_until_done.sh start 500"
    echo "  bash cybra_ai_until_done.sh stop"
    echo "  bash cybra_ai_until_done.sh status"
    echo "  bash cybra_ai_until_done.sh log"
    echo "  bash cybra_ai_until_done.sh report"
    echo "  bash cybra_ai_until_done.sh proof"
    ;;
esac
