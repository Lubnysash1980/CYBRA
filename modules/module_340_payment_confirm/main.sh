#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail
D="$HOME/CYBRA/modules/module_340_payment_confirm"
E="$HOME/CYBRA/modules/module_19_contract_tui_menu/evidence"
B=$'\e[36m'; G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; DIM=$'\e[2m'; N=$'\e[0m'

menu(){
  while :; do
    clear
    echo "${B}═══ Payment Confirmation (NBU QR) ═══${N}"
    echo
    # перевірка health
    if ! python3 "$D/engine.py" check >/dev/null 2>&1; then
      echo "  ${R}🚫 СИСТЕМА НЕ 100%${N}"
      python3 "$D/engine.py" check 2>&1
      echo
      echo "  Виправ: cybra → 330 (Self-Heal)"
      read -rp "  Enter…" _
      return
    fi
    python3 "$D/engine.py" check

    # список invoice
    echo "  ${B}Invoice контракти:${N}"
    i=0
    mapfile -t CIDS < <(grep -l '"type": "invoice_payment"' "$E"/*.json 2>/dev/null | xargs -r -n1 basename | sed 's/\.json$//')
    for cid in "${CIDS[@]}"; do
      i=$((i+1))
      no=$(python3 -c "import json;print(json.load(open('$E/$cid.json'))['invoice']['no'])" 2>/dev/null)
      amt=$(python3 -c "import json;print(json.load(open('$E/$cid.json'))['total_uah'])" 2>/dev/null)
      # чи вже генеровано?
      [ -f "$D/data/${cid}_confirm.json" ] && mark="${G}✓${N}" || mark=" "
      printf "  %s ${G}%2d${N}) %-34s  №%-15s %s UAH\n" "$mark" "$i" "${cid:0:32}" "$no" "$amt"
    done
    echo
    echo "  ${G}g${N}) Згенерувати QR для контракту"
    echo "  ${G}s${N}) Надіслати на bn@comfy.ua"
    echo "  ${G}j${N}) JSON останнього"
    echo "  ${G}0${N}) Назад"
    echo
    read -rp "  Вибір: " c

    case "$c" in
      g|G)
        read -rp "  Номер контракту зі списку: " n
        [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -ge 1 ] && [ "$n" -le "${#CIDS[@]}" ] || { echo "невірно"; sleep 1; continue; }
        cid="${CIDS[$((n-1))]}"
        clear
        python3 "$D/engine.py" generate "$cid"
        read -rp "  Enter…" _
        ;;
      s|S)
        read -rp "  CID: " cid
        P="$D/data/${cid}_confirm.json"
        [ -f "$P" ] || { echo "  спочатку згенеруй QR (g)"; sleep 2; continue; }
        # підготовка email
        python3 - <<PY
import json, sys
sys.path.insert(0, '$D')
d = json.load(open('$P'))
subject = f"Підтвердження оплати за рахунком №{d['purpose'].split('№')[1].split(' від')[0]}"
body = f"""Вітаю,

Підтверджуємо оплату за рахунком {d['purpose'].split('Оплата за ')[1] if 'Оплата за ' in d['purpose'] else d['purpose']}.

Реквізити платежу:
  Отримувач:   {d['recipient']}
  IBAN:        {d['iban']}
  ЄДРПОУ:      {d['edrpou']}
  Сума:        {d['amount_uah']:,.2f} UAH
  Призначення: {d['purpose']}

QR-код за стандартом НБУ v002:
{d['nbu_url']}

Просимо підтвердити отримання коштів та підготувати замовлення до видачі.

--
CYBRA автоматична система
"""
print("SUBJECT:", subject)
print("BODY:")
print(body)
open('/tmp/komfi_email.txt','w').write(f"To: bn@comfy.ua\nSubject: {subject}\n\n{body}")
print("─" * 60)
print("  Файл: /tmp/komfi_email.txt")
PY
        echo
        echo "  ${G}Готово.${N} Щоб відправити:"
        echo "    1) Відкрий email-клієнт"
        echo "    2) Кому: bn@comfy.ua"
        echo "    3) Тема і текст: з /tmp/komfi_email.txt"
        echo "    4) Прикріпи QR: $D/data/${cid}_nbu_qr.png"
        echo
        echo "  ${DIM}Автовідправка: cybra → 143 (Email module)${N}"
        read -rp "  Enter…" _
        ;;
      j|J)
        LATEST=$(ls -1t "$D/data"/*_confirm.json 2>/dev/null | head -1)
        [ -n "$LATEST" ] && python3 -m json.tool "$LATEST" | head -30
        read -rp "  Enter…" _
        ;;
      0) return ;;
    esac
  done
}
menu
