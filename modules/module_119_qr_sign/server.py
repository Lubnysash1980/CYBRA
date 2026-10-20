import http.server, json, os, socketserver, sys, base64
from urllib.parse import urlparse, parse_qs
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import levels

ROOT = os.path.dirname(os.path.abspath(__file__))
EVIDENCE = sys.argv[1]; PORT = int(sys.argv[2])

HTML = r"""<!doctype html><html lang="uk"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>CYBRA QR Sign</title><style>
body{font-family:system-ui;background:#0b0f14;color:#e6edf3;max-width:520px;margin:0 auto;padding:24px}
h1{font-size:18px;margin:0 0 16px}
.row{font-family:monospace;background:#161b22;padding:10px;border-radius:8px;font-size:12px;margin-bottom:8px;word-break:break-all}
.badge{display:inline-block;padding:2px 8px;border-radius:20px;font-size:11px;font-weight:700;margin-right:6px}
.ok{background:#0d2818;color:#2ea043}.fail{background:#3d1418;color:#f85149}
button{width:100%;padding:14px;margin:8px 0;border:0;border-radius:10px;font-size:16px;font-weight:600;cursor:pointer}
#connect{background:#f6851b;color:#fff}#sign{background:#2ea043;color:#fff}
button:disabled{opacity:.5;cursor:not-allowed}
.status{margin-top:16px;padding:12px;border-radius:8px;background:#161b22;font-size:14px;white-space:pre-wrap}
.notes{margin-top:8px;font-size:12px;color:#8b949e}
.note{padding:2px 0}
.parl{margin-top:12px;padding:12px;border-radius:8px;background:#0d1117;
      border:1px solid #21262d;font-size:12px}
.parl h4{margin:0 0 8px;font-size:12px;color:#58a6ff;text-transform:uppercase;
         letter-spacing:0.5px}
.approver{display:flex;justify-content:space-between;padding:4px 0;
          border-bottom:1px solid #21262d;font-family:monospace}
.approver:last-child{border-bottom:0}
.appr-ok{color:#2ea043}
.quorum-bar{height:6px;border-radius:3px;background:#21262d;margin:8px 0;overflow:hidden}
.quorum-fill{height:100%;background:#2ea043;transition:width 0.3s}
</style></head><body>
<h1>CYBRA · Підпис контракту (QR)</h1>
<div id="hdr"></div>
<div class="notes" id="notes"></div>
<button id="connect" hidden>1️⃣ Підключити MetaMask</button>
<button id="sign" hidden disabled>2️⃣ Підписати</button>
<div class="status" id="st">Перевірка QR…</div>
<script>
const P = __PAYLOAD__;
const VERIFY = __VERIFY__;
const PARL = __PARLIAMENT__ || null;
let account=null, signed=false;
const st=document.getElementById('st');
const hdr=document.getElementById('hdr');
const notes=document.getElementById('notes');
const bc=document.getElementById('connect');
const bs=document.getElementById('sign');
function show(m,c){st.className='status '+(c||'');st.textContent=m;}

function renderParlament(){
  if (!PARL) return;
  const div = document.createElement('div');
  div.className = 'parl';
  const total = PARL.total_weight || 0;
  const got = PARL.signed_weight || 0;
  const pct = total ? (got/total*100) : 0;
  let h = '<h4>🏛 Парламентські підписи</h4>';
  h += '<div style="color:#8b949e;margin-bottom:6px">'
     + (PARL.pid ? 'PID: '+PARL.pid : 'немає пропозиції') + '</div>';
  if (PARL.approvers && PARL.approvers.length) {
    for (const a of PARL.approvers) {
      h += '<div class="approver"><span class="appr-ok">✓ '+a.label+'</span>'
         + '<span style="color:#6e7681">'+a.role+'</span></div>';
    }
  } else {
    h += '<div style="color:#f85149">немає підписів</div>';
  }
  h += '<div class="quorum-bar"><div class="quorum-fill" style="width:'+pct+'%"></div></div>';
  h += '<div style="color:'+(PARL.quorum_met?'#2ea043':'#f0883e')+'">'
     + (PARL.quorum_met ? '✅ Кворум досягнуто' : '⏳ Кворум: '+got+' / '+total)
     + '</div>';
  div.innerHTML = h;
  const notes = document.getElementById('notes');
  if (notes) notes.parentNode.insertBefore(div, notes.nextSibling);
  else document.body.appendChild(div);
}

if (!VERIFY.ok) {
  hdr.innerHTML = '<div class="row"><span class="badge fail">FAIL</span>L'+VERIFY.level+' · '+VERIFY.reason+'</div>';
  show('QR не пройшов перевірку: '+VERIFY.reason, 'fail');
} else {
  hdr.innerHTML = '<div class="row"><span class="badge ok">OK</span>Рівень '+VERIFY.level+'</div>'
                + '<div class="row">CID: '+P.c+'</div>';
  notes.innerHTML = (VERIFY.notes||[]).map(n=>'<div class="note">· '+n+'</div>').join('');
  show('QR верифіковано · готово до підпису','ok');
  renderParlament();
  run();
}

async function run(){
  if (!window.ethereum) return show('MetaMask не знайдено','fail');
  try{
    show('Запит на підключення…');
    const a = await window.ethereum.request({method:'eth_requestAccounts'});
    account = a[0];
    show('Підключено: '+account,'ok');
    await doSign();
  }catch(e){ show('Помилка: '+(e.message||e),'fail'); bc.hidden=false; }
}
async function doSign(){
  if (!account || signed) return;
  const msg = 'CYBRA Contract\nCID: '+P.c+'\nBuyer: '+account+'\nLevel: '+VERIFY.level+'\nTime: '+new Date().toISOString();
  try{
    show('Запит на підпис…');
    const sig = await window.ethereum.request({method:'personal_sign', params:[msg, account]});
    show('Надсилаю…');
    const r = await fetch('/sign', {method:'POST', headers:{'Content-Type':'application/json'},
      body: JSON.stringify({cid:P.c, address:account, message:msg, signature:sig,
                            level:VERIFY.level, payload:P})});
    if (!r.ok) throw new Error('HTTP '+r.status);
    signed = true;
    show('✅ Готово! Можна закрити.','ok');
    bs.disabled = true;
  }catch(e){ show('Помилка: '+(e.message||e),'fail'); bs.hidden=false; bs.disabled=false; }
}
bc.onclick = run;
bs.onclick = doSign;
</script></body></html>
"""

