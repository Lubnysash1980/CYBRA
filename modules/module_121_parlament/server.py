import http.server, json, os, socketserver, sys, base64
from urllib.parse import urlparse, parse_qs
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import parliament as P

ROOT = os.path.dirname(os.path.abspath(__file__))
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8770

HTML = r"""<!doctype html><html lang="uk"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>CYBRA Parliament</title>
<style>
body{font-family:system-ui;background:#0b0f14;color:#e6edf3;max-width:560px;margin:0 auto;padding:24px}
h1{font-size:18px;margin:0 0 16px}
.row{font-family:monospace;background:#161b22;padding:10px;border-radius:8px;font-size:12px;margin-bottom:8px;word-break:break-all}
.pid{font-size:16px;font-weight:700;color:#58a6ff}
.title{margin:12px 0;font-size:15px}
.vote{display:flex;gap:8px}
.vote button{flex:1;padding:14px;border:0;border-radius:10px;font-size:16px;font-weight:700;cursor:pointer}
#yes{background:#2ea043;color:#fff}#no{background:#da3633;color:#fff}#abs{background:#6e7681;color:#fff}
button:disabled{opacity:.5;cursor:not-allowed}
.status{margin-top:16px;padding:12px;border-radius:8px;background:#161b22;font-size:14px;white-space:pre-wrap}
.ok{color:#2ea043}.err{color:#f85149}
.tally{font-family:monospace;font-size:12px;background:#0d1117;padding:10px;border-radius:8px;margin:10px 0;white-space:pre}
</style></head><body>
<h1>CYBRA Parliament · голосування</h1>
<div id="hdr"></div>
<div class="tally" id="tally"></div>
<div class="vote">
  <button id="yes" disabled>✅ За</button>
  <button id="no" disabled>❌ Проти</button>
  <button id="abs" disabled>➖ Утрим.</button>
</div>
<div class="status" id="st">Підключіть MetaMask…</div>
<script>
const PID = "__PID__";
let account = null;
const st = document.getElementById('st');
const hdr = document.getElementById('hdr');
const tallyEl = document.getElementById('tally');
const btns = {yes:document.getElementById('yes'), no:document.getElementById('no'),
              abstain:document.getElementById('abs')};
const set = (m,c) => { st.className='status '+(c||''); st.textContent=m; };

async function refresh(){
  try {
    const r = await fetch('/api/tally?pid='+PID);
    const j = await r.json();
    if (!j.ok) { tallyEl.textContent = j.reason || 'tally недоступний'; return; }
    const t = j.tally;
    tallyEl.textContent =
      'Кворум:     ' + t.participated_weight + ' / ' + t.quorum_needed +
      (t.quorum_ok ? '  ✅' : '  ⏳') + '\n' +
      'Схвалення:  ' + t.approval_percent + '%  (треба ' + j.proposal.approval_percent + '%)' +
      (t.approval_ok ? '  ✅' : '  ⏳') + '\n' +
      'За:      ' + t.yes.count + ' голос(ів), вага ' + t.yes.weight + '\n' +
      'Проти:   ' + t.no.count  + ' голос(ів), вага ' + t.no.weight + '\n' +
      'Утрим.:  ' + t.abstain.count + ' голос(ів), вага ' + t.abstain.weight;
    hdr.innerHTML =
      '<div class="pid">' + PID + '</div>' +
      '<div class="title">' + j.proposal.title + '</div>' +
      '<div class="row">Тип: ' + j.proposal.type + ' · статус: ' + j.proposal.status + '</div>';
  } catch(e) { tallyEl.textContent = 'помилка: ' + e; }
}

async function connect(){
  if (!window.ethereum) return set('MetaMask не знайдено','err');
  try {
    const a = await window.ethereum.request({method:'eth_requestAccounts'});
    account = a[0];
    set('Підключено: '+account, 'ok');
    Object.values(btns).forEach(b => b.disabled = false);
  } catch(e) { set('Помилка підключення: '+(e.message||e),'err'); }
}

async function vote(choice){
  if (!account) return;
  try {
    set('Формую повідомлення…');
    const r = await fetch('/api/prepare', {
      method:'POST', headers:{'Content-Type':'application/json'},
      body: JSON.stringify({pid: PID, voter: account, choice})
    });
    const j = await r.json();
    if (!j.ok) return set('Помилка: '+j.reason, 'err');
    set('Запит на підпис…');
    const sig = await window.ethereum.request({
      method:'personal_sign', params:[j.message, account]
    });
    set('Надсилаю голос…');
    const r2 = await fetch('/api/vote', {
      method:'POST', headers:{'Content-Type':'application/json'},
      body: JSON.stringify({pid: PID, voter: account, choice, signature: sig, message: j.message})
    });
    const j2 = await r2.json();
    if (!j2.ok) return set('Помилка: '+j2.reason, 'err');
    set('✅ Голос зараховано: '+choice, 'ok');
    await refresh();
  } catch(e) { set('Помилка: '+(e.message||e),'err'); }
}

btns.yes.onclick = () => vote('yes');
btns.no.onclick  = () => vote('no');
btns.abs.onclick = () => vote('abstain');

refresh();
setTimeout(connect, 300);
setInterval(refresh, 5000);
</script></body></html>
"""

