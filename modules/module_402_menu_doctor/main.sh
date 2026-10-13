#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_402_menu_doctor"
B=$'\e[36m'; G=$'\e[32m'; N=$'\e[0m'
while :; do
  clear
  python3 "$D/doctor.py" check
  echo
  echo "  1) Повторити перевірку  2) ${G}Fix broken${N}  3) JSON   0) Назад"
  read -rp "  Вибір: " c
  case "$c" in
    1) continue ;;
    2) python3 "$D/doctor.py" fix; read -rp "Enter…" _ ;;
    3) python3 "$D/doctor.py" cache | head -40; read -rp "Enter…" _ ;;
    0) return ;;
  esac
done
