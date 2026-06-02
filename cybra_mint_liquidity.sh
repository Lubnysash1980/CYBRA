#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

case "${1:-status}" in
  report|plan)
    python3 cybra_kibra_mint_liquidity.py report
    cat posts/kibra_mint_liquidity_report.md
    ;;
  submit-ai)
    python3 cybra_kibra_mint_liquidity.py submit-ai
    bash cybra_ai_block_enforcer.sh enforce 3 || true
    ;;
  set-reserves)
    python3 cybra_kibra_mint_liquidity.py set-reserves "$2" "$3" "${4:-manual_liquidity_reference}"
    ;;
  task)
    cybra parliament '{"topic":"KIBRA Mint Liquidity Department","type":"kibra_mint_liquidity_task","priority":"critical","payload":{"liquidity_department":true,"pool_reserves":true,"orderbook_depth":true,"sell_without_crash":true,"fake_price":false,"fake_volume":false,"real_pool_now":false,"real_sell_now":false,"manual_OWNER_approval_required":true}}'
    ;;
  cycle)
    python3 cybra_kibra_mint_liquidity.py submit-ai
    bash cybra_ai_block_enforcer.sh enforce 3 || true
    cybra parliament '{"topic":"KIBRA Mint Liquidity Department","type":"kibra_mint_liquidity_task","priority":"critical","payload":{"liquidity_department":true,"manual_OWNER_approval_required":true}}'
    python3 parliament_executor_v6.py || true
    python3 cybra_kibra_mint_liquidity.py report
    ;;
  until-done)
    python3 cybra_kibra_mint_liquidity.py submit-ai
    bash cybra_ai_block_enforcer.sh until-done 20 || true
    bash cybra_ai_until_done.sh run 300 || true
    python3 cybra_kibra_mint_liquidity.py report
    ;;
  status)
    redis-cli ping
    echo "MINT_LIQUIDITY_AUDIT: $(redis-cli LLEN cybra:kibra:mint_liquidity:audit)"
    echo "MINT_LIQUIDITY_RECS: $(redis-cli LLEN cybra:kibra:mint_liquidity:recommendations)"
    echo "MINT_LIQUIDITY_PLANS: $(redis-cli LLEN cybra:kibra:mint_liquidity:plans)"
    echo "BLOCK_INBOX: $(redis-cli LLEN cybra:ai:tasks:block_inbox)"
    echo "TASK_BLOCK_MEMPOOL: $(redis-cli LLEN cybra:kibra:task_blocks:mempool)"
    echo "TASK_BLOCKS_MINED: $(redis-cli LLEN cybra:kibra:task_blocks:mined)"
    echo "POOL_MINING_BLOCKS: $(redis-cli LLEN cybra:kibra:pool:mining_blocks)"
    echo "PARLIAMENT_QUEUE: $(redis-cli LLEN cybra:parliament:queue)"
    echo "PARLIAMENT_FAILED: $(redis-cli LLEN cybra:parliament:failed)"
    test -f posts/kibra_mint_liquidity_report.md && echo "REPORT: exists" || echo "REPORT: missing"
    test -f data/kibra_mint_liquidity/liquidity_plan.json && echo "LIQUIDITY_PLAN: exists" || echo "LIQUIDITY_PLAN: missing"
    ;;
  liquidity-plan)
    cat data/kibra_mint_liquidity/liquidity_plan.json
    ;;
  reserves)
    cat data/kibra_market/pool_reserves.json
    ;;
  proof)
    cat proofs/kibra_mint_liquidity.sha256
    ;;
  *)
    echo "Usage:"
    echo "  bash cybra_mint_liquidity.sh report"
    echo "  bash cybra_mint_liquidity.sh submit-ai"
    echo "  bash cybra_mint_liquidity.sh set-reserves <quote_usd> <kibra_reserve> <source>"
    echo "  bash cybra_mint_liquidity.sh task"
    echo "  bash cybra_mint_liquidity.sh cycle"
    echo "  bash cybra_mint_liquidity.sh until-done"
    echo "  bash cybra_mint_liquidity.sh status"
    echo "  bash cybra_mint_liquidity.sh liquidity-plan"
    echo "  bash cybra_mint_liquidity.sh reserves"
    ;;
esac
