#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

CMD="${1:-status}"

case "$CMD" in
  collect)
    python3 cybra_revision_organ.py
    ;;
  task)
    cybra parliament '{"topic":"CYBRA Parliament Revision Organ","type":"revision_organ_task","priority":"high","payload":{"mode":"task_and_work_revision"}}'
    ;;
  status)
    redis-cli ping
    echo "RESULTS: $(redis-cli LLEN cybra:results)"
    echo "AUDIT: $(redis-cli LLEN cybra:audit)"
    echo "REVISION_AUDIT: $(redis-cli LLEN cybra:revision:audit)"
    echo "PARLIAMENT_QUEUE: $(redis-cli LLEN cybra:parliament:queue)"
    echo "REVIEW_HOLD: $(redis-cli LLEN cybra:review:hold)"
    test -f posts/revision_organ_report.md && echo "REPORT: exists" || echo "REPORT: missing"
    ;;
  report)
    cat posts/revision_organ_report.md
    ;;
  feed)
    cat feeds/revision_organ_report.json
    ;;
  proof)
    cat proofs/revision_organ.sha256
    ;;
  audit)
    redis-cli LRANGE cybra:revision:audit 0 20
    ;;
  organ)
    cat parliament/revision/cybra_revision_organ.json
    ;;
  *)
    echo "Usage: bash cybra_revision.sh collect|task|status|report|feed|proof|audit|organ"
    ;;
esac
