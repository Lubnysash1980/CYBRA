#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA" || exit 1
if [ "$#" -eq 0 ]; then
  python3 cybra_it_menubar.py menu
else
  python3 cybra_it_menubar.py "$@"
fi
