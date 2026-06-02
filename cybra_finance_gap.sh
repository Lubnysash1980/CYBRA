#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

case "${1:-status}" in
  report)
    python3 cybra_finance_gap_evolution.py report
    cat posts/finance_gap_evolution_report.md
    ;;
  submit-ai)
    python3 cybra_finance_gap_evolution.py submit-ai
    ;;
  task)
    cybra parliament '{"topic":"Finance Gap Evolution Committee Scan","type":"finance_gap_evolution_task","priority":"critical","payload":{"mode":"detect_missing_create_ai_recommendations","real_payment_execution":false,"automatic_token_mint":false,"automatic_pool":false,"manual_OWNER_approval_required":true}}'
    ;;
  cycle)
    python3 cybra_finance_gap_evolution.py submit-ai
    cybra parliament '{"topic":"Finance Gap Evolution Committee Scan","type":"finance_gap_evolution_task","priority":"critical","payload":{"mode":"detect_missing_create_ai_recommendations","real_payment_execution":false,"automatic_token_mint":false,"automatic_pool":false,"manual_OWNER_approval_required":true}}'

    for i in $(seq 1 30); do
      echo "round=$i queue=$(redis-cli LLEN cybra:parliament:queue)"
      python3 parliament_executor_v6.py || true
      sleep 1
      [ "$(redis-cli LLEN cybra:parliament:queue)" = "0" ] && break
    done

    python3 cybra_finance_gap_evolution.py report
    cat posts/finance_gap_evolution_report.md
    ;;
  status)
    redis-cli ping
    echo "FINANCE_GAP_AUDIT: $(redis-cli LLEN cybra:finance_gap_evolution:audit)"
    echo "FINANCE_GAP_RECOMMENDATIONS: $(redis-cli LLEN cybra:finance_gap_evolution:recommendations)"
    echo "FINANCE_GAP_AI_TASKS: $(redis-cli LLEN cybra:finance_gap_evolution:ai_tasks)"
    echo "AI_QUEUE: $(redis-cli LLEN cybra:ai:tasks:finance_gap_evolution)"
    echo "PARLIAMENT_QUEUE: $(redis-cli LLEN cybra:parliament:queue)"
    echo "PARLIAMENT_RESULTS: $(redis-cli LLEN cybra:parliament:results)"
    test -f posts/finance_gap_evolution_report.md && echo "REPORT: exists" || echo "REPORT: missing"
    ;;
  recommendations)
    redis-cli LRANGE cybra:finance_gap_evolution:recommendations 0 10
    ;;
  ai-tasks)
    cat data/finance_gap_evolution/ai_tasks.json
    ;;
  feed)
    cat feeds/finance_gap_evolution_report.json
    ;;
  proof)
    cat proofs/finance_gap_evolution.sha256
    ;;
  *)
    echo "Usage: bash cybra_finance_gap.sh report|submit-ai|task|cycle|status|recommendations|ai-tasks|feed|proof"
    ;;
esac
