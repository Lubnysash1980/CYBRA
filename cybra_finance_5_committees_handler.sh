#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

python3 cybra_finance_5_committees.py cycle >/dev/null 2>&1 || true
