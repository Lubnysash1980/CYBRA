#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_341_dual_confirm"
E="$HOME/CYBRA/modules/module_19_contract_tui_menu/evidence"
B=$'\e[36m'; G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; DIM=$'\e[2m'; N=$'\e[0m'

while :; do
  clear
  echo "${B}═══ Dual Confirmation ═══${N}"
  echo

  if ! python3 "$D/engine.py" check >/dev/null 2>&1; then
    echo "  ${R}🚫 Система не 100%${N}"
    python3 "$D/engine.py" check
    read -rp "  Enter…" _; return
  fi

  echo "  ${G}✓${N} Health 100%"
  echo

  # список контрактів
  echo "  ${B}Контракти з dual-confirm:${N}"
  mapfile -t CIDS < <(ls -1 "$D/data"/*_dual.json 2>/dev/null | xargs -r -n1 basename | sed 's/_dual\.json$//')
  if [ ${#CIDS[@]} -eq 0 ]; then
    echo "    ${DIM}немає — створи з існуючого invoice${N}"
  else
    for cid in "${CIDS[@]}"; do
      python3 "$D/engine.py" status "$cid" 2>/dev/null | grep -E "^\s+\[" | head -2 | sed 's/^/  /'
      echo "  ── $cid ──"
    done
  fi
  echo

  # список invoice які ще не мають dual
  echo "  ${B}Invoice без dual-confirm:${N}"
  mapfile -t INV < <(grep -l '"type": "invoice_payment"' "$E"/*.json 2>/dev/null | xargs -r -n1 basename | sed 's/\.json$//')
  i=0
  for cid in "${INV[@]}"; do
    [ -f "$D/data/${cid}_dual.json" ] && continue
    i=$((i+1))
    no=$(python3 -c "import json;print(json.load(open('$E/$cid.json'))['invoice']['no'])" 2>/dev/null)
    amt=$(python3 -c "import json;print(json.load(open('$E/$cid.json'))['total_uah'])" 2>/dev/null)
    printf "  ${G}%2d${N}) %-36s №%-15s %s UAH\n" "$i" "${cid:0:34}" "$no" "$amt"
  done
  [ $i -eq 0 ] && echo "    ${DIM}немає${N}"
  echo

  echo "  ${G}1${N}) Створити dual-confirm для контракту"
  echo "  ${G}2${N}) Показати статус"
  echo "  ${G}3${N}) Комфі доставив (старт 3-денного вікна)"
  echo "  ${G}4${N}) Підписати отримання (MetaMask)"
  echo "  ${G}5${N}) Згенерувати URL для Комфі"
  echo "  ${G}0${N}) Назад"
  echo
  read -rp "  Вибір: " c
  case "$c" in
    1) read -rp "  CID: " cid
       python3 "$D/engine.py" create "$cid"; read -rp "Enter…" _ ;;
    2) read -rp "  CID: " cid
       python3 "$D/engine.py" status "$cid"; read -rp "Enter…" _ ;;
    3) read -rp "  CID: " cid
       python3 "$D/engine.py" delivered "$cid"; read -rp "Enter…" _ ;;
    4) read -rp "  CID: " cid
       echo "  Відкривається підпис через 108..."
       # TODO: MetaMask flow
       read -rp "Enter…" _ ;;
    5) read -rp "  CID: " cid
       read -rp "  Base URL (cloudflared): " u
       python3 - <<PY
import sys
sys.path.insert(0, "$D")
import engine
u = engine.payment_url("$cid", "$u")
print(f"\n  URL для Комфі:\n    {u}\n")
PY
       read -rp "Enter…" _ ;;
    0) return ;;
  esac
done
