#!/data/data/com.termux/files/usr/bin/bash
# CYBRA Bootstrap Seed — відновлює CYBRA з git або snapshot
set -uo pipefail
H="$HOME/CYBRA"
SRC="$HOME/.cybra_src"
G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; B=$'\e[36m'; N=$'\e[0m'

echo "${B}═══ CYBRA Bootstrap ═══${N}"

if [ -d "$H/modules/module_19_contract_tui_menu" ]; then
  echo "${G}✓${N} CYBRA на місці"
  exit 0
fi

echo "${Y}!${N} CYBRA відсутня — відновлюю..."

# 1. Git clone
if [ -f "$SRC/remote.txt" ]; then
  REMOTE=$(cat "$SRC/remote.txt")
  echo "  git clone $REMOTE"
  git clone "$REMOTE" "$H" 2>&1 | tail -3
  if [ -d "$H/modules" ]; then
    echo "${G}✓${N} відновлено з git"
    exit 0
  fi
fi

# 2. Останній snapshot
LATEST=$(ls -1t "$SRC/snapshots"/*.tar.gz 2>/dev/null | head -1)
if [ -n "$LATEST" ] && [ -f "$LATEST" ]; then
  echo "  розпаковую $LATEST"
  mkdir -p "$H"
  tar -xzf "$LATEST" -C "$HOME" 2>&1 | tail -3
  if [ -d "$H/modules" ]; then
    echo "${G}✓${N} відновлено з snapshot"
    exit 0
  fi
fi

echo "${R}✗${N} не вдалось відновити"
echo "  Потрібен remote: echo URL > $SRC/remote.txt"
exit 1
