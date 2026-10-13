#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_142_invoice_pdf"
E="$HOME/CYBRA/modules/module_19_contract_tui_menu/evidence"
B=$'\e[36m'; G=$'\e[32m'; N=$'\e[0m'
while :; do
  clear; echo "${B}═══ Invoice PDF Export ═══${N}"; echo
  echo "  1) Останній INVOICE → HTML/PDF"
  echo "  2) За CID"
  echo "  3) Список згенерованих"
  echo "  0) Назад"; echo
  read -rp "  Вибір: " c
  case "$c" in
    1) cid=$(ls -t "$E"/*.json 2>/dev/null | head -1 | xargs -r basename | sed 's/\.json//')
       [ -n "$cid" ] && python3 "$D/gen.py" "$cid"; read -rp "Enter…" _ ;;
    2) read -rp "  CID: " cid; python3 "$D/gen.py" "$cid"; read -rp "Enter…" _ ;;
    3) ls -1t "$D/data"/invoice_*.html 2>/dev/null | head -10 | sed 's/^/  /'; read -rp "Enter…" _ ;;
    0) return ;;
  esac
done
