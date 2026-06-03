#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

bash cybra_payment_autoblock.sh >/dev/null 2>&1 || true
bash cybra_closed_sha_bridge.sh cycle >/dev/null 2>&1 || true
