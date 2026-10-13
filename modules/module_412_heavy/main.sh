#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_412_heavy"
B=$'\e[36m'; Y=$'\e[33m'; G=$'\e[32m'; N=$'\e[0m'
clear
echo "${B}═══ [412] Heavy Operations ═══${N}"
echo
if [ -f "$D/engine.py" ]; then
  python3 "$D/engine.py" 2>&1 | head -40
elif [ -f "$D/main.py" ]; then
  python3 "$D/main.py" 2>&1 | head -40
else
  echo "  ${Y}немає engine.py — модуль у розробці${N}"
  ls -la "$D" | sed 's/^/  /'
fi
echo
read -rp "Enter…" _
