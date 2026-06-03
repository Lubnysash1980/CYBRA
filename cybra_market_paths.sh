#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

case "${1:-status}" in
  status)
    python3 cybra_kibra_market_paths.py status
    ;;
  report|plan)
    python3 cybra_kibra_market_paths.py report
    cat posts/kibra_market_price_paths_report.md
    ;;
  submit-ai)
    python3 cybra_kibra_market_paths.py submit-ai
    bash cybra_ai_block_enforcer.sh enforce 3 || true
    ;;
  cycle)
    python3 cybra_kibra_market_paths.py submit-ai
    bash cybra_ai_block_enforcer.sh enforce 3 || true
    cybra parliament '{"topic":"KIBRA Market Price Paths","type":"kibra_market_price_paths_task","priority":"critical","payload":{"dex_pool_readiness":true,"orderbook_backend_provider":true,"reserve_backed_peg":true,"external_anchor_request":true,"all_tasks_to_mining_blocks_first":true,"real_sell_now":false,"manual_OWNER_approval_required":true}}' || true
    python3 parliament_executor_v6.py || true
    bash cybra_real_market_price_gate.sh verify || true
    python3 cybra_kibra_market_paths.py report
    ;;
  until-done)
    python3 cybra_kibra_market_paths.py submit-ai
    bash cybra_ai_block_enforcer.sh until-done 30 || true
    bash cybra_ai_until_done.sh run 300 || true
    bash cybra_real_market_price_gate.sh verify || true
    python3 cybra_kibra_market_paths.py report
    ;;
  orderbook-snapshot)
    python3 cybra_kibra_market_paths.py orderbook-snapshot "${2:-0}" "${3:-0}" "${4:-0}" "${5:-internal_backend_draft}"
    ;;
  files)
    echo "DEX:"
    cat data/kibra_market/dex_pool_readiness/dex_pool_readiness.json 2>/dev/null || true
    echo
    echo "ORDERBOOK:"
    cat data/kibra_market/orderbook_backend_provider/backend_provider_package.json 2>/dev/null || true
    echo
    echo "PEG:"
    cat data/kibra_market/reserve_backed_peg/peg_package.json 2>/dev/null || true
    echo
    echo "ANCHOR:"
    cat data/kibra_market/external_anchor_requests/price_paths_anchor_request.json 2>/dev/null || true
    ;;
  proof)
    cat proofs/kibra_market_price_paths.sha256
    ;;
  *)
    echo "Usage:"
    echo "  bash cybra_market_paths.sh status"
    echo "  bash cybra_market_paths.sh report"
    echo "  bash cybra_market_paths.sh submit-ai"
    echo "  bash cybra_market_paths.sh cycle"
    echo "  bash cybra_market_paths.sh until-done"
    echo "  bash cybra_market_paths.sh orderbook-snapshot <bid> <ask> <depth> [provider]"
    echo "  bash cybra_market_paths.sh files"
    ;;
esac
