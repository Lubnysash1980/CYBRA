#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

case "${1:-status}" in
  report)
    python3 cybra_kibra_block_ai_support.py report
    cat posts/kibra_block_ai_support_report.md
    ;;
  submit)
    python3 cybra_kibra_block_ai_support.py submit
    ;;
  task)
    cybra parliament '{"topic":"KIBRA blocks AI Parliament support","type":"kibra_block_ai_support_task","priority":"critical","payload":{"send_blocks_with_ai_tasks":true,"support_ai_parliament":true,"real_network_broadcast_now":false,"manual_OWNER_approval_required":true}}'
    ;;
  until-done)
    python3 cybra_kibra_block_ai_support.py submit
    bash cybra_ai_until_done.sh run 500
    ;;
  status)
    redis-cli ping
    echo "BLOCK_AI_AUDIT: $(redis-cli LLEN cybra:kibra:block_ai_support:audit)"
    echo "BLOCK_AI_QUEUE: $(redis-cli LLEN cybra:ai:tasks:kibra_block_ai_support)"
    echo "BLOCK_AI_OUTBOX: $(redis-cli LLEN cybra:kibra:block_ai_support:outbox)"
    echo "SENT_HASHES: $(redis-cli SCARD cybra:kibra:block_ai_support:sent_hashes)"
    echo "PARLIAMENT_QUEUE: $(redis-cli LLEN cybra:parliament:queue)"
    echo "PARLIAMENT_FAILED: $(redis-cli LLEN cybra:parliament:failed)"
    test -f posts/kibra_block_ai_support_report.md && echo "REPORT: exists" || echo "REPORT: missing"
    ;;
  tasks)
    cat data/kibra_block_ai_support/tasks/block_ai_tasks.json
    ;;
  outbox)
    cat data/kibra_block_ai_support/outbox/block_ai_outbox.json
    ;;
  proof)
    cat proofs/kibra_block_ai_support.sha256
    ;;
  *)
    echo "Usage:"
    echo "  bash cybra_kibra_block_ai.sh report"
    echo "  bash cybra_kibra_block_ai.sh submit"
    echo "  bash cybra_kibra_block_ai.sh task"
    echo "  bash cybra_kibra_block_ai.sh until-done"
    echo "  bash cybra_kibra_block_ai.sh status"
    echo "  bash cybra_kibra_block_ai.sh tasks"
    echo "  bash cybra_kibra_block_ai.sh outbox"
    echo "  bash cybra_kibra_block_ai.sh proof"
    ;;
esac
