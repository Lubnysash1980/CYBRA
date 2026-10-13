#!/usr/bin/env python3
"""Підписати існуючий invoice-контракт.
Піднімає сервер + показує деталі рахунку, MetaMask підписує."""
import http.server, json, os, socketserver, sys, subprocess, time
from pathlib import Path

H = Path.home() / "CYBRA"
E = H / "modules/module_19_contract_tui_menu/evidence"

def load(cid):
    for p in [E/f"{cid}.json", E/f"{cid}_buyer.sig"]:
        if p.exists():
            try: return json.loads(p.read_text()), p
            except Exception: pass
    return None, None

def find_public_url():
    """Шукаємо активний cloudflared тунель."""
    for log in [H/"public/sign/tunnel_http2.log", H/"public/sign/tunnel_default.log",
                H/"public/sign"/f"tunnel_*.log"]:
        if isinstance(log, Path) and not log.exists(): continue
        try:
            import subprocess
            r = subprocess.run(["grep","-hoE","https://[a-z0-9-]+\\.trycloudflare\\.com",str(log)],
                               capture_output=True, text=True, timeout=5)
            for line in r.stdout.splitlines():
                if line and "api." not in line:
                    return line.strip()
        except Exception: pass
    return None

HTML = r"""<!doctype html><html lang="uk"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Підпис рахунку</title><style>
body{font-family:system-ui;background:#0b0f14;color:#e6edf3;max-width:560px;margin:0 auto;padding:20px}
h1{font-size:18px;margin:0 0 12px}
.inv{background:#161b22;border-radius:10px;padding:16px;margin:12px 0;font-size:14px}
.row{display:flex;justify-content:space-between;padding:6px 0;border-bottom:1px solid #21262d}
.row:last-child{border:0}
.item{padding:8px 0;border-bottom:1px dashed #21262d;font-size:12px}
.item:last-child{border:0}
.total{font-size:20px;color:#2ea043;font-weight:700;text-align:right;margin-top:12px}
.warn{background:#3d2814;color:#f0883e;padding:12px;border-radius:8px;font-size:12px;margin:12px 0}
button{width:100%;padding:14px;margin:8px 0;border:0;border-radius:10px;font-size:16px;font-weight:600;cursor:pointer}
#c1{background:#f6851b;color:#fff}#c2{background:#2ea043;color:#fff}
button:disabled{opacity:.5;cursor:not-allowed}
.st{margin-top:12px;padding:12px;border-radius:8px;background:#161b22;font-size:14px;white-space:pre-wrap}
.ok{color:#2ea043}.err{color:#f85149}
</style></head><body>
<h1>Підпис рахунку</h1>
<div class="inv" id="info"></div>
<div class="warn" id="warn"></div>
<button id="c1" hidden>Підключити MetaMask</button>
<button id="c2" hidden disabled>Підписати</button>
<div class="st" id="st">Готую…</div>
<script>
const DATA = __DATA__;
const CID = "__CID__";
let account = null;
const st = document.getElementById('st');
const info = document.getElementById('info');
const warn = document.getElementById('warn');
const b1 = document.getElementById('c1');
const b2 = document.getElementById('c2');
const set = (m, c) => { st.className = 'st ' + (c||''); st.textContent = m; };

function render(){
  const inv = DATA.invoice || {};
  const sup = inv.supplier || {};
  let html = '<div class="row"><b>' + (sup.name || '—') + '</b></div>';
  html += '<div class="row"><span>ЄДРПОУ</span><span>' + (sup.edrpou || '—') + '</span></div>';
  html += '<div class="row"><span>Рахунок</span><span>№' + (inv.no || '—') + '</span></div>';
  html += '<div class="row"><span>Від</span><span>' + (inv.date || '—') + '</span></div>';
  html += '<div class="row"><span>Дійсний до</span><span style="color:#f0883e">' + (inv.valid_until || '—') + '</span></div>';
  html += '<div style="margin-top:12px"><b>Позиції:</b></div>';
  for (const it of (inv.items || [])) {
    html += '<div class="item"><div>' + it.no + '. ' + it.name + '</div>';
    html += '<div style="color:#8b949e">' + it.qty + ' × ' + it.price_uah.toLocaleString() + ' = <b>' + it.sum_uah.toLocaleString() + ' UAH</b></div></div>';
  }
  html += '<div class="total">' + (DATA.total_uah || 0).toLocaleString() + ' UAH</div>';
  info.innerHTML = html;

  if (inv.valid_until) {
    warn.textContent = '⚠ Рахунок дійсний до ' + inv.valid_until + ' — перевір чи не прострочений!';
  } else {
    warn.style.display = 'none';
  }
}

async function connect(){
  if (!window.ethereum) return set('MetaMask не знайдено', 'err');
  try {
    const a = await window.ethereum.request({method:'eth_requestAccounts'});
    account = a[0];
    set('Підключено: ' + account, 'ok');
    b1.hidden = true; b2.hidden = false; b2.disabled = false;
  } catch(e) { set('Помилка: ' + e.message, 'err'); }
}

async function sign(){
  if (!account) return;
  const inv = DATA.invoice || {};
  const msg = 'CYBRA Invoice Payment\\n' +
              'CID: ' + CID + '\\n' +
              'Invoice: ' + (inv.no || '—') + ' від ' + (inv.date || '—') + '\\n' +
              'Supplier: ' + ((inv.supplier||{}).name || '—') + '\\n' +
              'Amount: ' + (DATA.total_uah || 0) + ' UAH\\n' +
              'Pay to: ' + DATA.pay_to + '\\n' +
              'Buyer: ' + account + '\\n' +
              'Timestamp: ' + new Date().toISOString();
  try {
    set('Запит підпису в MetaMask…');
    const sig = await window.ethereum.request({method:'personal_sign', params:[msg, account]});
    set('Надсилаю…');
    const r = await fetch('/sign', {
      method:'POST', headers:{'Content-Type':'application/json'},
      body: JSON.stringify({cid: CID, address: account, message: msg, signature: sig})
    });
    if (!r.ok) throw new Error('HTTP ' + r.status);
    set('✅ Підписано! Можна закривати.', 'ok');
    b2.disabled = true;
  } catch(e) { set('Помилка: ' + (e.message || e), 'err'); }
}

b1.onclick = connect;
b2.onclick = sign;
render();
set('Натисни Підключити');
b1.hidden = false;
</script></body></html>"""

