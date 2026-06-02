#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

case "${1:-status}" in
  report)
    python3 cybra_kibra_stats_recommendations.py report
    cat posts/kibra_stats_recommendations_report.md
    ;;
  submit-ai)
    python3 cybra_kibra_stats_recommendations.py submit-ai
    ;;
  task)
    cybra parliament '{"topic":"KIBRA Statistics and Parliament Recommendations","type":"kibra_stats_recommendations_task","priority":"critical","payload":{"statistics":true,"recommendations":true,"ai_tasks":true,"real_sell":false,"real_payment":false,"manual_OWNER_approval_required":true}}'
    ;;
  cycle)
    python3 cybra_kibra_stats_recommendations.py submit-ai
    cybra parliament '{"topic":"KIBRA Statistics and Parliament Recommendations","type":"kibra_stats_recommendations_task","priority":"critical","payload":{"statistics":true,"recommendations":true,"ai_tasks":true,"manual_OWNER_approval_required":true}}'
    python3 parliament_executor_v6.py || true
    python3 cybra_kibra_stats_recommendations.py report
    cat posts/kibra_stats_recommendations_report.md
    ;;
  until-done)
    python3 cybra_kibra_stats_recommendations.py submit-ai
    bash cybra_ai_blocks.sh until-done || true
    bash cybra_ai_until_done.sh run 300 || true
    python3 cybra_kibra_stats_recommendations.py report
    ;;
  status)
    redis-cli ping
    echo "STATS_AUDIT: $(redis-cli LLEN cybra:kibra:stats_recommendations:audit)"
    echo "STATS_RECS: $(redis-cli LLEN cybra:kibra:stats_recommendations:recommendations)"
    echo "STATS_AI_QUEUE: $(redis-cli LLEN cybra:ai:tasks:kibra_stats_recommendations)"
    echo "BLOCKS: $(find blockchain/kibra_chain/blocks -name 'block_*.json' 2>/dev/null | wc -l)"
    echo "TASK_BLOCKS: $(find blockchain/kibra_chain/task_blocks -name '*.json' 2>/dev/null | wc -l)"
    echo "PARLIAMENT_QUEUE: $(redis-cli LLEN cybra:parliament:queue)"
    echo "PARLIAMENT_FAILED: $(redis-cli LLEN cybra:parliament:failed)"
    test -f posts/kibra_stats_recommendations_report.md && echo "REPORT: exists" || echo "REPORT: missing"
    ;;
  recommendations)
    cat data/kibra_stats_recommendations/recommendations.json
    ;;
  ai-tasks)
    cat data/kibra_stats_recommendations/ai_tasks.json
    ;;
  feed)
    cat feeds/kibra_stats_recommendations_report.json
    ;;
  proof)
    cat proofs/kibra_stats_recommendations.sha256
    ;;
  *)
    echo "Usage:"
    echo "  bash cybra_kibra_stats.sh report"
    echo "  bash cybra_kibra_stats.sh submit-ai"
    echo "  bash cybra_kibra_stats.sh task"
    echo "  bash cybra_kibra_stats.sh cycle"
    echo "  bash cybra_kibra_stats.sh until-done"
    echo "  bash cybra_kibra_stats.sh status"
    echo "  bash cybra_kibra_stats.sh recommendations"
    echo "  bash cybra_kibra_stats.sh ai-tasks"
    ;;
esac
