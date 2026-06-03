#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA"

case "${1:-menu}" in
  menu|status|finance|recommendations|report)
    python3 cybra_menubar.py "$1"
    ;;
  task)
    shift
    python3 cybra_menubar.py task "$@"
    ;;
  post)
    shift
    python3 cybra_menubar.py post "$@"
    ;;
  committee)
    shift
    python3 cybra_menubar.py committee "$@"
    ;;
  withdraw)
    shift
    python3 cybra_menubar.py withdraw "$@"
    ;;
  cycle)
    python3 cybra_menubar.py cycle "${2:-safe}"
    ;;
  proof)
    cat proofs/cybra_menubar.sha256
    ;;
  *)
    echo "Usage:"
    echo "  bash cybra_menubar.sh menu"
    echo "  bash cybra_menubar.sh status"
    echo "  bash cybra_menubar.sh finance"
    echo "  bash cybra_menubar.sh recommendations"
    echo "  bash cybra_menubar.sh task 'text'"
    echo "  bash cybra_menubar.sh post 'title' 'body'"
    echo "  bash cybra_menubar.sh committee 'name' 'mission'"
    echo "  bash cybra_menubar.sh withdraw AMOUNT DESTINATION NETWORK MEMO"
    echo "  bash cybra_menubar.sh cycle safe"
    echo "  bash cybra_menubar.sh report"
    ;;
esac