class H2(http.server.SimpleHTTPRequestHandler):
    def log_message(s, f, *a): sys.stderr.write("[sign] " + f%a + "\n")
    def _send(s, code, body, ctype="application/json"):
        s.send_response(code); s.send_header("Content-Type", ctype)
        s.send_header("Content-Length", str(len(body)))
        s.end_headers(); s.wfile.write(body)
    def do_GET(s):
        from urllib.parse import urlparse
        p = urlparse(s.path).path
        if p == "/":
            d, _ = load(CID)
            if not d: return s._send(404, b'{"ok":false}')
            html = HTML.replace("__DATA__", json.dumps(d)).replace("__CID__", CID)
            return s._send(200, html.encode(), "text/html; charset=utf-8")
        if p == "/state":
            d, _ = load(CID)
            return s._send(200, json.dumps({"ok": True, "data": d}).encode())
        s.send_error(404)
    def do_POST(s):
        from urllib.parse import urlparse
        if urlparse(s.path).path != "/sign": return s.send_error(404)
        n = int(s.headers.get("Content-Length", 0))
        try: d = json.loads(s.rfile.read(n))
        except Exception as e: return s._send(400, json.dumps({"ok":False,"reason":str(e)}).encode())
        # Зберегти .sig
        out = E / f"{CID}_buyer.sig"
        d["cid"] = CID
        d["signed_at"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        out.write_text(json.dumps(d, indent=2, ensure_ascii=False))
        s._send(200, b'{"ok":true}')
        # shutdown сервер через 2 сек
        import threading
        threading.Timer(2, s.server.shutdown).start()

if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8795
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("127.0.0.1", port), H2) as x:
        x.serve_forever()
