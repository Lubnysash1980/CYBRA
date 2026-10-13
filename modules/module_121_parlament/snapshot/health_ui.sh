#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_121_parlament"
B=$'\e[36m'; G=$'\e[32m'; N=$'\e[0m'
while :; do
  clear
  python3 "$D/health.py" check
  echo "  1) ${G}Auto-heal${N}  2) JSON  0) Назад"
  read -rp "  Вибір: " c
  case "$c" in
    1) python3 "$D/health.py" heal; read -rp "Enter…" _ ;;
    2) python3 "$D/health.py" json; read -rp "Enter…" _ ;;
    0) return ;;
  esac
done
