#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_408_menu_tester"
B=$'\e[36m'; G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
while :; do
  clear
  echo "${B}═══ Menu Tester ═══${N}"
  echo
  python3 "$D/tester.py" test
  echo
  echo "  1) Повний список"
  echo "  2) ${G}8-Stage Autofix${N}"
  echo "  3) JSON"
  echo "  0) Назад"
  read -rp "  Вибір: " c
  case "$c" in
    1) python3 "$D/tester.py" list; read -rp "Enter…" _ ;;
    2) python3 "$D/tester.py" 8stage; read -rp "Enter…" _ ;;
    3) python3 "$D/tester.py" json | head -40; read -rp "Enter…" _ ;;
    0) return ;;
  esac
done
