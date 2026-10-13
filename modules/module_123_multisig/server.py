import http.server, json, os, socketserver, sys
from urllib.parse import urlparse, parse_qs
D = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, D)
import multisig as MS

PORT = int(sys.argv[1]); SID = sys.argv[2]

HTML = r"""<!doctype html><html lang="uk"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Multi-Sig</title><style>
body{font-family:system-ui;background:#0b0f14;color:#e6edf3;max-width:520px;margin:0 auto;padding:24px}
h1{font-size:18px;margin:0 0 8px}
.row{font-family:monospace;background:#161b22;padding:10px;border-radius:8px;font-size:12px;margin-bottom:8px;word-break:break-all}
.sig{padding:10px;border-radius:8px;background:#0d2818;color:#2ea043;font-size:13px;margin:6px 0}
.prog{height:8px;background:#21262d;border-radius:4px;overflow:hidden;margin:12px 0}
.prog-fill{height:100%;background:#2ea043;transition:width 0.3s}
button{width:100%;padding:14px;margin:8px 0;border:0;border-radius:10px;font-size:16px;font-weight:600;cursor:pointer}
#c1{background:#f6851b;color:#fff}#c2{background:#2ea043;color:#fff}
button:disabled{opacity:.5;cursor:not-allowed}
.status{margin-top:12px;padding:12px;border-radius:8px;background:#161b22;font-size:14px}
.ok{color:#2ea043}.err{color:#f85149}
</style></head><body>
<h1>CYBRA Multi-Sig</h1>
<div class="row">SID: __SID__<br>CID: __CID__<br>Схема: __SCHEME__ (поріг __THRESHOLD__)</div>
<div id="signers"></div>
<div class="prog"><div class="prog-fill" id="fill"></div></div>
<div id="count"></div>
<button id="c1" hidden>Підключити MetaMask</button>
<button id="c2" hidden disabled>Підписати</button>
<div class="status" id="st">Ініціалізація…</div>
<script>
const SID="__SID__";
let account=null;
const st=document.getElementById('st');
const signers=document.getElementById('signers');
const fill=document.getElementById('fill');
const cnt=document.getElementById('count');
const b1=document.getElementById('c1');
const b2=document.getElementById('c2');
const set=(m,c)=>{st.className='status '+(c||'');st.textContent=m;};

async function refresh(){
  const r = await fetch('/state');
  const j = await r.json();
  if (!j.ok) return;
  const s = j.session;
  signers.innerHTML = s.signatures.map(x =>
      '<div class="sig">✓ '+x.signer.slice(0,14)+'… '+
      '<span style="color:#8b949e">'+x.at+'</span></div>').join('')
      || '<div style="color:#8b949e">підписів ще немає</div>';
  const pct = s.threshold ? (s.signatures.length/s.threshold*100) : 0;
  fill.style.width = Math.min(100, pct)+'%';
  cnt.textContent = s.signatures.length + ' / ' + s.threshold +
    (s.status==='complete' ? ' ✅ завершено' : ' ⏳ збираємо');
  if (s.status==='complete') {
    set('Кворум досягнуто! Можна закривати.', 'ok');
  }
}

async function connect(){
  if (!window.ethereum) return set('MetaMask не знайдено', 'err');
  try {
    const a = await window.ethereum.request({method:'eth_requestAccounts'});
    account = a[0];
    set('Підключено: '+account, 'ok');
    b1.hidden = true; b2.hidden = false; b2.disabled = false;
  } catch(e) { set('помилка: '+(e.message||e), 'err'); }
}

async function sign(){
  if (!account) return;
  try {
    set('Формую повідомлення…');
    const r = await fetch('/prepare', {
      method:'POST', headers:{'Content-Type':'application/json'},
      body: JSON.stringify({sid: SID, signer: account})
    });
    const j = await r.json();
    if (!j.ok) return set('помилка: '+j.reason, 'err');
    set('Запит підпису…');
    const sig = await window.ethereum.request({
      method:'personal_sign', params:[j.message, account]
    });
    set('Надсилаю…');
    const r2 = await fetch('/sign', {
      method:'POST', headers:{'Content-Type':'application/json'},
      body: JSON.stringify({sid: SID, signer: account, signature: sig, message: j.message})
    });
    const j2 = await r2.json();
    if (!j2.ok) return set('помилка: '+j2.reason, 'err');
    set('✅ Ваш підпис зараховано', 'ok');
    b2.disabled = true;
    refresh();
  } catch(e) { set('помилка: '+(e.message||e), 'err'); }
}

b1.onclick = connect;
b2.onclick = sign;
b1.hidden = false;
setTimeout(refresh, 200);
setInterval(refresh, 4000);
</script></body></html>
"""

class H(http.server.SimpleHTTPRequestHandler):
    def __init__(s,*a,**k): super().__init__(*a, directory=D, **k)
    def log_message(s,f,*a): sys.stderr.write("[ms] "+f%a+"\n")
    def _send(s, code, body, ctype="application/json"):
        s.send_response(code); s.send_header("Content-Type", ctype)
        s.send_header("Content-Length", str(len(body)))
        s.end_headers(); s.wfile.write(body)

    def do_GET(s):
        if urlparse(s.path).path == "/":
            sess = MS.get_session(SID)
            if not sess: return s._send(404, b'{"ok":false}')
            html = (HTML
                .replace("__SID__", SID)
                .replace("__CID__", sess["cid"])
                .replace("__SCHEME__", sess["scheme"])
                .replace("__THRESHOLD__", str(sess["threshold"])))
            return s._send(200, html.encode(), "text/html; charset=utf-8")
        if urlparse(s.path).path == "/state":
            return s._send(200, json.dumps({"ok": True, "session": MS.get_session(SID)}).encode())
        super().do_GET()

    def do_POST(s):
        p = urlparse(s.path).path
        n = int(s.headers.get("Content-Length",0))
        try: d = json.loads(s.rfile.read(n))
        except Exception as e:
            return s._send(400, json.dumps({"ok":False,"reason":str(e)}).encode())
        if p == "/prepare":
            msg = MS.sign_message(d["sid"], d["signer"])
            if not msg: return s._send(404, b'{"ok":false}')
            return s._send(200, json.dumps({"ok": True, "message": msg}).encode())
        if p == "/sign":
            ok, why = MS.add_signature(d["sid"], d["signer"], d["signature"], d.get("message"))
            return s._send(200 if ok else 400, json.dumps({"ok":ok,"reason":why}).encode())
        s.send_error(404)

socketserver.TCPServer.allow_reuse_address = True
with socketserver.TCPServer(("127.0.0.1", PORT), H) as x:
    x.serve_forever()
