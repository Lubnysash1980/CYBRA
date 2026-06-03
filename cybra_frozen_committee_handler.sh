#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

bash cybra_frozen_committee.sh cycle >/dev/null 2>&1 || true
