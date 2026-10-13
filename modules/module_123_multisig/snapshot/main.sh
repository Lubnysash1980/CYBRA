#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail
H="$HOME/CYBRA"; D="$H/modules/module_123_multisig"
P="$H/public/sign"; CFG="$H/config/metamask.env"
[ -f "$CFG" ] && . "$CFG"
MY="${BUYER_ADDR:-0x29fA26FC5768Fe1E62160E021Fd3f88d92257A1F}"
PORT_MS="${MS_PORT:-8772}"
G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; B=$'\e[36m'; DIM=$'\e[2m'; N=$'\e[0m'

menu(){
  while :; do
    clear
    echo "${B}═══ Multi-Sig Flow ═══${N}"
    echo
    echo "  ${G}1${N}) Створити сесію мультипідпису"
    echo "  ${G}2${N}) Список сесій"
    echo "  ${G}3${N}) Показати сесію"
    echo "  ${G}4${N}) Зібрати підписи через MetaMask (браузер)"
    echo "  ${G}5${N}) Завершити → .sig"
    echo "  ${G}6${N}) Перевірити .sig"
    echo "  ${G}7${N}) Схеми (2-of-3, 3-of-5, ...)"
    echo
    echo "  ${G}0${N}) Назад"
    echo
    read -rp "  Вибір: " c
    case "$c" in
      1)
        read -rp "  CID: " cid
        read -rp "  Сума BNB [0]: " amt; amt="${amt:-0}"
        SCHEME=$(python3 -c "import sys;sys.path.insert(0,'$D');import multisig;print(multisig.pick_scheme(float('$amt')))")
        echo "  ${D}Автосхема за сумою: $SCHEME${N}"
        read -rp "  Схема [$SCHEME]: " s; s="${s:-$SCHEME}"
        python3 "$D/multisig.py" start "$cid" "$s"
        read -rp "Enter…" _
        ;;
      2) python3 "$D/multisig.py" list; read -rp "Enter…" _ ;;
      3) read -rp "  SID: " sid; python3 "$D/multisig.py" show "$sid"; read -rp "Enter…" _ ;;
      4)
        read -rp "  SID: " sid
        # запуск сервера для збору підписів
        kill $(cat "$H/run/ms.pid" 2>/dev/null) 2>/dev/null
        python3 "$D/server.py" "$PORT_MS" "$sid" >"$P/ms_server.log" 2>&1 &
        echo $! > "$H/run/ms.pid"
        sleep 1
        : > "$P/tunnel_ms.log"
        cloudflared tunnel --url "http://127.0.0.1:$PORT_MS" --protocol http2 \
          --no-autoupdate >"$P/tunnel_ms.log" 2>&1 &
        TPID=$!
        URL=""
        for i in $(seq 1 25); do
          URL=$(grep -oE 'https://[a-z0-9][a-z0-9-]+\.trycloudflare\.com' "$P/tunnel_ms.log" 2>/dev/null|grep -v '^https://api\.'|head -1||true)
          [ -n "$URL" ] && break; sleep 1
        done
        [ -z "$URL" ] && URL="http://127.0.0.1:$PORT_MS"
        DL="https://metamask.app.link/dapp/${URL#https://}"
        echo
        echo "  URL:  $URL"
        echo "  Deep: $DL"
        if command -v termux-open-url >/dev/null; then
          termux-open-url "$DL" && echo "  ${G}✓${N} MetaMask відкрито"
        fi
        echo
        echo "  ${D}очікую підписи (Ctrl+C для виходу)${N}"
        while kill -0 $(cat "$H/run/ms.pid" 2>/dev/null) 2>/dev/null; do
          sleep 5
          CNT=$(python3 -c "import sys;sys.path.insert(0,'$D');import multisig;s=multisig.get_session('$sid');print(f\"{len(s['signatures'])}/{s['threshold']}\" if s else '?')")
          printf "\r  зібрано: $CNT"
          python3 -c "import sys;sys.path.insert(0,'$D');import multisig;s=multisig.get_session('$sid');sys.exit(0 if s and s['status']=='complete' else 1)" && break
        done
        echo
        kill $TPID 2>/dev/null; pkill -f "cloudflared.*$PORT_MS" 2>/dev/null
        kill $(cat "$H/run/ms.pid" 2>/dev/null) 2>/dev/null
        read -rp "Enter…" _
        ;;
      5) read -rp "  SID: " sid; python3 "$D/multisig.py" finalize "$sid"; read -rp "Enter…" _ ;;
      6) read -rp "  шлях: " p; python3 "$D/multisig.py" verify "$p"; read -rp "Enter…" _ ;;
      7) python3 "$D/multisig.py" schemes; read -rp "Enter…" _ ;;
      0) return ;;
    esac
  done
}
menu
