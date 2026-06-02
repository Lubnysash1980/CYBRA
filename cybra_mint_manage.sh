#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

case "${1:-status}" in
  report)
    python3 cybra_kibra_mint_management.py report
    cat posts/kibra_mint_management_finance_report.md
    ;;
  submit-ai)
    python3 cybra_kibra_mint_management.py submit-ai
    ;;
  task)
    cybra parliament '{"topic":"KIBRA Mint Management and Finance Department","type":"kibra_mint_management_task","priority":"critical","payload":{"manage_mined_kibra":true,"profitable_realization_plan":true,"sell_without_crash":true,"utility_monetization":true,"finance_department":true,"real_sell_now":false,"fake_price":false,"fake_volume":false,"manual_OWNER_approval_required":true}}'
    ;;
  cycle)
    python3 cybra_kibra_mint_management.py submit-ai
    cybra parliament '{"topic":"KIBRA Mint Management and Finance Department","type":"kibra_mint_management_task","priority":"critical","payload":{"manage_mined_kibra":true,"profitable_realization_plan":true,"finance_department":true,"manual_OWNER_approval_required":true}}'
    python3 parliament_executor_v6.py || true
    python3 cybra_kibra_mint_management.py report
    cat posts/kibra_mint_management_finance_report.md
    ;;
  until-done)
    python3 cybra_kibra_mint_management.py submit-ai
    bash cybra_ai_blocks.sh until-done || true
    bash cybra_ai_until_done.sh run 300 || true
    python3 cybra_kibra_mint_management.py report
    ;;
  status)
    redis-cli ping
    echo "MINT_MANAGEMENT_AUDIT: $(redis-cli LLEN cybra:kibra:mint_management:audit)"
    echo "MINT_FINANCE_AUDIT: $(redis-cli LLEN cybra:kibra:mint_finance:audit)"
    echo "MINT_FINANCE_SELL_PLANS: $(redis-cli LLEN cybra:kibra:mint_finance:sell_plans)"
    echo "MINT_MANAGEMENT_RECS: $(redis-cli LLEN cybra:kibra:mint_management:recommendations)"
    echo "MINT_MANAGEMENT_AI_QUEUE: $(redis-cli LLEN cybra:ai:tasks:kibra_mint_management)"
    echo "TASK_BLOCKS_MINED: $(redis-cli LLEN cybra:kibra:task_blocks:mined)"
    echo "POOL_MINING_BLOCKS: $(redis-cli LLEN cybra:kibra:pool:mining_blocks)"
    echo "PARLIAMENT_QUEUE: $(redis-cli LLEN cybra:parliament:queue)"
    echo "PARLIAMENT_FAILED: $(redis-cli LLEN cybra:parliament:failed)"
    test -f posts/kibra_mint_management_finance_report.md && echo "REPORT: exists" || echo "REPORT: missing"
    test -f data/kibra_mint_finance/sell_plan.json && echo "SELL_PLAN: exists" || echo "SELL_PLAN: missing"
    ;;
  sell-plan)
    cat data/kibra_mint_finance/sell_plan.json
    ;;
  reward-policy)
    cat data/kibra_mint_finance/reward_policy.json
    ;;
  feed)
    cat feeds/kibra_mint_management_finance_report.json
    ;;
  proof)
    cat proofs/kibra_mint_management_finance.sha256
    ;;
  *)
    echo "Usage:"
    echo "  bash cybra_mint_manage.sh report"
    echo "  bash cybra_mint_manage.sh submit-ai"
    echo "  bash cybra_mint_manage.sh task"
    echo "  bash cybra_mint_manage.sh cycle"
    echo "  bash cybra_mint_manage.sh until-done"
    echo "  bash cybra_mint_manage.sh status"
    echo "  bash cybra_mint_manage.sh sell-plan"
    echo "  bash cybra_mint_manage.sh reward-policy"
    echo "  bash cybra_mint_manage.sh feed"
    echo "  bash cybra_mint_manage.sh proof"
    ;;
esac
