#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

case "${1:-status}" in
  create)
    python3 cybra_finance_5_committees.py create
    ;;
  report)
    python3 cybra_finance_5_committees.py report
    cat posts/cybra_finance_5_committees_report.md
    ;;
  submit-ai)
    python3 cybra_finance_5_committees.py submit-ai
    ;;
  cycle)
    python3 cybra_finance_5_committees.py cycle
    ;;
  status)
    python3 cybra_finance_5_committees.py status
    ;;
  proof)
    cat proofs/cybra_finance_5_committees.sha256
    ;;
  committees)
    find parliament/departments/finance_department/cybra_cold_finance_binary_department/committees -name committee.json -maxdepth 3 -print
    ;;
  *)
    echo "Usage:"
    echo "  bash cybra_finance_committees.sh create"
    echo "  bash cybra_finance_committees.sh report"
    echo "  bash cybra_finance_committees.sh submit-ai"
    echo "  bash cybra_finance_committees.sh cycle"
    echo "  bash cybra_finance_committees.sh status"
    echo "  bash cybra_finance_committees.sh proof"
    ;;
esac
