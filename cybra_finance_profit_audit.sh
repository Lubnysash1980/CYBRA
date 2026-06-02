#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

case "${1:-status}" in
  report)
    python3 cybra_finance_token_profit_audit.py report
    cat posts/finance_token_profit_audit_report.md
    ;;
  submit-ai)
    python3 cybra_finance_token_profit_audit.py submit-ai
    ;;
  task)
    cybra parliament '{"topic":"CYBRA Finance Token Profit Audit","type":"finance_token_profit_audit_task","priority":"critical","payload":{"mode":"audit_finance_token_creation_profit_optimization","real_payment_execution":false,"automatic_token_mint":false,"automatic_liquidity_pool":false,"no_guaranteed_profit":true,"manual_OWNER_approval_required":true}}'
    ;;
  cycle)
    python3 cybra_finance_token_profit_audit.py submit-ai
    cybra parliament '{"topic":"CYBRA Finance Token Profit Audit","type":"finance_token_profit_audit_task","priority":"critical","payload":{"mode":"audit_finance_token_creation_profit_optimization","real_payment_execution":false,"automatic_token_mint":false,"automatic_liquidity_pool":false,"no_guaranteed_profit":true,"manual_OWNER_approval_required":true}}'

    for i in $(seq 1 30); do
      echo "round=$i queue=$(redis-cli LLEN cybra:parliament:queue)"
      python3 parliament_executor_v6.py || true
      sleep 1
      [ "$(redis-cli LLEN cybra:parliament:queue)" = "0" ] && break
    done

    python3 cybra_finance_token_profit_audit.py report
    cat posts/finance_token_profit_audit_report.md
    ;;
  status)
    redis-cli ping
    echo "FINANCE_PROFIT_AUDIT: $(redis-cli LLEN cybra:finance_profit_audit:audit)"
    echo "FINANCE_PROFIT_RECOMMENDATIONS: $(redis-cli LLEN cybra:finance_profit_audit:recommendations)"
    echo "FINANCE_PROFIT_AI_TASKS: $(redis-cli LLEN cybra:finance_profit_audit:ai_tasks)"
    echo "AI_QUEUE: $(redis-cli LLEN cybra:ai:tasks:finance_profit_audit)"
    echo "PARLIAMENT_QUEUE: $(redis-cli LLEN cybra:parliament:queue)"
    echo "PARLIAMENT_RESULTS: $(redis-cli LLEN cybra:parliament:results)"
    test -f posts/finance_token_profit_audit_report.md && echo "REPORT: exists" || echo "REPORT: missing"
    ;;
  recommendations)
    redis-cli LRANGE cybra:finance_profit_audit:recommendations 0 10
    ;;
  ai-tasks)
    cat data/finance_profit_audit/ai_tasks.json
    ;;
  feed)
    cat feeds/finance_token_profit_audit_report.json
    ;;
  proof)
    cat proofs/finance_token_profit_audit.sha256
    ;;
  *)
    echo "Usage: bash cybra_finance_profit_audit.sh report|submit-ai|task|cycle|status|recommendations|ai-tasks|feed|proof"
    ;;
esac
