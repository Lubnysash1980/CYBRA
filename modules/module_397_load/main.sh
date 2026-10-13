#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_397_load"
B=$'\e[36m'; N=$'\e[0m'
while :; do
  clear; echo "${B}═══ Load Controller ═══${N}"
  python3 "$D/load.py" status
  echo
  echo "  1) Цикл   2) Daemon status   0) Назад"
  read -rp "  Вибір: " c
  case "$c" in
    1) python3 "$D/load.py" cycle | head -20; read -rp "Enter…" _ ;;
    2) pgrep -f "module_397_load/load.py daemon" >/dev/null && echo "● online" || echo "○ offline"; read -rp "Enter…" _ ;;
    0) return ;;
  esac
done
