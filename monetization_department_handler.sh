#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

python3 cybra_monetization_department.py report

# Підключаємо суміжні органи, якщо вони є
bash cybra_finance.sh report >/dev/null 2>&1 || true
bash cybra_kibra_chain.sh verify >/dev/null 2>&1 || true
bash cybra_kibra_chain.sh report >/dev/null 2>&1 || true
bash cybra_hash_test.sh run >/dev/null 2>&1 || true
bash cybra_institution.sh check >/dev/null 2>&1 || true
bash cybra_evolution.sh report >/dev/null 2>&1 || true
