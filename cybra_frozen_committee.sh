#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

case "${1:-status}" in
  status|scan|submit-ai|report|cycle)
    python3 cybra_frozen_committee.py "$@"
    ;;
  register)
    shift
    python3 cybra_frozen_committee.py register "$@"
    ;;
  case)
    shift
    python3 cybra_frozen_committee.py case "$@"
    ;;
  audit)
    python3 cybra_frozen_committee.py audit "$2"
    ;;
  freeze)
    python3 cybra_frozen_committee.py freeze "$2"
    ;;
  unfreeze)
    shift
    python3 cybra_frozen_committee.py unfreeze "$@"
    ;;
  proof)
    cat proofs/frozen_license_committee.sha256
    ;;
  *)
    echo "Usage:"
    echo "  bash cybra_frozen_committee.sh status"
    echo "  bash cybra_frozen_committee.sh register 'Hash Module' 'OWNER Hash Module license'"
    echo "  bash cybra_frozen_committee.sh case 'Hash Module' 'Subject' 'evidence text'"
    echo "  bash cybra_frozen_committee.sh audit CASE_ID"
    echo "  bash cybra_frozen_committee.sh freeze CASE_ID"
    echo "  bash cybra_frozen_committee.sh unfreeze CASE_ID 'OWNER approved'"
    echo "  bash cybra_frozen_committee.sh scan"
    echo "  bash cybra_frozen_committee.sh cycle"
    ;;
esac
