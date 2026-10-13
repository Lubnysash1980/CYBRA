#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_137_escrow"
G=$'\e[32m'; B=$'\e[36m'; N=$'\e[0m'
while :; do
  clear; echo "${B}═══ Escrow Flow ═══${N}"; echo
  echo "  ${G}1${N}) Створити escrow   ${G}2${N}) Список"
  echo "  ${G}3${N}) Fund plan        ${G}4${N}) Позначити funded"
  echo "  ${G}5${N}) Release plan"
  echo; echo "  ${G}0${N}) Назад"; echo
  read -rp "  Вибір: " c
  case "$c" in
    1) read -rp "CID: " cid; read -rp "Buyer: " b; read -rp "Seller: " s; read -rp "Amount BNB: " a
       python3 "$D/escrow.py" create "$cid" "$b" "$s" "$a"; read -rp "Enter…" _ ;;
    2) python3 "$D/escrow.py" list; read -rp "Enter…" _ ;;
    3) read -rp "CID: " cid; python3 "$D/escrow.py" fund "$cid"; read -rp "Enter…" _ ;;
    4) read -rp "CID: " cid; read -rp "TX hash: " tx; python3 "$D/escrow.py" mark "$cid" "$tx"; read -rp "Enter…" _ ;;
    5) read -rp "CID: " cid; python3 "$D/escrow.py" release "$cid"; read -rp "Enter…" _ ;;
    0) return ;;
  esac
done
