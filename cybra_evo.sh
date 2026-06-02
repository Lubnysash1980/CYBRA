#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

CMD="${1:-status}"
shift || true

case "$CMD" in
  auto)
    python3 cybra_evo_committee_factory.py auto
    ;;
  create)
    python3 cybra_evo_committee_factory.py create "$@"
    ;;
  task)
    cybra parliament '{"topic":"CYBRA EVO Committee Creation","type":"evo_committee_task","priority":"high","payload":{"mode":"auto_create_support_committees"}}'
    ;;
  status)
    redis-cli ping
    echo "EVO_AUDIT: $(redis-cli LLEN cybra:evo:audit)"
    echo "EVO_COMMITTEES: $(redis-cli HLEN cybra:evo:committees)"
    echo "EXECUTOR_MAPPING: $(redis-cli HLEN cybra:executor:mapping)"
    echo "PARLIAMENT_QUEUE: $(redis-cli LLEN cybra:parliament:queue)"
    echo "PARLIAMENT_RESULTS: $(redis-cli LLEN cybra:parliament:results)"
    test -f posts/evo_committee_report.md && echo "REPORT: exists" || echo "REPORT: missing"
    ;;
  list)
    redis-cli HGETALL cybra:evo:committees
    ;;
  report)
    cat posts/evo_committee_report.md
    ;;
  feed)
    cat feeds/evo_committee_report.json
    ;;
  proof)
    cat proofs/evo_committee.sha256
    ;;
  audit)
    redis-cli LRANGE cybra:evo:audit 0 20
    ;;
  laws)
    cat parliament/evo/evo_laws.json
    ;;
  *)
    echo "Usage:"
    echo "  bash cybra_evo.sh auto"
    echo "  bash cybra_evo.sh create <committee_id> <name> <mission> [task_type1,task_type2]"
    echo "  bash cybra_evo.sh task"
    echo "  bash cybra_evo.sh status|list|report|feed|proof|audit|laws"
    ;;
esac
