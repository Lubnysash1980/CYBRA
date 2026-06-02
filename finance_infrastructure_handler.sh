#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

python3 cybra_finance_infrastructure.py report

bash cybra_finance.sh report >/dev/null 2>&1 || true
bash cybra_monetization.sh report >/dev/null 2>&1 || true
bash cybra_hash_test.sh run >/dev/null 2>&1 || true
bash cybra_institution.sh check >/dev/null 2>&1 || true
