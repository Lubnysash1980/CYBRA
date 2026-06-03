#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

python3 kybra_valid_gateway.py report >/dev/null 2>&1 || true
bash cybra_closed_sha_bridge.sh cycle >/dev/null 2>&1 || true
