#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_395_structure"
B=$'\e[36m'; G=$'\e[32m'; N=$'\e[0m'
while :; do
  clear; echo "${B}═══ Structure Guardian ═══${N}"
  python3 "$D/structure.py" verify
  echo
  echo "  1) Minimal graph   2) Rebuild   3) JSON   0) Назад"
  read -rp "  Вибір: " c
  case "$c" in
    1) python3 "$D/structure.py" minimal; read -rp "Enter…" _ ;;
    2) python3 "$D/structure.py" build; read -rp "Enter…" _ ;;
    3) python3 "$D/structure.py" json | head -40; read -rp "Enter…" _ ;;
    0) return ;;
  esac
done
