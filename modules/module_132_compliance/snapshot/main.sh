#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_132_compliance"
B=$'\e[36m'; N=$'\e[0m'
while :; do
  clear; echo "${B}═══ Compliance Check ═══${N}"; echo
  echo "  1) Перевірити CID"
  echo "  0) Назад"; echo
  read -rp "  Вибір: " c
  case "$c" in
    1) read -rp "CID: " cid; python3 "$D/compliance.py" "$cid"; read -rp "Enter…" _ ;;
    0) return ;;
  esac
done
