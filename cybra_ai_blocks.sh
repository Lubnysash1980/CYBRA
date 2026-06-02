#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

case "${1:-status}" in
  collect)
    python3 cybra_ai_tasks_to_blocks.py collect
    ;;
  mine)
    python3 cybra_ai_tasks_to_blocks.py mine
    ;;
  cycle)
    python3 cybra_ai_tasks_to_blocks.py cycle
    ;;
  task)
    cybra parliament '{"topic":"AI tasks to KIBRA mining blocks","type":"ai_tasks_to_blocks_task","priority":"critical","payload":{"unfinished_ai_tasks_to_blocks":true,"blocks_to_pool_mining":true,"do_not_send_blocks_directly":true,"manual_OWNER_approval_required":true}}'
    ;;
  until-done)
    for i in $(seq 1 50); do
      echo "AI-BLOCK-CYCLE $i"
      python3 cybra_ai_tasks_to_blocks.py cycle
      bash cybra_ai_until_done.sh run 50 || true
      [ "$(redis-cli LLEN cybra:kibra:task_blocks:mempool)" = "0" ] && break
      sleep 1
    done
    ;;
  status)
    python3 cybra_ai_tasks_to_blocks.py status
    echo "PARLIAMENT_QUEUE: $(redis-cli LLEN cybra:parliament:queue)"
    echo "PARLIAMENT_FAILED: $(redis-cli LLEN cybra:parliament:failed)"
    test -f posts/ai_tasks_to_mining_blocks_report.md && echo "REPORT: exists" || echo "REPORT: missing"
    ;;
  report)
    cat posts/ai_tasks_to_mining_blocks_report.md
    ;;
  proof)
    cat proofs/ai_tasks_to_mining_blocks.sha256
    ;;
  *)
    echo "Usage: bash cybra_ai_blocks.sh collect|mine|cycle|task|until-done|status|report|proof"
    ;;
esac
