#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

python3 cybra_kibra_price_sell_repair.py submit-ai
bash cybra_kibra_chain.sh verify >/dev/null 2>&1 || true
bash cybra_kibra_bridge.sh submit-ai >/dev/null 2>&1 || true