class H(http.server.SimpleHTTPRequestHandler):
    def __init__(s,*a,**k): super().__init__(*a, directory=ROOT, **k)
    def log_message(s,f,*a): sys.stderr.write("[qr] "+f%a+"\n")
    def do_GET(s):
        if urlparse(s.path).path == "/":
            q = parse_qs(urlparse(s.path).query)
            p_b64 = (q.get("p") or [""])[0]
            if not p_b64:
                s.send_response(400); s.send_header("Content-Type","text/plain"); s.end_headers()
                s.wfile.write(b"no payload"); return
            pad = "=" * (-len(p_b64) % 4)
            try:
                payload = json.loads(base64.urlsafe_b64decode(p_b64 + pad).decode())
            except Exception as e:
                s.send_response(400); s.end_headers()
                s.wfile.write(f"bad payload: {e}".encode()); return
            r = levels.verify(payload, consume_nonce=False)
            parl_info = None
            if payload.get("v") == 8:
                try:
                    import parliament_check
                    pi = parliament_check.get_approvers(payload.get("c",""))
                    # рахуємо signed_weight
                    members = {}
                    try:
                        sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "module_121_parlament"))
                        import parliament as P2
                        members = {m["addr"].lower(): m for m in P2.members()["members"]}
                    except Exception: pass
                    signed_weight = sum(members.get(a["addr"].lower(),{}).get("weight",1)
                                        for a in pi.get("approvers",[]))
                    total_weight = sum(m.get("weight",1) for m in members.values()
                                       if m.get("active",True))
                    parl_info = {
                        "pid": pi.get("pid"),
                        "approvers": pi.get("approvers", []),
                        "quorum_met": pi.get("quorum_met", False),
                        "signed_weight": signed_weight,
                        "total_weight": total_weight,
                    }
                except Exception as e:
                    parl_info = {"pid": None, "approvers": [], "quorum_met": False,
                                 "error": str(e)}
            body = (HTML
                .replace("__PAYLOAD__", json.dumps(payload))
                .replace("__VERIFY__", json.dumps(r))
                .replace("__PARLIAMENT__", json.dumps(parl_info) if parl_info else "null"))
            s.send_response(200); s.send_header("Content-Type","text/html; charset=utf-8")
            s.send_header("Content-Length", str(len(body.encode())))
            s.end_headers(); s.wfile.write(body.encode()); return
        super().do_GET()
    def do_POST(s):
        if urlparse(s.path).path != "/sign": s.send_error(404); return
        n = int(s.headers.get("Content-Length",0))
        try: d = json.loads(s.rfile.read(n))
        except Exception as e: s.send_error(400, str(e)); return
        # фінальна верифікація (consumes nonce)
        v = levels.verify(d.get("payload", {}), consume_nonce=True)
        if not v.get("ok"):
            s.send_response(403); s.end_headers()
            s.wfile.write(json.dumps({"ok":False,"reason":v.get("reason")}).encode()); return
        cid = d.get("cid","X")
        out = os.path.join(EVIDENCE, f"{cid}_buyer.sig")
        d["qr_verify"] = v
        open(out,"w").write(json.dumps(d, indent=2))
        s.send_response(200); s.send_header("Content-Type","application/json")
        s.end_headers(); s.wfile.write(b'{"ok":true}')

socketserver.TCPServer.allow_reuse_address = True
with socketserver.TCPServer(("0.0.0.0", PORT), H) as x:
    x.serve_forever()
