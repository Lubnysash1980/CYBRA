#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

case "${1:-status}" in
  status|scan|submit-ai|report|cycle)
    python3 hash_license_guard.py "$@"
    ;;
  add)
    shift
    python3 hash_license_guard.py add "$@"
    ;;
  audit)
    python3 hash_license_guard.py audit "$2"
    ;;
  freeze)
    python3 hash_license_guard.py freeze "$2"
    ;;
  proof)
    cat proofs/hash_license_guard.sha256
    ;;
  *)
    echo "Usage:"
    echo "  bash hash_license_guard.sh status"
    echo "  bash hash_license_guard.sh add 'Subject name' 'Evidence text'"
    echo "  bash hash_license_guard.sh audit SUBJECT_ID"
    echo "  bash hash_license_guard.sh freeze SUBJECT_ID"
    echo "  bash hash_license_guard.sh scan"
    echo "  bash hash_license_guard.sh submit-ai"
    echo "  bash hash_license_guard.sh report"
    echo "  bash hash_license_guard.sh cycle"
    ;;
esac
