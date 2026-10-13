#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_410_runtime_ctrl"
B=$'\e[36m'; G=$'\e[32m'; N=$'\e[0m'
while :; do
  clear
  python3 "$D/controllers.py" check
  echo "  1) Повторити  2) JSON  0) Назад"
  read -rp "  Вибір: " c
  case "$c" in
    1) continue ;;
    2) python3 "$D/controllers.py" json; read -rp "Enter…" _ ;;
    0) return ;;
  esac
done
