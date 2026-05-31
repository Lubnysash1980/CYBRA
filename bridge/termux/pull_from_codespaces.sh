#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"
git pull --rebase || git pull
echo "✅ Termux pulled latest CYBRA"
