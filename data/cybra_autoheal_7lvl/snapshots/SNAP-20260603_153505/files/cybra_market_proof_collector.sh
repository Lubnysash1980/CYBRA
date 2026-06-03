#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

case "${1:-status}" in
  status)
    python3 cybra_market_proof_collector.py status
    ;;
  collect|report)
    python3 cybra_market_proof_collector.py collect
    cat posts/kibra_market_proof_collector_report.md
    ;;
  submit-ai)
    python3 cybra_market_proof_collector.py submit-ai
    ;;
  files)
    python3 cybra_market_proof_collector.py files
    ;;
  proof)
    cat proofs/kibra_market_proof_collector.sha256
    ;;
  *)
    echo "Usage: bash cybra_market_proof_collector.sh status|collect|submit-ai|files|proof"
    ;;
esac
