#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA"

case "${1:-report}" in
  report|status)
    python3 cybra_recommendation_actions.py promo
    ;;
  *)
    echo "Usage: bash cybra_mint_promo.sh report"
    ;;
esac
