#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

case "${1:-status}" in
  edit)
    nano data/cybra_payment_requisites/payer_profile.json
    ;;
  edit-car)
    nano data/cybra_payment_requisites/car_purchase/invoice_request.json
    ;;
  report)
    bash cybra_payment_autoblock.sh
    cat posts/cybra_payment_requisites_package.md
    ;;
  dealer)
    cat posts/car_dealer_invoice_request.txt
    ;;
  status)
    test -f data/cybra_payment_requisites/payer_profile.json && echo "PROFILE=exists" || echo "PROFILE=missing"
    test -f posts/cybra_payment_requisites_package.md && echo "REPORT=exists" || echo "REPORT=missing"
    echo "PAYMENT_AUDIT=$(redis-cli LLEN cybra:finance:payment_requisites:audit 2>/dev/null || echo 0)"
    echo "BLOCK_INBOX=$(redis-cli LLEN cybra:ai:tasks:block_inbox 2>/dev/null || echo 0)"
    ;;
  proof)
    cat proofs/cybra_payment_requisites_package.sha256
    ;;
  *)
    echo "Usage:"
    echo "  bash cybra_payment_requisites.sh edit"
    echo "  bash cybra_payment_requisites.sh edit-car"
    echo "  bash cybra_payment_requisites.sh report"
    echo "  bash cybra_payment_requisites.sh dealer"
    echo "  bash cybra_payment_requisites.sh status"
    ;;
esac
