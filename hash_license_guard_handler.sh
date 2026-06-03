#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

bash hash_license_guard.sh cycle >/dev/null 2>&1 || true
