#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

case "${1:-status}" in
  repair)
    python3 cybra_existing_tasks_evolution_activation.py repair
    ;;
  report)
    python3 cybra_existing_tasks_evolution_activation.py report
    cat posts/existing_tasks_evolution_activation.md
    ;;
  task)
    python3 cybra_existing_tasks_evolution_activation.py task
    ;;
  cycle)
    python3 cybra_existing_tasks_evolution_activation.py repair
    python3 cybra_existing_tasks_evolution_activation.py task

    for i in $(seq 1 30); do
      echo "round=$i queue=$(redis-cli LLEN cybra:parliament:queue)"
      python3 parliament_executor_v6.py || true
      sleep 1
      [ "$(redis-cli LLEN cybra:parliament:queue)" = "0" ] && break
    done

    bash cybra_evolution_deploy.sh report >/dev/null 2>&1 || true
    python3 cybra_existing_tasks_evolution_activation.py report
    cat posts/existing_tasks_evolution_activation.md
    ;;
  status)
    redis-cli ping
    echo "EXISTING_TASKS_AUDIT: $(redis-cli LLEN cybra:existing_tasks_activation:audit)"
    echo "PARLIAMENT_QUEUE: $(redis-cli LLEN cybra:parliament:queue)"
    echo "PARLIAMENT_RESULTS: $(redis-cli LLEN cybra:parliament:results)"
    echo "PARLIAMENT_FAILED: $(redis-cli LLEN cybra:parliament:failed)"
    echo "FAILED_ARCHIVE: $(redis-cli LLEN cybra:parliament:failed:archive)"
    echo "MAPPING_COUNT: $(redis-cli HLEN cybra:executor:mapping)"
    test -f posts/existing_tasks_evolution_activation.md && echo "REPORT: exists" || echo "REPORT: missing"
    ;;
  feed)
    cat feeds/existing_tasks_evolution_activation.json
    ;;
  proof)
    cat proofs/existing_tasks_evolution_activation.sha256
    ;;
  *)
    echo "Usage: bash cybra_existing_tasks.sh repair|report|task|cycle|status|feed|proof"
    ;;
esac
