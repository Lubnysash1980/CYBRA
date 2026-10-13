#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_149_analytics"
B=$'\e[36m'; N=$'\e[0m'
while :; do
  clear
  python3 "$D/adv.py" show
  echo "  1) Оновити  2) Експорт CSV  0) Назад"
  read -rp "  Вибір: " c
  case "$c" in
    1) continue ;;
    2) python3 "$D/adv.py" export; read -rp "Enter…" _ ;;
    0) return ;;
  esac
done
