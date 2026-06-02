#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

bash cybra_native_kibra.sh build >/dev/null 2>&1 || true
bash cybra_native_kibra.sh status || true
