#!/usr/bin/env bash
set +e
cd "$HOME" || exit 1
if [ ! -d CYBRA/.git ]; then
  git clone git@github.com:Lubnysash1980/CYBRA.git CYBRA || git clone https://github.com/Lubnysash1980/CYBRA.git CYBRA
fi
cd "$HOME/CYBRA" || exit 1
git pull --rebase origin main || true
bash install_cyberbot_import_bar_menu.sh
cyberbot status
