#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

python3 cybra_kibra_mint_promotion.py submit-ai

bash cybra_ai_blocks.sh cycle >/dev/null 2>&1 || true
bash cybra_kibra_block_ai.sh submit >/dev/null 2>&1 || true
bash cybra_kibra_difficulty.sh submit-ai >/dev/null 2>&1 || true
bash cybra_kibra_bridge.sh submit-ai >/dev/null 2>&1 || true
