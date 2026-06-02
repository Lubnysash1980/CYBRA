#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

python3 cybra_kibra_token_chain.py init
python3 cybra_kibra_token_chain.py mine 1
python3 cybra_kibra_token_chain.py verify
python3 cybra_kibra_token_chain.py report

# Підключення суміжних органів, якщо вони вже є
bash cybra_finance.sh report >/dev/null 2>&1 || true
bash cybra_hash_test.sh run >/dev/null 2>&1 || true
bash cybra_institution.sh check >/dev/null 2>&1 || true
bash cybra_evolution.sh report >/dev/null 2>&1 || true
