#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_128_dashboard"; P="$HOME/CYBRA/public/sign"
PORT=8790; G=$'\e[32m'; R=$'\e[31m'; B=$'\e[36m'; N=$'\e[0m'
mkdir -p "$P"
case "${1:-menu}" in
  start)
    kill $(cat "$HOME/CYBRA/run/dash.pid" 2>/dev/null) 2>/dev/null
    python3 "$D/server.py" "$PORT" >"$P/dash.log" 2>&1 &
    echo $! > "$HOME/CYBRA/run/dash.pid"
    sleep 1
    : > "$P/tunnel_dash.log"
    cloudflared tunnel --url "http://127.0.0.1:$PORT" --protocol http2 --no-autoupdate >"$P/tunnel_dash.log" 2>&1 &
    echo $! > "$HOME/CYBRA/run/dash_tunnel.pid"
    URL=""
    for i in $(seq 1 25); do
      URL=$(grep -oE 'https://[a-z0-9][a-z0-9-]+\.trycloudflare\.com' "$P/tunnel_dash.log" 2>/dev/null|grep -v '^https://api\.'|head -1||true)
      [ -n "$URL" ] && break; sleep 1
    done
    echo "  ${G}✓${N} Dashboard: ${B}${URL:-http://127.0.0.1:$PORT}${N}"
    ;;
  stop)
    kill $(cat "$HOME/CYBRA/run/dash.pid" 2>/dev/null) 2>/dev/null
    kill $(cat "$HOME/CYBRA/run/dash_tunnel.pid" 2>/dev/null) 2>/dev/null
    pkill -f "cloudflared.*8790" 2>/dev/null
    echo "${G}✓${N} зупинено"
    ;;
  status)
    if kill -0 $(cat "$HOME/CYBRA/run/dash.pid" 2>/dev/null) 2>/dev/null; then
      echo "${G}● працює${N}"
    else
      echo "${R}○ зупинено${N}"
    fi
    ;;
  *)
    echo "${B}Dashboard${N}"
    echo "  1) start  2) stop  3) status"
    read -rp "  Вибір: " c
    case "$c" in 1) bash "$0" start ;; 2) bash "$0" stop ;; 3) bash "$0" status ;; esac
    read -rp "Enter…" _
    ;;
esac
