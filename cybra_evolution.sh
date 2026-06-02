#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

case "${1:-status}" in
  inspect)
    python3 cybra_evolution_guard.py inspect "$2"
    ;;
  submit)
    python3 cybra_evolution_guard.py submit "$2"
    ;;
  report)
    python3 cybra_evolution_guard.py report
    cat posts/evolution_guard_report.md
    ;;
  status)
    redis-cli ping
    echo "EVOLUTION_APPROVED: $(redis-cli LLEN cybra:evolution:approved)"
    echo "EVOLUTION_HOLD: $(redis-cli LLEN cybra:evolution:hold)"
    echo "EVOLUTION_REJECTED: $(redis-cli LLEN cybra:evolution:rejected)"
    echo "EVOLUTION_AUDIT: $(redis-cli LLEN cybra:evolution:audit)"
    echo "PARLIAMENT_QUEUE: $(redis-cli LLEN cybra:parliament:queue)"
    echo "PARLIAMENT_RESULTS: $(redis-cli LLEN cybra:parliament:results)"
    test -f posts/evolution_guard_status.md && echo "STATUS_REPORT: exists" || echo "STATUS_REPORT: missing"
    ;;
  *)
    echo "Usage: bash cybra_evolution.sh inspect|submit|report|status"
    ;;
esac
