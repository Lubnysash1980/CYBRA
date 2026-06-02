#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

CMD="${1:-status}"
shift || true

case "$CMD" in
  run|report)
    python3 cybra_monetization_department.py report
    cat posts/monetization_department_report.md
    ;;
  task)
    cybra parliament '{"topic":"CYBRA KIBRA Monetization Department","type":"monetization_department_task","priority":"critical","payload":{"mode":"utility_first_monetization","token":"KIBRA","spendability":true,"price_guaranteed":false,"owner_share_percent":60,"pool_share_percent":40,"evolution_required":true,"manual_owner_approval_required":true,"real_payment_execution":false}}'
    ;;
  evolution-task)
    TASK='{"topic":"CYBRA KIBRA Monetization Evolution","type":"monetization_department_task","priority":"critical","payload":{"goal":"розвиток utility proof finance analytics revision hash recovery mapping documentation safe monetization","token":"KIBRA","price_guaranteed":false,"manual_owner_approval_required":true,"no_market_manipulation":true}}'
    if [ -f cybra_evolution_guard.py ]; then
      python3 cybra_evolution_guard.py inspect "$TASK"
      python3 cybra_evolution_guard.py submit "$TASK"
    else
      cybra parliament "$TASK"
    fi
    ;;
  spend)
    python3 cybra_monetization_department.py spend "${1:-KIBRA-AI-TASK}" "${2:-0}"
    ;;
  proposals)
    redis-cli LRANGE cybra:monetization:proposals 0 20
    ;;
  spend-proposals)
    redis-cli LRANGE cybra:monetization:spend_proposals 0 20
    ;;
  audit)
    redis-cli LRANGE cybra:monetization:audit 0 20
    ;;
  evolution)
    redis-cli LRANGE cybra:monetization:evolution_cycles 0 20
    ;;
  status)
    redis-cli ping
    echo "MONETIZATION_AUDIT: $(redis-cli LLEN cybra:monetization:audit)"
    echo "MONETIZATION_PROPOSALS: $(redis-cli LLEN cybra:monetization:proposals)"
    echo "SPEND_PROPOSALS: $(redis-cli LLEN cybra:monetization:spend_proposals)"
    echo "EVOLUTION_CYCLES: $(redis-cli LLEN cybra:monetization:evolution_cycles)"
    echo "PARLIAMENT_QUEUE: $(redis-cli LLEN cybra:parliament:queue)"
    echo "PARLIAMENT_RESULTS: $(redis-cli LLEN cybra:parliament:results)"
    test -f posts/monetization_department_report.md && echo "REPORT: exists" || echo "REPORT: missing"
    ;;
  feed)
    cat feeds/monetization_department_report.json
    ;;
  proof)
    cat proofs/monetization_department.sha256
    ;;
  catalog)
    cat token/kibra/monetization/utility_catalog.json
    ;;
  price)
    cat token/kibra/monetization/price_model_proposal.json
    ;;
  liquidity)
    cat token/kibra/monetization/liquidity_plan_proposal.json
    ;;
  *)
    echo "Usage: bash cybra_monetization.sh run|task|evolution-task|spend|status|proposals|spend-proposals|audit|evolution|feed|proof|catalog|price|liquidity"
    ;;
esac
