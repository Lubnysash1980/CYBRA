#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

CMD="${1:-status}"

case "$CMD" in
  generate)
    python3 cybra_biometric_succession_guard.py
    ;;
  task)
    cybra parliament '{"topic":"CYBRA Biometric Succession Guard","type":"biometric_succession_task","priority":"critical","payload":{"mode":"notary_legal_successor_guard"}}'
    ;;
  status)
    redis-cli ping
    echo "SUCCESSION_AUDIT: $(redis-cli LLEN cybra:succession:audit)"
    echo "PARLIAMENT_QUEUE: $(redis-cli LLEN cybra:parliament:queue)"
    echo "PARLIAMENT_RESULTS: $(redis-cli LLEN cybra:parliament:results)"
    test -f posts/biometric_succession_guard.md && echo "REPORT: exists" || echo "REPORT: missing"
    ;;
  report)
    cat posts/biometric_succession_guard.md
    ;;
  feed)
    cat feeds/biometric_succession_guard.json
    ;;
  proof)
    cat proofs/biometric_succession_guard.sha256
    ;;
  audit)
    redis-cli LRANGE cybra:succession:audit 0 20
    ;;
  *)
    echo "Usage: bash cybra_succession.sh generate|task|status|report|feed|proof|audit"
    ;;
esac
