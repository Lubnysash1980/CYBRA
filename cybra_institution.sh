#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

case "${1:-check}" in
  check)
    python3 cybra_institution_audit.py check
    ;;
  repair)
    python3 cybra_institution_audit.py repair
    ;;
  task)
    cybra parliament '{"topic":"CYBRA Parliament Institution Audit","type":"institution_audit_task","priority":"high","payload":{"mode":"check_departments_committees_protection"}}'
    ;;
  status)
    redis-cli ping
    echo "INSTITUTION_AUDIT: $(redis-cli LLEN cybra:institution:audit)"
    echo "PARLIAMENT_RESULTS: $(redis-cli LLEN cybra:parliament:results)"
    echo "PARLIAMENT_QUEUE: $(redis-cli LLEN cybra:parliament:queue)"
    echo "MAPPING: $(redis-cli HLEN cybra:executor:mapping)"
    test -f posts/institution_audit_report.md && echo "REPORT: exists" || echo "REPORT: missing"
    ;;
  report)
    cat posts/institution_audit_report.md
    ;;
  feed)
    cat feeds/institution_audit_report.json
    ;;
  proof)
    cat proofs/institution_audit_report.sha256
    ;;
  *)
    echo "Usage: bash cybra_institution.sh check|repair|task|status|report|feed|proof"
    ;;
esac
