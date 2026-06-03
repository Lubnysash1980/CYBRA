#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

case "${1:-status}" in
  init)
    python3 kybra_valid_gateway.py init
    ;;
  status|balance)
    python3 kybra_valid_gateway.py status
    ;;
  report)
    python3 kybra_valid_gateway.py report
    cat posts/kybra_valid_wallet_gateway_report.md
    ;;
  requisites)
    cat posts/kybra_valid_web_payment_requisites.txt
    ;;
  set-destination)
    python3 kybra_valid_gateway.py set-destination "$2" "${3:-KYBRA_INTERNAL}" "${4:-}"
    ;;
  propose)
    python3 kybra_valid_gateway.py propose "$2" "$3" "${4:-KYBRA_INTERNAL}" "${5:-}"
    ;;
  approve-internal)
    python3 kybra_valid_gateway.py approve-internal "$2"
    ;;
  proposals)
    ls -lah data/kybra_valid/proposals 2>/dev/null || true
    ;;
  ledger)
    cat data/kybra_valid/ledger.json
    ;;
  wallet)
    cat data/kybra_valid/wallet.json
    ;;
  destination)
    cat data/kybra_valid/destination_wallet.json
    ;;
  proof)
    cat proofs/kybra_valid_wallet_gateway.sha256
    ;;
  *)
    echo "Usage:"
    echo "  bash kybra_valid.sh status"
    echo "  bash kybra_valid.sh report"
    echo "  bash kybra_valid.sh requisites"
    echo "  bash kybra_valid.sh set-destination ADDRESS NETWORK LABEL"
    echo "  bash kybra_valid.sh propose AMOUNT ADDRESS NETWORK MEMO"
    echo "  bash kybra_valid.sh approve-internal PROPOSAL_ID"
    echo "  bash kybra_valid.sh proposals"
    echo "  bash kybra_valid.sh ledger"
    ;;
esac
