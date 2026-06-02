#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

python3 cybra_kibra_mint_management.py submit-ai

bash cybra_kibra_price.sh report >/dev/null 2>&1 || true
bash cybra_mint_audit.sh submit-ai >/dev/null 2>&1 || true
bash cybra_mint_promo.sh submit-ai >/dev/null 2>&1 || true
bash cybra_ai_blocks.sh cycle >/dev/null 2>&1 || true