class H(http.server.SimpleHTTPRequestHandler):
    def __init__(s,*a,**k): super().__init__(*a, directory=ROOT, **k)
    def log_message(s,f,*a): sys.stderr.write("[prl] "+f%a+"\n")

    def _send(s, code, body, ctype="application/json"):
        s.send_response(code); s.send_header("Content-Type", ctype)
        s.send_header("Content-Length", str(len(body)))
        s.end_headers(); s.wfile.write(body)

    def do_GET(s):
        p = urlparse(s.path)
        if p.path == "/":
            q = parse_qs(p.query)
            pid = (q.get("pid") or [""])[0]
            if not pid:
                return s._send(400, b'{"ok":false,"reason":"no pid"}')
            return s._send(200, HTML.replace("__PID__", pid).encode(),
                           "text/html; charset=utf-8")
        if p.path == "/api/tally":
            q = parse_qs(p.query)
            pid = (q.get("pid") or [""])[0]
            prop = P.get_proposal(pid)
            if not prop:
                return s._send(404, b'{"ok":false,"reason":"not found"}')
            t = P.tally(pid)
            return s._send(200, json.dumps({"ok":True,"proposal":prop,"tally":t}).encode())
        if p.path == "/api/proposals":
            return s._send(200, json.dumps({"ok":True,"proposals":P.proposals()}).encode())
        super().do_GET()

    def do_POST(s):
        p = urlparse(s.path)
        n = int(s.headers.get("Content-Length",0))
        try: d = json.loads(s.rfile.read(n))
        except Exception as e:
            return s._send(400, json.dumps({"ok":False,"reason":str(e)}).encode())

        if p.path == "/api/prepare":
            msg = P.sign_message(d["pid"], d["voter"], d["choice"])
            if not msg: return s._send(404, b'{"ok":false,"reason":"no proposal"}')
            return s._send(200, json.dumps({"ok":True,"message":msg}).encode())

        if p.path == "/api/vote":
            # спершу верифікуємо підпис, потім записуємо
            vote = {
                "pid": d["pid"], "voter": d["voter"], "choice": d["choice"],
                "signature": d["signature"], "message": d["message"],
            }
            ok, why = P.verify_vote_signature(vote)
            if not ok:
                return s._send(403, json.dumps({"ok":False,"reason":"sig: "+why}).encode())
            ok, why = P.cast_vote(d["pid"], d["voter"], d["choice"],
                                  d["signature"], d["message"])
            return s._send(200 if ok else 400,
                           json.dumps({"ok":ok,"reason":why}).encode())

        s.send_error(404)

socketserver.TCPServer.allow_reuse_address = True
with socketserver.TCPServer(("127.0.0.1", PORT), H) as x:
    x.serve_forever()
