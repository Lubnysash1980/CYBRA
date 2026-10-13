#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_396_diffrecover"
B=$'\e[36m'; G=$'\e[32m'; N=$'\e[0m'
while :; do
  clear; echo "${B}═══ Snapshot Diff Recovery ═══${N}"
  python3 "$D/recover.py" scan
  echo
  echo "  1) Fix broken   2) JSON   0) Назад"
  read -rp "  Вибір: " c
  case "$c" in
    1) python3 "$D/recover.py" fix; read -rp "Enter…" _ ;;
    2) python3 "$D/recover.py" json | head -40; read -rp "Enter…" _ ;;
    0) return ;;
  esac
done
