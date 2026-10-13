#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_101_hash_eco"
B=$'\e[36m'; N=$'\e[0m'
while :; do
  clear; echo "${B}═══ Hash Ecosystem ═══${N}"
  python3 "$D/eco.py" show
  echo "  1) JSON   0) Назад"
  read -rp "  Вибір: " c
  case "$c" in
    1) python3 "$D/eco.py" json; read -rp "Enter…" _ ;;
    0) return ;;
  esac
done
