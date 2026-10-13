#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_411_tiers"
B=$'\e[36m'; G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
while :; do
  clear; echo "${B}═══ Tiered Controllers ═══${N}"
  echo
  python3 "$D/tiers.py" run 3  # L1-L3 швидко
  echo
  echo "  1) L1-L3 (швидко)   2) L1-L5"
  echo "  3) ${Y}L1-L7 у фоні${N} (через PM)"
  echo "  4) Лог tiers"
  echo "  0) Назад"
  read -rp "  Вибір: " c
  case "$c" in
    1) python3 "$D/tiers.py" run 3; read -rp "Enter…" _ ;;
    2) python3 "$D/tiers.py" run 5; read -rp "Enter…" _ ;;
    3) cybra-heavy tiers; read -rp "Enter…" _ ;;
    4) tail -30 "$HOME/CYBRA/logs/tiers_full.log" 2>/dev/null || echo "немає логу"; read -rp "Enter…" _ ;;
    0) return ;;
  esac
done
