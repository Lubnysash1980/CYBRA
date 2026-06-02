#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

case "${1:-status}" in
  report)
    python3 cybra_kibra_mint_audit.py report
    cat posts/kibra_mint_audit_report.md
    ;;
  submit-ai)
    python3 cybra_kibra_mint_audit.py submit-ai
    ;;
  task)
    cybra parliament '{"topic":"KIBRA Mint Audit Department","type":"kibra_mint_audit_task","priority":"critical","payload":{"audit_mint":true,"audit_blocks":true,"audit_pools":true,"audit_task_blocks":true,"audit_bridge":true,"audit_promotion":true,"real_payment":false,"real_sell":false,"fake_price":false,"fake_volume":false,"manual_OWNER_approval_required":true}}'
    ;;
  cycle)
    python3 cybra_kibra_mint_audit.py submit-ai
    cybra parliament '{"topic":"KIBRA Mint Audit Department","type":"kibra_mint_audit_task","priority":"critical","payload":{"audit_mint":true,"audit_blocks":true,"audit_pools":true,"audit_task_blocks":true,"audit_bridge":true,"audit_promotion":true,"manual_OWNER_approval_required":true}}'
    python3 parliament_executor_v6.py || true
    python3 cybra_kibra_mint_audit.py report
    cat posts/kibra_mint_audit_report.md
    ;;
  until-done)
    python3 cybra_kibra_mint_audit.py submit-ai
    bash cybra_ai_blocks.sh until-done || true
    bash cybra_ai_until_done.sh run 300 || true
    python3 cybra_kibra_mint_audit.py report
    ;;
  status)
    redis-cli ping
    echo "MINT_AUDIT_AUDIT: $(redis-cli LLEN cybra:kibra:mint_audit:audit)"
    echo "MINT_AUDIT_RECS: $(redis-cli LLEN cybra:kibra:mint_audit:recommendations)"
    echo "MINT_AUDIT_AI_QUEUE: $(redis-cli LLEN cybra:ai:tasks:kibra_mint_audit)"
    echo "TASK_BLOCKS_MINED: $(redis-cli LLEN cybra:kibra:task_blocks:mined)"
    echo "POOL_MINING_BLOCKS: $(redis-cli LLEN cybra:kibra:pool:mining_blocks)"
    echo "MINT_REPAIR_QUEUE: $(redis-cli LLEN cybra:kibra:mint_repair:queue)"
    echo "BROKEN_BLOCKS: $(redis-cli LLEN cybra:kibra:broken_blocks)"
    echo "PARLIAMENT_QUEUE: $(redis-cli LLEN cybra:parliament:queue)"
    echo "PARLIAMENT_FAILED: $(redis-cli LLEN cybra:parliament:failed)"
    test -f posts/kibra_mint_audit_report.md && echo "REPORT: exists" || echo "REPORT: missing"
    ;;
  ai-tasks)
    cat data/kibra_mint_audit/ai_tasks.json
    ;;
  feed)
    cat feeds/kibra_mint_audit_report.json
    ;;
  proof)
    cat proofs/kibra_mint_audit.sha256
    ;;
  *)
    echo "Usage:"
    echo "  bash cybra_mint_audit.sh report"
    echo "  bash cybra_mint_audit.sh submit-ai"
    echo "  bash cybra_mint_audit.sh task"
    echo "  bash cybra_mint_audit.sh cycle"
    echo "  bash cybra_mint_audit.sh until-done"
    echo "  bash cybra_mint_audit.sh status"
    echo "  bash cybra_mint_audit.sh ai-tasks"
    echo "  bash cybra_mint_audit.sh feed"
    echo "  bash cybra_mint_audit.sh proof"
    ;;
esac
