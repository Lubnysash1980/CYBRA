#!/usr/bin/env python3
"""Web UI — простий HTML стан CYBRA. Тільки показує."""
import http.server, json, os, socketserver, sys, subprocess, time
from pathlib import Path

H = Path.home() / "CYBRA"
M = H / "modules"
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8791

def _run(cmd, timeout=10):
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
        return (r.stdout + r.stderr).strip()
    except Exception: return ""

def gather():
    out = {"at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}
    # health
    try:
        sys.path.insert(0, str(M/"module_121_parlament"))
        import health
        h = health.health_all()
        out["health"] = h
    except Exception as e:
        out["health"] = {"overall": 0, "error": str(e)[:100]}
    # controllers
    try:
        sys.path.insert(0, str(M/"module_320_controllers"))
        import controllers
        out["controllers"] = controllers.check_all()
    except Exception: out["controllers"] = []
    # load
    try:
        sys.path.insert(0, str(M/"module_397_load"))
        import load as L
        out["load"] = L.get_load()
        mode, reason = L.decide(out["load"])
        out["load"]["mode"] = mode; out["load"]["reason"] = reason
    except Exception: out["load"] = {}
    # structure
    try:
        sys.path.insert(0, str(M/"module_395_structure"))
        import structure as S
        d = S.verify()
        out["structure"] = {"ok": len(d["ok"]), "missing": len(d["missing"]), "changed": len(d["changed"])}
    except Exception: out["structure"] = {}
    # SRC
    try:
        cp = Path.home() / ".cybra_src" / "checkpoint.json"
        if cp.exists():
            out["src"] = json.loads(cp.read_text())
    except Exception: out["src"] = {}
    # processes
    r = _run("cybra-pm list")
    out["processes_raw"] = r
    # signals
    try:
        E = M / "module_19_contract_tui_menu/evidence"
        sigs = list(E.glob("*.sig")) if E.exists() else []
        unsigned = []
        for c in E.glob("C-INV-*.json"):
            cid = c.stem
            if not (E/f"{cid}_buyer.sig").exists():
                unsigned.append(cid)
        out["signatures"] = {"total": len(sigs), "unsigned": len(unsigned), "unsigned_list": unsigned[:5]}
    except Exception: out["signatures"] = {}
    return out

HTML = r"""<!doctype html><html lang="uk"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="theme-color" content="#0b0f14">
<title>CYBRA Status</title><style>
*{box-sizing:border-box}
body{font-family:system-ui;background:#0b0f14;color:#e6edf3;max-width:800px;margin:0 auto;padding:20px;font-size:14px}
h1{font-size:20px;margin:0 0 4px}
h2{font-size:13px;color:#58a6ff;margin:18px 0 8px;text-transform:uppercase;letter-spacing:.5px}
.kpi-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(140px,1fr));gap:10px;margin-bottom:16px}
.card{background:#161b22;border:1px solid #21262d;border-radius:10px;padding:14px}
.kpi{font-size:28px;font-weight:800;line-height:1}
.kpi-lbl{font-size:11px;color:#8b949e;text-transform:uppercase;margin-top:4px}
.ok{color:#2ea043}.warn{color:#f0883e}.err{color:#f85149}.info{color:#58a6ff}
.row{display:flex;justify-content:space-between;padding:7px 0;border-bottom:1px solid #21262d;font-family:monospace;font-size:12px}
.row:last-child{border-bottom:0}
.badge{padding:2px 8px;border-radius:20px;font-size:11px;font-weight:700}
.b-ok{background:#0d2818;color:#2ea043}
.b-warn{background:#3d2814;color:#f0883e}
.b-err{background:#3d1418;color:#f85149}
.bar{height:6px;background:#21262d;border-radius:3px;overflow:hidden;margin-top:6px}
.fill{height:100%;background:#2ea043;transition:width .3s}
.timestamp{color:#8b949e;font-size:11px;margin-bottom:16px}
</style></head><body>
<h1>CYBRA · Status</h1>
<div class="timestamp" id="ts">loading…</div>

<div class="kpi-grid" id="kpis"></div>

<div class="card"><h2>Health</h2><div id="health"></div></div>
<div class="card"><h2>Controllers</h2><div id="ctrls"></div></div>
<div class="card"><h2>Load (CPU / RAM / Disk)</h2><div id="load"></div></div>
<div class="card"><h2>Structure</h2><div id="structure"></div></div>
<div class="card"><h2>Signatures</h2><div id="sigs"></div></div>
<div class="card"><h2>Processes</h2><div id="procs"></div></div>

<script>
function fmt(v){ return v === undefined || v === null ? '—' : v }
function render(d){
  document.getElementById('ts').textContent = 'Оновлено: ' + d.at;
  const h = d.health || {};
  const ov = h.overall || 0;
  const hCol = ov >= 100 ? 'ok' : ov >= 80 ? 'warn' : 'err';

  const ctrls = d.controllers || [];
  const cOk = ctrls.filter(c => c.ok).length;
  const cTotal = ctrls.length;

  const ld = d.load || {};
  const st = d.structure || {};
  const sg = d.signatures || {};

  document.getElementById('kpis').innerHTML =
    `<div class="card"><div class="kpi ${hCol}">${ov}%</div><div class="kpi-lbl">Health</div></div>` +
    `<div class="card"><div class="kpi ${cOk === cTotal ? 'ok' : 'warn'}">${cOk}/${cTotal}</div><div class="kpi-lbl">Controllers</div></div>` +
    `<div class="card"><div class="kpi ${ld.mode === 'critical' ? 'err' : ld.mode === 'high' ? 'warn' : 'ok'}">${ld.mode || '?'}</div><div class="kpi-lbl">Load mode</div></div>` +
    `<div class="card"><div class="kpi ${sg.unsigned ? 'warn' : 'ok'}">${sg.total || 0}</div><div class="kpi-lbl">Signatures</div></div>`;

  document.getElementById('health').innerHTML =
    `<div class="row"><span>Парламент</span><span class="${h.parliament?.score === 100 ? 'ok' : 'warn'}">${h.parliament?.score || 0}%</span></div>` +
    `<div class="row"><span>Система</span><span class="${h.system?.score === 100 ? 'ok' : 'warn'}">${h.system?.score || 0}%</span></div>` +
    `<div class="bar"><div class="fill" style="width:${ov}%"></div></div>`;

  document.getElementById('ctrls').innerHTML = ctrls.map(c =>
    `<div class="row"><span>${c.ok ? '✓' : '✗'} ${c.name || c.id}</span><span class="${c.ok ? 'ok' : 'err'}">${c.ok ? 'ok' : (c.msg || '').slice(0,40)}</span></div>`
  ).join('') || '<div style="color:#8b949e">—</div>';

  document.getElementById('load').innerHTML =
    `<div class="row"><span>CPU</span><span class="${ld.cpu_pct > 80 ? 'warn' : 'ok'}">${ld.cpu_pct || 0}%</span></div>` +
    `<div class="row"><span>RAM</span><span class="${ld.ram_pct > 80 ? 'warn' : 'ok'}">${ld.ram_pct || 0}%</span></div>` +
    `<div class="row"><span>Disk free</span><span>${ld.disk_free_mb || '?'} MB</span></div>` +
    `<div class="row"><span>Режим</span><span class="info">${ld.mode || '?'} — ${ld.reason || ''}</span></div>`;

  document.getElementById('structure').innerHTML =
    `<div class="row"><span>✓ OK</span><span class="ok">${st.ok || 0}</span></div>` +
    `<div class="row"><span>✗ Missing</span><span class="${st.missing ? 'err' : 'ok'}">${st.missing || 0}</span></div>` +
    `<div class="row"><span>! Changed</span><span class="${st.changed ? 'warn' : 'ok'}">${st.changed || 0}</span></div>`;

  let sigHtml = `<div class="row"><span>Всього .sig</span><span>${sg.total || 0}</span></div>`;
  sigHtml += `<div class="row"><span>Не підписано</span><span class="${sg.unsigned ? 'warn' : 'ok'}">${sg.unsigned || 0}</span></div>`;
  if (sg.unsigned_list?.length) {
    sigHtml += sg.unsigned_list.map(c => `<div class="row"><span style="font-size:11px">${c.slice(0,24)}</span><span class="warn">unsigned</span></div>`).join('');
  }
  document.getElementById('sigs').innerHTML = sigHtml;

  const procs = (d.processes_raw || '').split('\n').filter(l => l.includes('●') || l.includes('○'));
  document.getElementById('procs').innerHTML = procs.map(l => {
    const parts = l.split(/\s+/);
    const name = parts[0], status = l.includes('●') ? 'ok' : 'err';
    return `<div class="row"><span>${l.includes('●') ? '●' : '○'} ${name}</span><span class="${status}">${l.includes('●') ? 'online' : 'offline'}</span></div>`;
  }).join('') || '<div style="color:#8b949e">—</div>';
}

async function refresh(){
  try {
    const r = await fetch('/api/state');
    render(await r.json());
  } catch(_) {}
}
refresh();
setInterval(refresh, 5000);
if ('serviceWorker' in navigator) {
  // немає service worker, але метадані PWA
}
</script></body></html>"""

class H2(http.server.SimpleHTTPRequestHandler):
    def log_message(s, f, *a): pass
    def do_GET(s):
        from urllib.parse import urlparse
        p = urlparse(s.path).path
        if p == "/":
            body = HTML.encode()
            s.send_response(200); s.send_header("Content-Type", "text/html; charset=utf-8")
            s.send_header("Content-Length", str(len(body)))
            s.end_headers(); s.wfile.write(body); return
        if p == "/api/state":
            body = json.dumps(gather(), ensure_ascii=False, default=str).encode()
            s.send_response(200); s.send_header("Content-Type", "application/json")
            s.send_header("Content-Length", str(len(body)))
            s.end_headers(); s.wfile.write(body); return
        if p == "/manifest.json":
            mf = json.dumps({
                "name":"CYBRA Status","short_name":"CYBRA","start_url":"/",
                "display":"standalone","background_color":"#0b0f14","theme_color":"#0b0f14",
            }).encode()
            s.send_response(200); s.send_header("Content-Type","application/json")
            s.send_header("Content-Length", str(len(mf)))
            s.end_headers(); s.wfile.write(mf); return
        s.send_error(404)

socketserver.TCPServer.allow_reuse_address = True
with socketserver.TCPServer(("127.0.0.1", PORT), H2) as x:
    x.serve_forever()
