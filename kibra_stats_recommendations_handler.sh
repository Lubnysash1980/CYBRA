#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

python3 cybra_kibra_stats_recommendations.py submit-ai

bash cybra_mint_manage.sh report >/dev/null 2>&1 || true
bash cybra_mint_audit.sh report >/dev/null 2>&1 || true
bash cybra_mint_promo.sh report >/dev/null 2>&1 || true
