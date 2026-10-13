#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_125_anchor"
G=$'\e[32m'; B=$'\e[36m'; N=$'\e[0m'
while :; do
  clear; echo "${B}═══ On-chain Anchor ═══${N}"; echo
  echo "  ${G}1${N}) Підготувати anchor (TX для підпису)"
  echo "  ${G}2${N}) Підтвердити (після TX у мережі)"
  echo "  ${G}3${N}) Перевірити       ${G}4${N}) Список"
  echo; echo "  ${G}0${N}) Назад"; echo
  read -rp "  Вибір: " c
  case "$c" in
    1) read -rp "CID: " cid
       read -rp "Path до protocol (html): " f
       read -rp "From addr: " fa
       H=$(sha256sum "$f" | cut -d' ' -f1)
       python3 "$D/anchor.py" prepare "$cid" "$H" "$fa"
       read -rp "Enter…" _ ;;
    2) read -rp "CID: " cid; read -rp "TX hash: " tx
       python3 "$D/anchor.py" confirm "$cid" "$tx"; read -rp "Enter…" _ ;;
    3) read -rp "CID: " cid; python3 "$D/anchor.py" verify "$cid"; read -rp "Enter…" _ ;;
    4) python3 "$D/anchor.py" list; read -rp "Enter…" _ ;;
    0) return ;;
  esac
done
