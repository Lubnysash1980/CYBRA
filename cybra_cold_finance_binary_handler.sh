#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

bin/cybra-finance-bin report >/dev/null 2>&1 || true
bin/cybra-finance-bin task >/dev/null 2>&1 || true
bash cybra_closed_sha_bridge.sh cycle >/dev/null 2>&1 || true
