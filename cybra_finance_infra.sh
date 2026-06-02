#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

CMD="${1:-status}"
shift || true

case "$CMD" in
  run|report)
    python3 cybra_finance_infrastructure.py report
    cat posts/finance_infrastructure_report.md
    ;;
  task)
    cybra parliament '{"topic":"CYBRA Finance Infrastructure: token mint multipayment gold treasury","type":"finance_infrastructure_task","priority":"critical","payload":{"mode":"token_mint_multipayment_gold","automatic_calculation":true,"real_payment_execution":false,"automatic_token_mint":false,"automatic_gold_purchase":false,"manual_owner_approval_required":true}}'
    ;;
  mint-proposal)
    python3 cybra_finance_infrastructure.py mint-proposal "${1:-49000000000000000}"
    ;;
  settlement-proposal)
    python3 cybra_finance_infrastructure.py settlement-proposal "$1"
    ;;
  gold-proposal)
    python3 cybra_finance_infrastructure.py gold-proposal "${1:-0}"
    ;;
  status)
    redis-cli ping
    echo "FIN_INFRA_AUDIT: $(redis-cli LLEN cybra:finance:infrastructure:audit)"
    echo "MINT_PROPOSALS: $(redis-cli LLEN cybra:token_mint:proposals)"
    echo "PAYMENT_PROPOSALS: $(redis-cli LLEN cybra:payment:settlement:proposals)"
    echo "GOLD_PROPOSALS: $(redis-cli LLEN cybra:treasury:gold:proposals)"
    echo "FINANCE_LEDGER: $(redis-cli LLEN cybra:finance:ledger)"
    echo "PARLIAMENT_QUEUE: $(redis-cli LLEN cybra:parliament:queue)"
    echo "PARLIAMENT_RESULTS: $(redis-cli LLEN cybra:parliament:results)"
    test -f posts/finance_infrastructure_report.md && echo "REPORT: exists" || echo "REPORT: missing"
    ;;
  rails)
    cat payments/rails/payment_rails.json
    ;;
  policy)
    cat parliament/finance/infrastructure/finance_infrastructure_policy.json
    ;;
  mint-policy)
    cat token/kibra/mint/kibra_mint_policy.json
    ;;
  gold-policy)
    cat treasury/gold/gold_treasury_policy.json
    ;;
  proposals)
    echo "=== MINT ==="
    redis-cli LRANGE cybra:token_mint:proposals 0 10
    echo
    echo "=== PAYMENT ==="
    redis-cli LRANGE cybra:payment:settlement:proposals 0 10
    echo
    echo "=== GOLD ==="
    redis-cli LRANGE cybra:treasury:gold:proposals 0 10
    ;;
  proof)
    cat proofs/finance_infrastructure.sha256
    ;;
  *)
    echo "Usage: bash cybra_finance_infra.sh report|task|mint-proposal|settlement-proposal|gold-proposal|status|rails|policy|mint-policy|gold-policy|proposals|proof"
    ;;
esac
