#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_412_pid_security"
B=$'\e[36m'; Y=$'\e[33m'; G=$'\e[32m'; N=$'\e[0m'
clear
echo "${B}═══ [412] PID Security ═══${N}"
echo
if [ -f "$D/engine.py" ]; then
  python3 "$D/engine.py" 2>&1 | head -40
else
  echo "  ${Y}немає engine.py${N}"
  ls -la "$D" | sed 's/^/  /'
fi
echo
read -rp "Enter…" _
