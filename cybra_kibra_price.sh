#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

case "${1:-status}" in
  report)
    python3 cybra_kibra_price_sell_repair.py report
    cat posts/kibra_price_sell_repair_report.md
    ;;
  submit-ai)
    python3 cybra_kibra_price_sell_repair.py submit-ai
    ;;
  task)
    cybra parliament '{"topic":"KIBRA price sell mint repair","type":"kibra_price_sell_repair_task","priority":"critical","payload":{"market_price_required":true,"sell_proposal":true,"broken_blocks_to_mint_repair":true,"real_sell_execution_now":false,"manual_OWNER_approval_required":true}}'
    ;;
  until-done)
    python3 cybra_kibra_price_sell_repair.py submit-ai
    bash cybra_ai_until_done.sh run 500
    ;;
  set-reserves)
    python3 cybra_kibra_price_sell_repair.py set-reserves "$2" "$3" "${4:-manual_pool_reserves}"
    ;;
  status)
    redis-cli ping
    echo "PRICE_SELL_REPAIR_AUDIT: $(redis-cli LLEN cybra:kibra_price_sell_repair:audit)"
    echo "SELL_PROPOSALS: $(redis-cli LLEN cybra:kibra:sell_proposals)"
    echo "BROKEN_BLOCKS: $(redis-cli LLEN cybra:kibra:broken_blocks)"
    echo "MINT_REPAIR_QUEUE: $(redis-cli LLEN cybra:kibra:mint_repair:queue)"
    echo "AI_QUEUE: $(redis-cli LLEN cybra:ai:tasks:kibra_price_sell_repair)"
    echo "PARLIAMENT_QUEUE: $(redis-cli LLEN cybra:parliament:queue)"
    echo "PARLIAMENT_FAILED: $(redis-cli LLEN cybra:parliament:failed)"
    test -f posts/kibra_price_sell_repair_report.md && echo "REPORT: exists" || echo "REPORT: missing"
    ;;
  sell-proposal)
    cat data/kibra_sell/latest_sell_proposal.json
    ;;
  proof)
    cat proofs/kibra_price_sell_repair.sha256
    ;;
  *)
    echo "Usage:"
    echo "  bash cybra_kibra_price.sh report"
    echo "  bash cybra_kibra_price.sh submit-ai"
    echo "  bash cybra_kibra_price.sh task"
    echo "  bash cybra_kibra_price.sh until-done"
    echo "  bash cybra_kibra_price.sh set-reserves <quote_usd> <kibra_reserve> <source>"
    echo "  bash cybra_kibra_price.sh status"
    echo "  bash cybra_kibra_price.sh sell-proposal"
    ;;
esac
