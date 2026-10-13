#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
H="$HOME/CYBRA"; P="$H/public/sign"
E="$H/modules/module_19_contract_tui_menu/evidence"
PORT="${CYBRA_PORT:-8765}"
BUYER="0x29fA26FC5768Fe1E62160E021Fd3f88d92257A1F"
G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; B=$'\e[36m'; N=$'\e[0m'
ok(){ echo "  ${G}✓${N} $*"; }; warn(){ echo "  ${Y}!${N} $*"; }; err(){ echo "  ${R}✗${N} $*" >&2; }
SPID=""; TPID=""
cleanup(){ kill "$SPID" "$TPID" 2>/dev/null||true; pkill -f "cloudflared.*$PORT" 2>/dev/null||true; }
trap cleanup EXIT INT TERM
mkdir -p "$P" "$E"

TS=$(date +%Y%m%d%H%M%S); RND=$(head -c4 /dev/urandom|od -An -tx1|tr -d ' \n')
CID="C-INV-${TS}-${RND}"
ok "CID: $CID"

# ─── HTML ───
cat > "$P/index.html" <<HTML
<!doctype html><meta charset=utf-8><meta name=viewport content="width=device-width,initial-scale=1">
<title>CYBRA $CID</title>
<style>body{font-family:system-ui;background:#0b0f14;color:#eee;max-width:520px;margin:0 auto;padding:20px}
button{width:100%;padding:14px;margin:8px 0;border:0;border-radius:10px;font-size:16px;font-weight:600}
#c1{background:#f6851b;color:#fff}#c2{background:#2ea043;color:#fff}
button:disabled{opacity:.5}.s{margin-top:14px;padding:10px;background:#161b22;border-radius:8px;font-size:14px;white-space:pre-wrap}</style>
<h2>CYBRA · Підпис</h2><div style="font-family:monospace;font-size:12px">$CID</div>
<button id=c1>1️⃣ Підключити MetaMask</button><button id=c2 disabled>2️⃣ Підписати</button>
<div class=s id=st>не підключено</div>
<script>let a=null;const CID="$CID",B="$BUYER",st=document.getElementById('st');
const S=(m)=>st.textContent=m;
c1.onclick=async()=>{if(!window.ethereum)return S('нема MetaMask');
try{a=(await window.ethereum.request({method:'eth_requestAccounts'}))[0];S('OK: '+a);c2.disabled=false}catch(e){S('err '+e.message)}};
c2.onclick=async()=>{if(!a)return S('спочатку підключіть');
const m='CYBRA Contract\nCID: '+CID+'\nBuyer: '+a+'\nTime: '+new Date().toISOString();
try{S('чекаю підпис...');const s=await window.ethereum.request({method:'personal_sign',params:[m,a]});
S('надсилаю...');const r=await fetch('/sign',{method:'POST',headers:{'Content-Type':'application/json'},
body:JSON.stringify({cid:CID,address:a,message:m,signature:s})});
S(r.ok?'✅ Готово':'помилка '+r.status);if(r.ok)c2.disabled=true}catch(e){S('err '+(e.message||e))}};</script>
HTML

# ─── server.py ───
cat > "$P/server.py" <<'PY'
import http.server,json,os,socketserver,sys
from urllib.parse import urlparse
R=os.path.dirname(os.path.abspath(__file__));E=sys.argv[1];P=int(sys.argv[2])
class H(http.server.SimpleHTTPRequestHandler):
    def __init__(s,*a,**k):super().__init__(*a,directory=R,**k)
    def log_message(s,f,*a):sys.stderr.write("[srv] "+f%a+"\n")
    def do_POST(s):
        if urlparse(s.path).path!="/sign":s.send_error(404);return
        n=int(s.headers.get("Content-Length",0))
        try:d=json.loads(s.rfile.read(n))
        except Exception as e:s.send_error(400,str(e));return
        o=os.path.join(E,f"{d.get('cid','X')}_buyer.sig")
        open(o,"w").write(json.dumps(d,indent=2))
        open(o+".msg","w").write(d.get("message",""))
        s.send_response(200);s.send_header("Content-Type","application/json");s.end_headers()
        s.wfile.write(b'{"ok":true}')
socketserver.TCPServer.allow_reuse_address=True
with socketserver.TCPServer(("127.0.0.1",P),H) as x:x.serve_forever()
PY

# ─── Сервер ───
python3 "$P/server.py" "$E" "$PORT" >"$P/server.log" 2>&1 & SPID=$!
sleep 1
kill -0 $SPID 2>/dev/null || { err "сервер впав"; cat "$P/server.log"; exit 1; }
ok "сервер PID $SPID :$PORT"

# ─── УНІВЕРСАЛЬНИЙ ЗАПУСК ТУНЕЛЮ ───
# Пробуємо кілька стратегій по черзі. Перша що дасть URL — перемагає.

fix_dns() {
  warn "фіксую DNS"
  echo "nameserver 1.1.1.1" > "$PREFIX/etc/resolv.conf" 2>/dev/null || true
  echo "nameserver 8.8.8.8" >> "$PREFIX/etc/resolv.conf" 2>/dev/null || true
}

try_cloudflared() {
  local name="$1"; shift
  local tlog="$P/tunnel_${name}.log"
  : > "$tlog"
  warn "спроба: cloudflared [$name]"
  cloudflared tunnel --url "http://127.0.0.1:$PORT" "$@" --no-autoupdate >"$tlog" 2>&1 &
  local pid=$!
  local url=""
  for i in $(seq 1 20); do
    url=$(grep -oE 'https://[a-z0-9][a-z0-9-]+\.trycloudflare\.com' "$tlog" 2>/dev/null \
          | grep -v '^https://api\.' | sort -u | head -1 || true)
    [ -n "$url" ] && break
    kill -0 $pid 2>/dev/null || break
    sleep 1
  done
  if [ -n "$url" ]; then
    TPID=$pid; TUNNEL_LOG="$tlog"; PUBLIC_URL="$url"
    ok "URL: $url"
    return 0
  fi
  kill $pid 2>/dev/null || true
  tail -3 "$tlog" | sed 's/^/     /'
  return 1
}

try_ngrok() {
  command -v ngrok >/dev/null || return 1
  warn "спроба: ngrok"
  local tlog="$P/tunnel_ngrok.log"
  : > "$tlog"
  ngrok http "$PORT" --log=stdout >"$tlog" 2>&1 &
  local pid=$!
  local url=""
  for i in $(seq 1 20); do
    url=$(grep -oE 'https://[a-z0-9-]+\.ngrok(-free)?\.app' "$tlog" 2>/dev/null | head -1 || true)
    [ -n "$url" ] && break
    kill -0 $pid 2>/dev/null || break
    sleep 1
  done
  if [ -n "$url" ]; then
    TPID=$pid; TUNNEL_LOG="$tlog"; PUBLIC_URL="$url"
    ok "URL: $url"
    return 0
  fi
  kill $pid 2>/dev/null || true
  return 1
}

try_ssh_tunnel() {
  command -v ssh >/dev/null || return 1
  local host="$1"
  warn "спроба: ssh $host"
  local tlog="$P/tunnel_ssh.log"
  : > "$tlog"
  ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=30 \
      -R 80:127.0.0.1:$PORT "$host" >"$tlog" 2>&1 &
  local pid=$!
  local url=""
  for i in $(seq 1 25); do
    url=$(grep -oE 'https://[a-z0-9-]+\.(lhr\.life|serveo\.net)' "$tlog" 2>/dev/null | grep -v console | head -1 || true)
    [ -n "$url" ] && break
    kill -0 $pid 2>/dev/null || break
    sleep 1
  done
  if [ -n "$url" ]; then
    TPID=$pid; TUNNEL_LOG="$tlog"; PUBLIC_URL="$url"
    ok "URL: $url"
    return 0
  fi
  kill $pid 2>/dev/null || true
  return 1
}

# ─── Ланцюг спроб ───
TPID=""; TUNNEL_LOG=""; PUBLIC_URL=""

try_cloudflared "default" || \
try_cloudflared "http2" --protocol http2 || \
try_cloudflared "http2-ipv4" --protocol http2 --edge-ip-version 4 || \
{ fix_dns; try_cloudflared "after-dns" --protocol http2 --edge-ip-version 4; } || \
try_ngrok || \
try_ssh_tunnel "nokey@localhost.run" || \
try_ssh_tunnel "nokey@serveo.net" || \
{ err "усі спроби провалились. Дивись $P/tunnel_*.log"; exit 1; }

# ─── Чекаємо підпис ───
echo
echo "════════════════════════════════════════════"
echo "  CID: $CID"
echo "  URL: ${B}${PUBLIC_URL}${N}"
echo "════════════════════════════════════════════"
echo "  MetaMask → ☰ → Browser → встав URL → підпиши"
echo "  (очікую...)"
SIG="$E/${CID}_buyer.sig"
while [ ! -f "$SIG" ]; do
  [ -n "$TPID" ] && ! kill -0 $TPID 2>/dev/null && { echo; err "тунель впав"; exit 1; }
  kill -0 $SPID 2>/dev/null || { echo; err "сервер впав"; exit 1; }
  printf '.'; sleep 1
done
echo
ok "ПІДПИС: $SIG"
