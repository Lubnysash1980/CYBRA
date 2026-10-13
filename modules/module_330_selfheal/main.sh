#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_330_selfheal"
B=$'\e[36m'; G=$'\e[32m'; N=$'\e[0m'
while :; do
  clear; echo "${B}═══ Self-Heal Engine ═══${N}"
  python3 "$D/engine.py" status
  echo "  1) ${G}Цикл зараз${N}   2) Лог   3) JSON   0) Назад"
  read -rp "  Вибір: " c
  case "$c" in
    1) python3 "$D/engine.py" cycle; read -rp "Enter…" _ ;;
    2) python3 "$D/engine.py" log 30; read -rp "Enter…" _ ;;
    3) python3 "$D/engine.py" json; read -rp "Enter…" _ ;;
    0) return ;;
  esac
done
