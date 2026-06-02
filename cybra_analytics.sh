#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

case "${1:-status}" in
  collect)
    python3 cybra_analytics_committee.py
    ;;
  task)
    cybra parliament '{"topic":"CYBRA Parliament Analytics Committee","type":"analytics_committee_task","priority":"high","payload":{"mode":"full_analytics"}}'
    ;;
  status)
    redis-cli ping
    echo "RESULTS: $(redis-cli LLEN cybra:results)"
    echo "AUDIT: $(redis-cli LLEN cybra:audit)"
    echo "ANALYTICS_AUDIT: $(redis-cli LLEN cybra:analytics:audit)"
    test -f posts/analytics_committee_report.md && echo "REPORT: exists" || echo "REPORT: missing"
    ;;
  report)
    cat posts/analytics_committee_report.md
    ;;
  feed)
    cat feeds/analytics_committee_report.json
    ;;
  proof)
    cat proofs/analytics_committee.sha256
    ;;
  *)
    echo "Usage: bash cybra_analytics.sh collect|task|status|report|feed|proof"
    ;;
esac
