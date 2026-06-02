#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

case "${1:-status}" in
  run)
    python3 cybra_owner_orchestrator_finance_anchor_car.py
    ;;
  task)
    cybra parliament '{"topic":"Set OWNER as MAIN_ORCHESTRATOR and resolve finance risk / external anchor / car preflight","type":"owner_orchestrator_task","priority":"critical","payload":{"owner_role":"MAIN_ORCHESTRATOR","finance_risk":"conditional_hold_until_documents","external_anchor":"manual_anchor_package_ready","car_purchase":"tomorrow_preflight","real_payment_execution":false,"manual_owner_approval_required":true}}'
    ;;
  status)
    redis-cli ping
    echo "OWNER_ORCHESTRATOR_AUDIT: $(redis-cli LLEN cybra:owner_orchestrator:audit)"
    echo "FINANCE_RISK_RESOLUTION: $(redis-cli LLEN cybra:finance:risk_resolution)"
    echo "ANCHOR_MANUAL_READY: $(redis-cli LLEN cybra:blockchain:anchor:manual_ready)"
    echo "CAR_PREFLIGHT: $(redis-cli LLEN cybra:car_purchase:preflight)"
    echo "PARLIAMENT_QUEUE: $(redis-cli LLEN cybra:parliament:queue)"
    echo "PARLIAMENT_RESULTS: $(redis-cli LLEN cybra:parliament:results)"
    test -f posts/owner_orchestrator_finance_anchor_car.md && echo "REPORT: exists" || echo "REPORT: missing"
    ;;
  report)
    cat posts/owner_orchestrator_finance_anchor_car.md
    ;;
  feed)
    cat feeds/owner_orchestrator_finance_anchor_car.json
    ;;
  proof)
    cat proofs/owner_orchestrator_finance_anchor_car.sha256
    ;;
  anchor-ready)
    redis-cli LRANGE cybra:blockchain:anchor:manual_ready 0 10
    ;;
  car)
    redis-cli LRANGE cybra:car_purchase:preflight 0 10
    ;;
  *)
    echo "Usage: bash cybra_owner_orchestrator.sh run|task|status|report|feed|proof|anchor-ready|car"
    ;;
esac
