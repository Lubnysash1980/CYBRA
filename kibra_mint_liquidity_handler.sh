#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

python3 cybra_kibra_mint_liquidity.py submit-ai

bash cybra_ai_block_enforcer.sh enforce 3 >/dev/null 2>&1 || true
bash cybra_mint_manage.sh report >/dev/null 2>&1 || true
bash cybra_kibra_stats.sh report >/dev/null 2>&1 || true
