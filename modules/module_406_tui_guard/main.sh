#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_406_tui_guard"
B=$'\e[36m'; G=$'\e[32m'; N=$'\e[0m'
while :; do
  clear
  python3 "$D/guard.py" check
  echo
  echo "  Daemon: $(pgrep -f 'module_406_tui_guard/guard.py daemon' >/dev/null && echo "${G}● online${N}" || echo "○ offline")"
  echo
  echo "  1) Check   2) ${G}Fix${N}   3) JSON   0) Назад"
  read -rp "  Вибір: " c
  case "$c" in
    1) python3 "$D/guard.py" check; read -rp "Enter…" _ ;;
    2) python3 "$D/guard.py" fix; read -rp "Enter…" _ ;;
    3) python3 "$D/guard.py" json | head -50; read -rp "Enter…" _ ;;
    0) return ;;
  esac
done
