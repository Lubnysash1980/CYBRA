#!/data/data/com.termux/files/usr/bin/env python3
# CYBRA WEB SERVER — dashboard + API

import http.server
import socketserver
import json
import os
import subprocess
import sys
from datetime import datetime
from urllib.parse import urlparse

ROOT = os.path.expanduser("~/CYBRA")
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8765


def run_cmd(cmd, timeout=10):
    """Запустити команду і повернути stdout."""
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
        return r.stdout.strip()
    except Exception as e:
        return f"ERR: {e}"


def get_status():
    """JSON статус системи."""
    # Модулі
    modules_dir = f"{ROOT}/modules"
    modules = []
    if os.path.isdir(modules_dir):
        for m in sorted(os.listdir(modules_dir)):
            if m.startswith(('.', '@', '_')) or m in ('evolution', 'answer_engine', 'node_modules'):
                continue
            p = os.path.join(modules_dir, m)
            if os.path.isdir(p):
                modules.append(m)

    # Контракти / лініки
    contracts_dir = f"{modules_dir}/module_19_contract_tui_menu/contracts"
    links_dir = f"{modules_dir}/module_19_contract_tui_menu/links"

    contracts = 0
    if os.path.isdir(contracts_dir):
        contracts = sum(1 for f in os.listdir(contracts_dir) if f.endswith('.env'))

    links = 0
    if os.path.isdir(links_dir):
        links = sum(1 for f in os.listdir(links_dir) if f.endswith('.link'))

    # Процеси
    procs = {}
    for name, pidfile in [
        ('watchdog', '.watchdog.pid'),
        ('evo_ctl', '.evo_ctl.pid'),
        ('parawatch', '.parawatch.pid'),
        ('schedule', '.schedule.pid'),
        ('web', '.cybra_web.pid'),
    ]:
        pf = os.path.join(ROOT, pidfile)
        running = False
        if os.path.isfile(pf):
            try:
                with open(pf) as f:
                    pid = int(f.read().strip())
                os.kill(pid, 0)
                running = True
            except Exception:
                pass
        procs[name] = running

    # Watchdog, evo, parawatch з PID
    watchdog_pid = None
    pf = os.path.join(ROOT, '.watchdog.pid')
    if os.path.isfile(pf):
        try:
            with open(pf) as f:
                watchdog_pid = int(f.read().strip())
        except:
            pass

    return {
        "ts": datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
        "modules": len(modules),
        "module_list": modules,
        "contracts": contracts,
        "links": links,
        "processes": procs,
        "watchdog_pid": watchdog_pid,
        "license": "0x66434c5501242ccC71b5a39C765892921624B66c",
        "policy": "3% non-degradation",
    }


def get_metrics_prom():
    """Prometheus metrics (in-memory)."""
    status = get_status()
    lines = [
        "# CYBRA metrics",
        f"# generated {status['ts']}",
        "",
        f"cybra_modules_total {status['modules']}",
        f"cybra_contracts_total {status['contracts']}",
        f"cybra_links_total {status['links']}",
    ]

    for name, running in status['processes'].items():
        lines.append(f'cybra_process_running{{name="{name}"}} {1 if running else 0}')

    # Модуль pass/fail — з audit
    audit_dir = f"{ROOT}/audit"
    if os.path.isdir(audit_dir):
        # Знайти найновіший test log per module
        per_mod = {}
        for f in os.listdir(audit_dir):
            if not f.endswith('.test.log'):
                continue
            # Формат: RUN-..._module_XX_name.test.log
            parts = f.split('_', 2)
            if len(parts) >= 3:
                mod = '_'.join(f.split('_')[1:]).replace('.test.log', '')
                # беремо останній
                mtime = os.path.getmtime(os.path.join(audit_dir, f))
                if mod not in per_mod or per_mod[mod][1] < mtime:
                    per_mod[mod] = (os.path.join(audit_dir, f), mtime)

        for mod, (path, _) in sorted(per_mod.items()):
            try:
                with open(path) as f:
                    content = f.read()
                p = content.count("[PASS]")
                fl = content.count("[FAIL]")
                # Спроба парсингу PASS=N
                if p == 0:
                    for line in content.splitlines():
                        if "PASS=" in line:
                            try:
                                p = int(line.split("PASS=")[1].split()[0])
                            except:
                                pass
                            break
                lines.append(f'cybra_module_pass{{module="{mod}"}} {p}')
                lines.append(f'cybra_module_fail{{module="{mod}"}} {fl}')
            except:
                pass

    return "\n".join(lines)


