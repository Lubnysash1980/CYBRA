#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

python3 cybra_closed_sha_pool_bridge.py cycle
bash cybra_kibra_stats.sh report >/dev/null 2>&1 || true
