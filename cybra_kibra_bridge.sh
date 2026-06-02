#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

case "${1:-status}" in
  report)
    python3 cybra_kibra_bridge_pool.py report
    cat posts/kibra_bridge_pool_monetization_report.md
    ;;
  submit-ai)
    python3 cybra_kibra_bridge_pool.py submit-ai
    ;;
  task)
    cybra parliament '{"topic":"KIBRA bridge pool monetization until done","type":"kibra_bridge_pool_task","priority":"critical","payload":{"closed_sha_bridge":true,"pool_monetization":true,"ai_block_creation":true,"real_network_broadcast_now":false,"manual_OWNER_approval_required":true}}'
    ;;
  until-done)
    python3 cybra_kibra_bridge_pool.py submit-ai
    bash cybra_ai_until_done.sh run 500
    ;;
  status)
    redis-cli ping
    echo "BRIDGE_AUDIT: $(redis-cli LLEN cybra:kibra_bridge:audit)"
    echo "BRIDGE_OUTBOX: $(redis-cli LLEN cybra:kibra_bridge:network_outbox)"
    echo "SEALED_PACKAGES: $(redis-cli LLEN cybra:kibra_bridge:sealed_packages)"
    echo "AI_QUEUE: $(redis-cli LLEN cybra:ai:tasks:kibra_bridge_pool_until_done)"
    echo "MANUAL_ANCHOR_READY: $(redis-cli LLEN cybra:blockchain:anchor:manual_ready)"
    echo "PARLIAMENT_QUEUE: $(redis-cli LLEN cybra:parliament:queue)"
    echo "PARLIAMENT_FAILED: $(redis-cli LLEN cybra:parliament:failed)"
    test -f posts/kibra_bridge_pool_monetization_report.md && echo "REPORT: exists" || echo "REPORT: missing"
    ;;
  outbox)
    ls -lh data/kibra_bridge/outbox/
    ;;
  sealed)
    ls -lh data/kibra_bridge/sealed/
    ;;
  feed)
    cat feeds/kibra_bridge_pool_monetization_report.json
    ;;
  proof)
    cat proofs/kibra_bridge_pool_monetization.sha256
    ;;
  *)
    echo "Usage: bash cybra_kibra_bridge.sh report|submit-ai|task|until-done|status|outbox|sealed|feed|proof"
    ;;
esac
