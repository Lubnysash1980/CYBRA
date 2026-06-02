#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

case "${1:-status}" in
  report)
    python3 cybra_kibra_mint_promotion.py report
    cat posts/kibra_mint_promotion_report.md
    ;;
  submit-ai)
    python3 cybra_kibra_mint_promotion.py submit-ai
    ;;
  task)
    cybra parliament '{"topic":"KIBRA Mint Promotion Department","type":"kibra_mint_promotion_task","priority":"critical","payload":{"promote_native_kibra":true,"promote_ai_task_blocks":true,"promote_pool_mining":true,"promote_bridge_proof":true,"promote_difficulty_classes":true,"fake_price":false,"fake_volume":false,"guaranteed_profit":false,"manual_OWNER_approval_required":true}}'
    ;;
  cycle)
    python3 cybra_kibra_mint_promotion.py submit-ai
    cybra parliament '{"topic":"KIBRA Mint Promotion Department","type":"kibra_mint_promotion_task","priority":"critical","payload":{"promote_native_kibra":true,"promote_ai_task_blocks":true,"promote_pool_mining":true,"promote_bridge_proof":true,"promote_difficulty_classes":true,"manual_OWNER_approval_required":true}}'
    python3 parliament_executor_v6.py || true
    python3 cybra_kibra_mint_promotion.py report
    cat posts/kibra_mint_promotion_report.md
    ;;
  until-done)
    python3 cybra_kibra_mint_promotion.py submit-ai
    bash cybra_ai_blocks.sh until-done || true
    bash cybra_ai_until_done.sh run 300 || true
    python3 cybra_kibra_mint_promotion.py report
    ;;
  status)
    redis-cli ping
    echo "MINT_PROMOTION_AUDIT: $(redis-cli LLEN cybra:kibra:mint_promotion:audit)"
    echo "MINT_PROMOTION_RECS: $(redis-cli LLEN cybra:kibra:mint_promotion:recommendations)"
    echo "MINT_PROMOTION_AI_QUEUE: $(redis-cli LLEN cybra:ai:tasks:kibra_mint_promotion)"
    echo "PARLIAMENT_QUEUE: $(redis-cli LLEN cybra:parliament:queue)"
    echo "PARLIAMENT_FAILED: $(redis-cli LLEN cybra:parliament:failed)"
    test -f posts/kibra_mint_promotion_report.md && echo "REPORT: exists" || echo "REPORT: missing"
    test -f website/kibra/promotion.html && echo "PROMOTION_PAGE: exists" || echo "PROMOTION_PAGE: missing"
    ;;
  plan)
    cat data/kibra_mint_promotion/promotion_plan.json
    ;;
  page)
    cat website/kibra/promotion.html
    ;;
  proof)
    cat proofs/kibra_mint_promotion.sha256
    ;;
  *)
    echo "Usage:"
    echo "  bash cybra_mint_promo.sh report"
    echo "  bash cybra_mint_promo.sh submit-ai"
    echo "  bash cybra_mint_promo.sh task"
    echo "  bash cybra_mint_promo.sh cycle"
    echo "  bash cybra_mint_promo.sh until-done"
    echo "  bash cybra_mint_promo.sh status"
    echo "  bash cybra_mint_promo.sh plan"
    echo "  bash cybra_mint_promo.sh page"
    echo "  bash cybra_mint_promo.sh proof"
    ;;
esac
