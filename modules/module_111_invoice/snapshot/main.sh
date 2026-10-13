#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_111_invoice"
E="$HOME/CYBRA/modules/module_19_contract_tui_menu/evidence"
B=$'\e[36m'; G=$'\e[32m'; N=$'\e[0m'
while :; do
  clear; echo "${B}═══ INVOICE ═══${N}"; echo
  echo "  1) Створити контракт з рахунку (вставити текст)"
  echo "  2) Список invoice-контрактів"
  echo "  3) Показати контракт за CID"
  echo "  0) Назад"; echo
  read -rp "  Вибір: " c
  case "$c" in
    1)
      echo "  Вставте текст рахунку (закінчіть EOF):"
      TMP=$(mktemp)
      cat > "$TMP"
      CID=$(python3 -c "
import sys, json, secrets, time
sys.path.insert(0, '$HOME/CYBRA/modules/module_41_ai_invoice_parser')
import parse_komfi
txt = open('$TMP').read()
p = parse_komfi.parse(txt)
print(json.dumps(p))
" 2>/dev/null)
      rm -f "$TMP"
      [ -n "$CID" ] && echo "$CID" | python3 -m json.tool | head -20
      read -rp "Enter…" _ ;;
    2)
      grep -l '"type": "invoice_payment"' "$E"/*.json 2>/dev/null | while read f; do
        cid=$(basename "$f" .json)
        no=$(python3 -c "import json;print(json.load(open('$f')).get('invoice',{}).get('no','?'))" 2>/dev/null)
        amt=$(python3 -c "import json;print(json.load(open('$f')).get('total_uah',0))" 2>/dev/null)
        echo "  $cid  №$no  $amt UAH"
      done
      read -rp "Enter…" _ ;;
    3)
      read -rp "CID: " cid
      [ -f "$E/$cid.json" ] && python3 -m json.tool "$E/$cid.json" | head -40
      read -rp "Enter…" _ ;;
    0) return ;;
  esac
done
