#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail
D="$HOME/CYBRA/modules/module_122_contract_validator"
G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; B=$'\e[36m'; DIM=$'\e[2m'; N=$'\e[0m'

while :; do
  clear
  echo "${B}═══ Contract Validator ═══${N}"
  echo
  echo "  ${G}1${N}) Перевірити контракт за CID"
  echo "  ${G}2${N}) Перевірити всі активні"
  echo "  ${G}3${N}) Перевірити останній підписаний"
  echo "  ${G}4${N}) Показати останній звіт"
  echo
  echo "  ${G}0${N}) Назад"
  echo
  read -rp "  Вибір: " c
  case "$c" in
    1)
      read -rp "  CID: " cid
      [ -n "$cid" ] && python3 "$D/validator.py" "$cid"
      echo; read -rp "Enter…" _
      ;;
    2)
      for cid in $(python3 "$HOME/CYBRA/modules/module_121_parlament/dossier.py" list 2>/dev/null); do
        echo "── $cid ──"
        python3 "$D/validator.py" "$cid" 2>&1 | grep -E "Вердикт|Score"
      done
      read -rp "Enter…" _
      ;;
    3)
      LAST=$(ls -t "$HOME/CYBRA/modules/module_19_contract_tui_menu/evidence/"*_buyer.sig 2>/dev/null | head -1 | xargs -r basename | sed 's/_buyer.sig//')
      [ -n "$LAST" ] && python3 "$D/validator.py" "$LAST"
      read -rp "Enter…" _
      ;;
    4)
      ls -t "$D/data"/*_validation.json 2>/dev/null | head -1 | xargs -r python3 -c "
import sys, json
v = json.load(open(sys.argv[1]))
G='\033[32m'; R='\033[31m'; B='\033[36m'; N='\033[0m'
col = G if v['verdict']=='OK' else R
print(f\"  CID:     {v['cid']}\")
print(f\"  Вердикт: {col}{v['verdict']}{N}\")
print(f\"  Score:   {v['score']}/100\")
for r in v['results']:
    m = '✓' if r['ok'] else ('✗' if r['level']=='critical' else '!')
    print(f\"  [{m}] {r['name']}\")
" 
      read -rp "Enter…" _
      ;;
    0) return ;;
  esac
done
