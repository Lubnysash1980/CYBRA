#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA"

case "${1:-status}" in
  status)
    python3 cybra_recommendation_actions.py status
    ;;
  cycle)
    python3 cybra_recommendation_actions.py blocks-cycle
    ;;
  until-done)
    if [ -f cybra_closed_sha_bridge.sh ]; then
      bash cybra_closed_sha_bridge.sh cycle || true
    fi
    python3 cybra_recommendation_actions.py until-done
    ;;
  *)
    echo "Usage:"
    echo "  bash cybra_ai_blocks.sh status"
    echo "  bash cybra_ai_blocks.sh cycle"
    echo "  bash cybra_ai_blocks.sh until-done"
    ;;
esac
