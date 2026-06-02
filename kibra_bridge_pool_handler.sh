#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

python3 cybra_kibra_bridge_pool.py submit-ai

bash cybra_kibra_chain.sh verify >/dev/null 2>&1 || true
bash cybra_native_kibra.sh build >/dev/null 2>&1 || true
bash cybra_monetization.sh report >/dev/null 2>&1 || true
bash cybra_finance_gap.sh submit-ai >/dev/null 2>&1 || true
