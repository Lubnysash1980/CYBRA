#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

python3 cybra_finance_redis_committee.py ensure
python3 cybra_finance_redis_committee.py report
bash cybra_closed_sha_bridge.sh cycle >/dev/null 2>&1 || true
