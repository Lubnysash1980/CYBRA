#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

CMD="${1:-status}"

case "$CMD" in
  run)
    python3 cybra_token_pool_ai_orchestrator.py run
    ;;
  task)
    cybra parliament '{"topic":"CYBRA Token Pool AI Finance Orchestrator","type":"token_pool_ai_task","priority":"high","payload":{"mode":"60_40_pool_ai_block_proof","owner_share_percent":60,"pool_reward_percent":40,"real_execution":false,"manual_approval_required":true}}'
    ;;
  status)
    redis-cli ping
    echo "TOKEN_POOL_AI_AUDIT: $(redis-cli LLEN cybra:token_pool_ai:audit)"
    echo "FINANCE_LEDGER: $(redis-cli LLEN cybra:finance:ledger)"
    echo "BLOCKCHAIN_ANCHOR_QUEUE: $(redis-cli LLEN cybra:blockchain:anchor:queue)"
    echo "PARLIAMENT_QUEUE: $(redis-cli LLEN cybra:parliament:queue)"
    echo "PARLIAMENT_RESULTS: $(redis-cli LLEN cybra:parliament:results)"
    test -f posts/token_pool_ai_status.md && echo "REPORT: exists" || echo "REPORT: missing"
    test -f blocks/token_pool_ai/latest.block.hash && echo "BLOCK_HASH: $(cat blocks/token_pool_ai/latest.block.hash)" || echo "BLOCK_HASH: missing"
    ;;
  report)
    cat posts/token_pool_ai_status.md
    ;;
  feed)
    cat feeds/token_pool_ai_status.json
    ;;
  proof)
    cat proofs/token_pool_ai.sha256
    ;;
  block)
    cat blocks/token_pool_ai/latest.block.json
    ;;
  hash)
    cat blocks/token_pool_ai/latest.block.hash
    ;;
  anchor-queue)
    redis-cli LRANGE cybra:blockchain:anchor:queue 0 20
    ;;
  *)
    echo "Usage: bash cybra_token_pool_ai.sh run|task|status|report|feed|proof|block|hash|anchor-queue"
    ;;
esac
