#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA"

bash cybra_menubar.sh report >/dev/null 2>&1 || true
