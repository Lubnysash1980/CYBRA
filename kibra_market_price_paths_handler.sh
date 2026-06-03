#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

python3 cybra_kibra_market_paths.py submit-ai
bash cybra_ai_block_enforcer.sh enforce 3 >/dev/null 2>&1 || true
bash cybra_price_committee.sh report >/dev/null 2>&1 || true
bash cybra_mint_liquidity.sh report >/dev/null 2>&1 || true
bash cybra_real_market_price_gate.sh verify >/dev/null 2>&1 || true
