#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA"

CMD="${1:-menu}"

case "$CMD" in
  menu|status|finance|recommendations|report)
    python3 cybra_menubar.py "$CMD"
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
    shift
    python3 cybra_menubar.py cycle "${1:-safe}"
    ;;
  recovery)
    shift
    bash cybra_menu_recovery_bridge.sh "${1:-status}" "$@"
    ;;
  evolution)
    shift
    bash cybra_evolution.sh "${1:-status}" "$@"
    ;;
  proof)
    cat proofs/cybra_menubar.sha256
    ;;
  help|--help|-h)
    echo "Usage:"
    echo "  cybra-menu"
    echo "  cybra-menu status"
    echo "  cybra-menu finance"
    echo "  cybra-menu recommendations"
    echo "  cybra-menu task 'text'"
    echo "  cybra-menu post 'title' 'body'"
    echo "  cybra-menu committee 'name' 'mission'"
    echo "  cybra-menu withdraw AMOUNT DESTINATION NETWORK MEMO"
    echo "  cybra-menu cycle safe"
    echo "  cybra-menu report"
    ;;
  *)
    echo "Unknown command: $CMD"
    echo "Run: cybra-menu help"
    ;;
esac
