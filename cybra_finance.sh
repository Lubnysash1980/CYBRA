#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

CMD="${1:-status}"
shift || true

case "$CMD" in
  report)
    python3 cybra_finance_department.py report
    cat posts/finance_department_report.md
    ;;
  task)
    cybra parliament '{"topic":"CYBRA Finance Department","type":"finance_department_task","priority":"high","payload":{"mode":"budget_risk_audit_no_payment_execution"}}'
    ;;
  ledger-add)
    python3 cybra_finance_department.py ledger-add "$1"
    ;;
  ledger)
    redis-cli LRANGE cybra:finance:ledger 0 20
    ;;
  audit)
    redis-cli LRANGE cybra:finance:audit 0 20
    ;;
  status)
    redis-cli ping
    echo "FINANCE_AUDIT: $(redis-cli LLEN cybra:finance:audit)"
    echo "FINANCE_LEDGER: $(redis-cli LLEN cybra:finance:ledger)"
    echo "PARLIAMENT_QUEUE: $(redis-cli LLEN cybra:parliament:queue)"
    echo "PARLIAMENT_RESULTS: $(redis-cli LLEN cybra:parliament:results)"
    echo "MAPPING: $(redis-cli HGET cybra:executor:mapping finance_department_task)"
    test -f posts/finance_department_report.md && echo "REPORT: exists" || echo "REPORT: missing"
    ;;
  feed)
    cat feeds/finance_department_report.json
    ;;
  proof)
    cat proofs/finance_department.sha256
    ;;
  policy)
    cat parliament/finance/finance_policy.json
    ;;
  *)
    echo "Usage: bash cybra_finance.sh report|task|ledger-add|ledger|audit|status|feed|proof|policy"
    ;;
esac
