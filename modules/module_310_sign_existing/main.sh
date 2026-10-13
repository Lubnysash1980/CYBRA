#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail
H="$HOME/CYBRA"; M="$H/modules"
D="$M/module_310_sign_existing"
E="$M/module_19_contract_tui_menu/evidence"
P="$H/public/sign"
PORT=8795
G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; B=$'\e[36m'; DIM=$'\e[2m'; N=$'\e[0m'

# Знайти invoice контракти
mapfile -t CIDS < <(grep -l '"type": "invoice_payment"' "$E"/*.json 2>/dev/null | xargs -r -n1 basename | sed 's/\.json$//')

if [ ${#CIDS[@]} -eq 0 ]; then
  echo
  echo "  ${Y}немає invoice_payment контрактів${N}"
  echo "  Створи: cybra → 111 → 1"
  read -rp "  Enter…" _
  exit 0
fi

clear
echo "${B}═══ Підпис існуючого контракту ═══${N}"
echo
i=0
for cid in "${CIDS[@]}"; do
  i=$((i+1))
  no=$(python3 -c "import json;d=json.load(open('$E/$cid.json'));print((d.get('invoice') or {}).get('no','?'))" 2>/dev/null)
  amt=$(python3 -c "import json;d=json.load(open('$E/$cid.json'));print(d.get('total_uah',0))" 2>/dev/null)
  printf "  ${G}%2d${N}) %-38s  №%-15s %s UAH\n" "$i" "${cid:0:36}" "$no" "$amt"
done
echo
echo "  ${G}0${N}) Назад"
read -rp "  Вибір: " c
[ "$c" = "0" ] && exit 0
[[ ! "$c" =~ ^[0-9]+$ ]] || [ "$c" -lt 1 ] || [ "$c" -gt "${#CIDS[@]}" ] && { echo "невірно"; exit 1; }
CID="${CIDS[$((c-1))]}"

# Піднімаємо сервер
kill $(cat "$H/run/sign_existing.pid" 2>/dev/null) 2>/dev/null
python3 "$D/sign.py" "$PORT" >"$P/sign_existing.log" 2>&1 &
echo $! > "$H/run/sign_existing.pid"
sleep 1

# Тунель
: > "$P/tunnel_sign_existing.log"
cloudflared tunnel --url "http://127.0.0.1:$PORT" --protocol http2 --no-autoupdate \
  >"$P/tunnel_sign_existing.log" 2>&1 &
TUNNEL_PID=$!

URL=""
for i in $(seq 1 25); do
  URL=$(grep -oE 'https://[a-z0-9][a-z0-9-]+\.trycloudflare\.com' "$P/tunnel_sign_existing.log" 2>/dev/null|grep -v '^https://api\.'|head -1||true)
  [ -n "$URL" ] && break; sleep 1
done

if [ -z "$URL" ]; then
  warn "тунель не піднявся — використовую localhost"
  URL="http://127.0.0.1:$PORT"
fi

FULL="$URL/?cid=$CID"
DL="https://metamask.app.link/dapp/${FULL#https://}"

echo
echo "${B}═══ ПІДПИС ═══${N}"
echo "  CID: $CID"
echo "  URL: $FULL"
echo "  Deep: $DL"
echo
if command -v termux-open-url >/dev/null; then
  termux-open-url "$DL" && echo "  ${G}✓${N} MetaMask відкрито"
fi
echo
echo "  ${DIM}очікую підпис (Ctrl+C для виходу)${N}"
SIG="$E/${CID}_buyer.sig"
START=$(date +%s)
while [ ! -f "$SIG" ]; do
  [ $(( $(date +%s) - START )) -gt 900 ] && { echo; echo "таймаут"; break; }
  kill -0 "$TUNNEL_PID" 2>/dev/null || { echo; echo "тунель впав"; break; }
  printf '.'; sleep 1
done
echo
kill "$TUNNEL_PID" 2>/dev/null
kill $(cat "$H/run/sign_existing.pid" 2>/dev/null) 2>/dev/null
if [ -f "$SIG" ]; then
  echo "${G}✓ ПІДПИС: $SIG${N}"
else
  echo "${R}✗ підпис не отримано${N}"
fi
read -rp "  Enter…" _