def get_log_tail(name, n=50):
    """Tail лог-файлу."""
    log = f"{ROOT}/logs/{name}"
    if not os.path.isfile(log):
        return f"(лог {name} відсутній)"
    try:
        with open(log) as f:
            lines = f.readlines()
        return "".join(lines[-n:])
    except Exception as e:
        return f"ERR: {e}"


# ═══════════════════════════════════════════════════════════
# HTML Dashboard
# ═══════════════════════════════════════════════════════════
HTML_PANEL = """<!DOCTYPE html>
<html lang="uk">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>CYBRA Panel</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    background: #0d1117; color: #c9d1d9;
    padding: 16px; min-height: 100vh;
  }
  h1 { font-size: 20px; margin-bottom: 4px; color: #58a6ff; }
  h2 { font-size: 14px; margin: 20px 0 10px; color: #7d8590; text-transform: uppercase; letter-spacing: 1px; }
  .header { margin-bottom: 20px; padding-bottom: 16px; border-bottom: 1px solid #21262d; }
  .status-badge { display: inline-block; padding: 4px 10px; border-radius: 12px; font-size: 12px; font-weight: 600; }
  .ok   { background: #1a7f37; color: #fff; }
  .warn { background: #9e6a03; color: #fff; }
  .err  { background: #da3633; color: #fff; }
  .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(140px, 1fr)); gap: 12px; }
  .card {
    background: #161b22; border: 1px solid #30363d; border-radius: 8px;
    padding: 14px; transition: border 0.2s;
  }
  .card:hover { border-color: #58a6ff; }
  .card .label { font-size: 11px; color: #7d8590; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 6px; }
  .card .value { font-size: 22px; font-weight: 600; color: #f0f6fc; }
  .card .value.ok { color: #3fb950; }
  .card .value.err { color: #f85149; }
  .process-list { display: flex; flex-wrap: wrap; gap: 8px; }
  .process {
    display: flex; align-items: center; gap: 6px;
    padding: 6px 12px; background: #21262d; border-radius: 6px;
    font-size: 13px;
  }
  .dot { width: 8px; height: 8px; border-radius: 50%; }
  .dot.on { background: #3fb950; box-shadow: 0 0 6px #3fb950; }
  .dot.off { background: #484f58; }
  .log-box {
    background: #0d1117; border: 1px solid #30363d; border-radius: 6px;
    padding: 12px; font-family: 'Courier New', monospace; font-size: 11px;
    max-height: 240px; overflow-y: auto; white-space: pre-wrap; color: #7ee787;
  }
  .module-list {
    display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
    gap: 4px; font-size: 12px;
  }
  .module-list div { padding: 4px 8px; background: #21262d; border-radius: 4px; }
  .refresh { font-size: 11px; color: #7d8590; margin-top: 10px; }
  .actions { display: flex; gap: 8px; flex-wrap: wrap; margin-top: 10px; }
  button {
    background: #21262d; border: 1px solid #30363d; color: #c9d1d9;
    padding: 8px 14px; border-radius: 6px; cursor: pointer; font-size: 12px;
  }
  button:hover { background: #30363d; border-color: #58a6ff; }
  .footer { margin-top: 24px; padding-top: 16px; border-top: 1px solid #21262d; font-size: 11px; color: #7d8590; text-align: center; }
</style>
</head>
<body>

<div class="header">
  <h1>🛡️ CYBRA Panel</h1>
  <div style="font-size:12px; color:#7d8590; margin-top:4px;">
    <span id="ts">—</span> ·
    <span class="status-badge ok" id="health-badge">LOADING</span>
  </div>
</div>

<h2>Загальне</h2>
<div class="grid">
  <div class="card"><div class="label">Модулів</div><div class="value" id="m-modules">—</div></div>
  <div class="card"><div class="label">Контрактів</div><div class="value" id="m-contracts">—</div></div>
  <div class="card"><div class="label">Лінків</div><div class="value" id="m-links">—</div></div>
  <div class="card"><div class="label">Policy</div><div class="value" style="font-size:14px;" id="m-policy">—</div></div>
</div>

<h2>Процеси</h2>
<div class="process-list" id="procs">—</div>

<h2>Модулі</h2>
<div class="module-list" id="modules"></div>

<h2>Watchdog log (останні 30)</h2>
<div class="log-box" id="log-watchdog">—</div>

<h2>Evo runtime log (останні 30)</h2>
<div class="log-box" id="log-evo">—</div>

<h2>Alerts</h2>
<div class="log-box" id="log-alerts">—</div>

<div class="actions">
  <button onclick="refreshAll()">🔄 Оновити</button>
  <button onclick="location.href='/metrics'">📊 Metrics</button>
  <button onclick="location.href='/status'">📋 Status JSON</button>
</div>

<div class="refresh">Оновлення: <span id="countdown">10</span>с · <span id="refresh-time">—</span></div>

<div class="footer">
  CYBRA Network · license 0x66434c55...B66c
</div>

<script>
async function fetchText(url) {
  const r = await fetch(url);
  return r.text();
}

async function fetchJSON(url) {
  const r = await fetch(url);
  return r.json();
}

async function refreshStatus() {
  try {
    const s = await fetchJSON('/status');

    document.getElementById('ts').textContent = s.ts;
    document.getElementById('m-modules').textContent = s.modules;
    document.getElementById('m-contracts').textContent = s.contracts;
    document.getElementById('m-links').textContent = s.links;
    document.getElementById('m-policy').textContent = s.policy || '—';

    // Health
    const hb = document.getElementById('health-badge');
    const allOn = Object.values(s.processes).every(v => v);
    hb.textContent = allOn ? 'HEALTHY' : 'DEGRADED';
    hb.className = 'status-badge ' + (allOn ? 'ok' : 'warn');

    // Processes
    const procs = document.getElementById('procs');
    procs.innerHTML = '';
    for (const [name, running] of Object.entries(s.processes)) {
      const d = document.createElement('div');
      d.className = 'process';
      d.innerHTML = '<span class="dot ' + (running ? 'on' : 'off') + '"></span>' + name;
      procs.appendChild(d);
    }

    // Modules
    const mods = document.getElementById('modules');
    mods.innerHTML = '';
    for (const m of (s.module_list || [])) {
      const d = document.createElement('div');
      d.textContent = '🟢 ' + m;
      mods.appendChild(d);
    }

    document.getElementById('refresh-time').textContent = new Date().toLocaleTimeString();
  } catch (e) {
    console.error(e);
  }
}

async function refreshLogs() {
  try {
    document.getElementById('log-watchdog').textContent =
      await fetchText('/log/watchdog.log?n=30');
    document.getElementById('log-evo').textContent =
      await fetchText('/log/evo_runtime.log?n=30');
    document.getElementById('log-alerts').textContent =
      await fetchText('/log/alerts.log?n=20');
  } catch (e) {
    console.error(e);
  }
}

function refreshAll() {
  refreshStatus();
  refreshLogs();
  countdown = 10;
}

let countdown = 10;
setInterval(() => {
  countdown--;
  document.getElementById('countdown').textContent = countdown;
  if (countdown <= 0) {
    refreshAll();
  }
}, 1000);

refreshAll();
</script>
</body>
</html>
"""


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        # Тихіше — тільки помилки
        pass

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path

        # ─── HTML Panel ───
        if path == "/" or path == "/panel":
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            self.wfile.write(HTML_PANEL.encode("utf-8"))
            return

        # ─── Status JSON ───
        if path == "/status":
            data = get_status()
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(json.dumps(data, indent=2, ensure_ascii=False).encode("utf-8"))
            return

        # ─── Health ───
        if path == "/healthz":
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(b"OK\n")
            return

        # ─── Metrics ───
        if path == "/metrics":
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; version=0.0.4")
            self.end_headers()
            self.wfile.write(get_metrics_prom().encode("utf-8"))
            return

        # ─── Log tail ───
        if path.startswith("/log/"):
            # /log/name.log?n=30
            logname = path[5:]
            # Захист від path traversal
            if ".." in logname or "/" in logname:
                self.send_response(400)
                self.end_headers()
                return

            n = 50
            if "n=" in parsed.query:
                try:
                    n = int(parsed.query.split("n=")[1].split("&")[0])
                    n = min(max(n, 1), 500)
                except:
                    pass

            content = get_log_tail(logname, n)

            self.send_response(200)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(content.encode("utf-8"))
            return

        # ─── 404 ───
        self.send_response(404)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write(b"404 - not found\n")


if __name__ == "__main__":
    with socketserver.TCPServer(("0.0.0.0", PORT), Handler) as httpd:
        print(f"CYBRA web server listening on 0.0.0.0:{PORT}", flush=True)
        httpd.serve_forever()
