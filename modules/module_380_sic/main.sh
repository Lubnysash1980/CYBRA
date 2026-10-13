#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_380_sic"
B=$'\e[36m'; G=$'\e[32m'; N=$'\e[0m'
while :; do
  clear; echo "${B}═══ System Integration Controller ═══${N}"
  python3 "$D/sic.py" status
  echo
  echo "  1) Integration matrix   2) Конфлікти"
  echo "  3) Orchestration — list  4) Orchestration — показати"
  echo "  5) Events (last 30)      6) Publish event"
  echo "  7) Rebuild registry"
  echo "  0) Назад"
  read -rp "  Вибір: " c
  case "$c" in
    1) python3 "$D/sic.py" matrix | head -60; read -rp "Enter…" _ ;;
    2) python3 "$D/sic.py" conflicts; read -rp "Enter…" _ ;;
    3) python3 "$D/sic.py" orchestrations; read -rp "Enter…" _ ;;
    4) read -rp "  Назва (new_contract/payment_flow/failover): " n
       python3 "$D/sic.py" orchestrate "$n"; read -rp "Enter…" _ ;;
    5) python3 "$D/sic.py" events; read -rp "Enter…" _ ;;
    6) read -rp "  Event type: " t; read -rp "  Source: " s
       python3 "$D/sic.py" publish "$t" "$s" '{}'; read -rp "Enter…" _ ;;
    7) python3 "$D/sic.py" build; read -rp "Enter…" _ ;;
    0) return ;;
  esac
done
