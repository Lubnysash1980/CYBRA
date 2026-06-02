#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

python3 cybra_kibra_block_ai_support.py report
bash cybra_kibra_chain.sh verify >/dev/null 2>&1 || true
bash cybra_kibra_bridge.sh submit-ai >/dev/null 2>&1 || true
