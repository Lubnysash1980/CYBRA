#!/usr/bin/env bash
set +e
cd "$HOME/CYBRA" || exit 1

echo "=== INSTALL CYBRA BOT BAR MENU ==="

mkdir -p \
  scripts/bot_supervisor \
  data/cybra_bot_supervisor/{bar,reports,audit,actions,tasks,config} \
  data/cybra_finance/it_department/tasks \
  parliament/inbox \
  data/cybra_bar/menus \
  posts feeds proofs dashboard/cybra_bot_bar runtime/redis

mkdir -p "$HOME/CYBRA/.cybra_local_secret/exchanges"
chmod 700 "$HOME/CYBRA/.cybra_local_secret" 2>/dev/null || true
chmod 700 "$HOME/CYBRA/.cybra_local_secret/exchanges" 2>/dev/null || true

grep -qxF ".cybra_local_secret/" .gitignore 2>/dev/null || echo ".cybra_local_secret/" >> .gitignore
grep -qxF "data/cybra_bot_supervisor/logs/" .gitignore 2>/dev/null || echo "data/cybra_bot_supervisor/logs/" >> .gitignore
grep -qxF "data/cybra_bot_supervisor/pids/" .gitignore 2>/dev/null || echo "data/cybra_bot_supervisor/pids/" >> .gitignore

cat > scripts/bot_supervisor/cybra_bot_bar_menu.py <<'PY'
#!/usr/bin/env python3
import os, sys, json, time, hashlib, subprocess, shutil, html, getpass
from pathlib import Path
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs

ROOT = Path.home() / "CYBRA"
SECRET_DIR = ROOT / ".cybra_local_secret/exchanges"
CONFIG_FILE = ROOT / "data/cybra_bot_supervisor/config/bot_bar_config.json"
REPORT_FILE = ROOT / "data/cybra_bot_supervisor/bar/bot_bar_latest.json"
ACTIONS_DIR = ROOT / "data/cybra_bot_supervisor/actions"

SAFETY = {
    "real_payment_now": False,
    "real_trading_now": False,
    "live_orders_enabled": False,
    "live_order_button_creates_request_only": True,
    "paper_trading": True,
    "testnet_mode": True,
    "automatic_external_tx": False,
    "automatic_withdrawals": False,
    "automatic_SWIFT": False,
    "automatic_real_rewards": False,
    "manual_OWNER_approval_required": True,
    "it_supervision_required": True,
    "cyber_parliament_supervision_required": True,
    "api_keys_stored_local_only": True,
    "do_not_store_secrets_in_git": True
}

QUEUES = [
    "it_department",
    "parliament_inbox",
    "cybra:audit:finance",
    "cybra:bot:supervised",
    "cybra:finance:evolution:pool",
    "cybra:meta:evolution:pool"
]

def now():
    return time.strftime("%Y-%m-%dT%H:%M:%S")

def mkdir(p):
    Path(p).mkdir(parents=True, exist_ok=True)

def write_json(path, data, mode=None):
    p = Path(path)
    mkdir(p.parent)
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    if mode:
        try:
            os.chmod(p, mode)
        except Exception:
            pass

def read_json(path, default=None):
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    except Exception:
        return default if default is not None else {}

def write_text(path, text):
    p = Path(path)
    mkdir(p.parent)
    p.write_text(text, encoding="utf-8")

def sha_file(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def run(cmd):
    return subprocess.run(cmd, shell=True, cwd=ROOT, text=True, capture_output=True)

def ensure_redis():
    if not shutil.which("redis-cli"):
        return False
    r = run("redis-cli ping")
    if r.returncode == 0 and "PONG" in r.stdout:
        return True
    mkdir(ROOT / "runtime/redis")
    run("redis-server --daemonize yes --bind 127.0.0.1 --port 6379 --dir runtime/redis --save '' --appendonly no >/dev/null 2>&1")
    time.sleep(1)
    r = run("redis-cli ping")
    return r.returncode == 0 and "PONG" in r.stdout

def redis_push(queue, payload):
    if not ensure_redis():
        return False
    raw = json.dumps(payload, ensure_ascii=False)
    r = subprocess.run(["redis-cli", "LPUSH", queue, raw], cwd=ROOT, text=True, capture_output=True)
    return r.returncode == 0

def redis_len(queue):
    if not ensure_redis():
        return 0
    r = subprocess.run(["redis-cli", "LLEN", queue], cwd=ROOT, text=True, capture_output=True)
    try:
        return int((r.stdout or "0").strip())
    except Exception:
        return 0

def default_config():
    return {
        "timestamp": now(),
        "pip_mode_enabled": True,
        "pip_value": 10,
        "paper_trading": True,
        "testnet_mode": True,
        "live_order_gate": "BLOCKED",
        "live_order_requested": False,
        "selected_exchange": "bybit",
        "safety": SAFETY
    }

def load_config():
    cfg = read_json(CONFIG_FILE, None)
    if not isinstance(cfg, dict):
        cfg = default_config()
        write_json(CONFIG_FILE, cfg)
    return cfg

def save_config(cfg):
    cfg["timestamp"] = now()
    cfg["safety"] = SAFETY
    cfg["live_orders_enabled"] = False
    write_json(CONFIG_FILE, cfg)

def mask_value(v):
    if not v:
        return None
    v = str(v)
    if len(v) <= 8:
        return "***"
    return v[:4] + "..." + v[-4:]

def exchange_file(exchange):
    return SECRET_DIR / f"{exchange}.json"

def save_exchange(exchange, api_key, api_secret, testnet=True):
    exchange = exchange.lower().strip()
    if exchange not in ["bybit", "binance"]:
        return {"status": "ERROR", "error": "unknown_exchange"}

    data = {
        "timestamp": now(),
        "exchange": exchange,
        "api_key": api_key.strip(),
        "api_secret": api_secret.strip(),
        "testnet": bool(testnet),
        "live_orders_enabled": False,
        "manual_OWNER_approval_required": True,
        "safety": SAFETY
    }
    write_json(exchange_file(exchange), data, mode=0o600)

    event = {
        "timestamp": now(),
        "status": "EXCHANGE_API_CONFIG_SAVED_LOCAL_ONLY",
        "exchange": exchange,
        "api_key_masked": mask_value(api_key),
        "api_secret_masked": mask_value(api_secret),
        "testnet": bool(testnet),
        "secret_file": str(exchange_file(exchange).relative_to(ROOT)),
        "git_safe": True,
        "safety": SAFETY
    }
    write_json(ACTIONS_DIR / f"{exchange}_api_config_latest.json", event)
    redis_push("cybra:audit:finance", event)
    redis_push("parliament_inbox", event)
    return event

def exchange_status(exchange):
    p = exchange_file(exchange)
    if not p.exists():
        return {
            "configured": False,
            "exchange": exchange,
            "api_key_masked": None,
            "api_secret_masked": None,
            "testnet": True
        }
    data = read_json(p, {})
    return {
        "configured": True,
        "exchange": exchange,
        "api_key_masked": mask_value(data.get("api_key")),
        "api_secret_masked": mask_value(data.get("api_secret")),
        "testnet": data.get("testnet", True),
        "file": str(p.relative_to(ROOT))
    }

def call_supervised(cmd):
    r = run(f"cybra-bot-supervised {cmd}")
    try:
        return json.loads(r.stdout)
    except Exception:
        return {
            "status": "COMMAND_OUTPUT",
            "cmd": f"cybra-bot-supervised {cmd}",
            "stdout": r.stdout[-2000:],
            "stderr": r.stderr[-2000:],
            "returncode": r.returncode
        }

def supervised_status():
    return call_supervised("status")

def supervised_audit():
    return call_supervised("audit")

def audit_recommendations():
    aud = read_json(ROOT / "data/cybra_bot_supervisor/audit/bot_supervision_audit_latest.json", {})
    advice = aud.get("advice")
    if isinstance(advice, list):
        return advice
    return [
        "Запусти аудит: cybra-bot-bar audit",
        "Перевір, що live_orders_enabled=false.",
        "Перевір Bybit/Binance API: ключі тільки локально, не в GitHub.",
        "Перед live-mode потрібен окремий ручний OWNER approval."
    ]

def add_task(title, body):
    task_id = "BOT-BAR-TASK-" + time.strftime("%Y%m%d_%H%M%S")
    task = {
        "task_id": task_id,
        "timestamp": now(),
        "status": "BOT_BAR_TASK_CREATED",
        "title": title or "Bot supervisor task",
        "body": body or "",
        "scope": "BOT_SUPERVISION_IT_CYBERPARLIAMENT",
        "routes": {
            "it_department": True,
            "cyber_parliament": True,
            "finance_audit": True,
            "meta_evolution": True
        },
        "safety": SAFETY
    }
    write_json(ROOT / f"data/cybra_bot_supervisor/tasks/{task_id}.json", task)
    write_json(ROOT / f"data/cybra_finance/it_department/tasks/{task_id}.json", task)
    write_json(ROOT / f"parliament/inbox/{task_id}.json", task)
    for q in QUEUES:
        redis_push(q, task)
    return task

def set_pip(enabled=None, value=None):
    cfg = load_config()
    if enabled is not None:
        cfg["pip_mode_enabled"] = bool(enabled)
    if value is not None:
        try:
            cfg["pip_value"] = int(value)
        except Exception:
            pass
    save_config(cfg)
    event = {
        "timestamp": now(),
        "status": "PIP_MODE_UPDATED",
        "pip_mode_enabled": cfg["pip_mode_enabled"],
        "pip_value": cfg["pip_value"],
        "safety": SAFETY
    }
    write_json(ACTIONS_DIR / "pip_mode_latest.json", event)
    redis_push("cybra:bot:supervised", event)
    return event

def live_order_request():
    cfg = load_config()
    cfg["live_order_gate"] = "REQUESTED_AUDIT_REQUIRED"
    cfg["live_order_requested"] = True
    cfg["live_orders_enabled"] = False
    save_config(cfg)
    event = {
        "timestamp": now(),
        "status": "LIVE_ORDER_REQUEST_CREATED_BUT_NOT_ENABLED",
        "message": "Live-order request created. Real live orders remain blocked until separate OWNER approval and audit.",
        "live_orders_enabled": False,
        "manual_OWNER_approval_required": True,
        "safety": SAFETY
    }
    write_json(ACTIONS_DIR / "live_order_request_latest.json", event)
    redis_push("cybra:audit:finance", event)
    redis_push("parliament_inbox", event)
    return event

def live_order_block():
    cfg = load_config()
    cfg["live_order_gate"] = "BLOCKED"
    cfg["live_order_requested"] = False
    cfg["live_orders_enabled"] = False
    save_config(cfg)
    event = {
        "timestamp": now(),
        "status": "LIVE_ORDER_GATE_BLOCKED",
        "live_orders_enabled": False,
        "safety": SAFETY
    }
    write_json(ACTIONS_DIR / "live_order_block_latest.json", event)
    redis_push("cybra:bot:supervised", event)
    return event

def build_report():
    cfg = load_config()
    st = supervised_status()
    advice = audit_recommendations()
    bybit = exchange_status("bybit")
    binance = exchange_status("binance")

    alive = bool(st.get("alive"))
    supervision = st.get("supervision", {})
    it_active = bool(supervision.get("it_department", True))
    parliament_active = bool(supervision.get("cyber_parliament", True))

    report = {
        "timestamp": now(),
        "status": "CYBRA_BOT_BAR_MENU_OK",
        "bot": {
            "alive": alive,
            "status": st.get("status"),
            "pid": st.get("pid"),
            "bot_file": st.get("bot_file_under_supervision"),
            "harness_file": st.get("harness_file"),
            "risk_scan": st.get("risk_scan", {})
        },
        "supervision": {
            "it_active": it_active,
            "cyber_parliament_active": parliament_active,
            "finance_audit_active": True,
            "redis_monitoring_active": True
        },
        "config": cfg,
        "exchanges": {
            "bybit": bybit,
            "binance": binance
        },
        "queues": {q: redis_len(q) for q in QUEUES},
        "audit_recommendations": advice,
        "safety": SAFETY
    }
    write_json(REPORT_FILE, report)
    write_json(ROOT / "feeds/cybra_bot_bar_menu.json", report)
    save_outputs(report)
    return report

def save_outputs(report):
    menu = {
        "title": "CYBRA Bot Bar Menu",
        "dashboard": "http://127.0.0.1:8800/",
        "commands": [
            "cybra-bot-bar status",
            "cybra-bot-bar audit",
            "cybra-bot-bar start",
            "cybra-bot-bar stop",
            "cybra-bot-bar watchdog",
            "cybra-bot-bar set-pip on 10",
            "cybra-bot-bar set-pip off",
            "cybra-bot-bar live-request",
            "cybra-bot-bar live-block",
            "cybra-bot-bar add-task",
            "cybra-bot-bar configure-bybit",
            "cybra-bot-bar configure-binance",
            "cybra-bot-bar serve 8800"
        ],
        "safety": SAFETY
    }
    write_json(ROOT / "data/cybra_bar/menus/bot_bar_menu.json", menu)

    md = f"""# CYBRA Bot Bar Menu

Status: **{report.get("status")}**

## Bot

- Alive: `{report["bot"]["alive"]}`
- Bot status: `{report["bot"]["status"]}`
- PID: `{report["bot"]["pid"]}`
- Bot file: `{report["bot"]["bot_file"]}`

## Supervision

- IT active: `{report["supervision"]["it_active"]}`
- CyberParliament active: `{report["supervision"]["cyber_parliament_active"]}`
- Finance audit active: `true`

## Switches

- PIP mode: `{report["config"].get("pip_mode_enabled")}`
- PIP value: `{report["config"].get("pip_value")}`
- Live-order gate: `{report["config"].get("live_order_gate")}`
- Live orders enabled: `false`

## Exchanges

- Bybit configured: `{report["exchanges"]["bybit"]["configured"]}`
- Binance configured: `{report["exchanges"]["binance"]["configured"]}`

## Safety

- real_trading_now: false
- live_orders_enabled: false
- automatic_withdrawals: false
- automatic_SWIFT: false
- API keys local only: true
"""
    write_text(ROOT / "posts/cybra_bot_bar_menu.md", md)

    write_text(ROOT / "dashboard/cybra_bot_bar/index.html", make_html(report))

    targets = [
        REPORT_FILE,
        ROOT / "feeds/cybra_bot_bar_menu.json",
        ROOT / "posts/cybra_bot_bar_menu.md",
        ROOT / "dashboard/cybra_bot_bar/index.html",
        ROOT / "data/cybra_bar/menus/bot_bar_menu.json",
        ROOT / "scripts/bot_supervisor/cybra_bot_bar_menu.py",
        ROOT / "cybra-bot-bar"
    ]
    proof = ""
    for p in targets:
        if p.exists():
            proof += f"{sha_file(p)}  {p.relative_to(ROOT)}\n"
    write_text(ROOT / "proofs/cybra_bot_bar_menu.sha256", proof)

def badge(ok, text):
    cls = "green" if ok else "red"
    return f"<span class='{cls}'>{html.escape(str(text))}</span>"

def make_html(report):
    cfg = report["config"]
    bybit = report["exchanges"]["bybit"]
    binance = report["exchanges"]["binance"]
    advice = "".join("<li>"+html.escape(str(x))+"</li>" for x in report["audit_recommendations"])
    qrows = "".join(f"<tr><td><code>{html.escape(q)}</code></td><td>({c})</td></tr>" for q,c in report["queues"].items())

    return f"""<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>CYBRA Bot Bar Menu</title>
<style>
body {{ font-family: system-ui, sans-serif; max-width: 1200px; margin: 28px auto; padding: 20px; }}
.card {{ border:1px solid #ddd; border-radius:14px; padding:16px; margin:14px 0; }}
.red {{ color:#c40000; font-weight:800; }}
.green {{ color:#008a2e; font-weight:800; }}
.yellow {{ color:#a36b00; font-weight:800; }}
.neutral {{ color:#555; font-weight:800; }}
.btn {{ display:inline-block; padding:10px 12px; margin:5px; border:1px solid #999; border-radius:9px; text-decoration:none; }}
input, textarea, select {{ width: 100%; padding: 8px; margin: 4px 0 10px 0; }}
button {{ padding: 10px 12px; }}
table {{ border-collapse: collapse; width:100%; }}
td, th {{ border:1px solid #ddd; padding:8px; }}
code {{ word-break: break-all; }}
</style>
</head>
<body>
<h1>CYBRA Bot Bar Menu</h1>

<div class="card">
<h2>Статус</h2>
<p>Bot працює: {badge(report["bot"]["alive"], report["bot"]["alive"])}</p>
<p>IT-нагляд активний: {badge(report["supervision"]["it_active"], report["supervision"]["it_active"])}</p>
<p>CyberParliament-нагляд активний: {badge(report["supervision"]["cyber_parliament_active"], report["supervision"]["cyber_parliament_active"])}</p>
<p>Audit: {badge(True, "ACTIVE")}</p>
<p>Bot file: <code>{html.escape(str(report["bot"]["bot_file"]))}</code></p>
<p>Risk: <code>{html.escape(str(report["bot"]["risk_scan"].get("risk")))}</code></p>
</div>

<div class="card">
<h2>Кнопки</h2>
<a class="btn green" href="/action?do=start">Start</a>
<a class="btn red" href="/action?do=stop">Stop</a>
<a class="btn yellow" href="/action?do=watchdog">Watchdog</a>
<a class="btn yellow" href="/action?do=audit">Audit</a>
<a class="btn green" href="/action?do=pip_on">PIP ON</a>
<a class="btn neutral" href="/action?do=pip_off">PIP OFF</a>
<a class="btn yellow" href="/action?do=live_request">Live-order request</a>
<a class="btn red" href="/action?do=live_block">Block live-order</a>
<a class="btn" href="/json">JSON</a>
</div>

<div class="card">
<h2>Перемикачі</h2>
<p>PIP mode: <b>{cfg.get("pip_mode_enabled")}</b></p>
<p>PIP value: <b>{cfg.get("pip_value")}</b></p>
<p>Live-order gate: <b>{html.escape(str(cfg.get("live_order_gate")))}</b></p>
<p class="red">Live orders enabled: false</p>
</div>

<div class="card">
<h2>Додати завдання щодо цього бота</h2>
<form method="post" action="/task">
<input name="title" placeholder="Назва завдання">
<textarea name="body" placeholder="Опис завдання"></textarea>
<button type="submit">Додати task в IT + Parliament + Audit</button>
</form>
</div>

<div class="card">
<h2>Bybit API local-only</h2>
<p>Configured: <b>{bybit["configured"]}</b>, Key: <code>{html.escape(str(bybit.get("api_key_masked")))}</code></p>
<form method="post" action="/exchange">
<input type="hidden" name="exchange" value="bybit">
<input name="api_key" placeholder="Bybit API Key">
<input name="api_secret" type="password" placeholder="Bybit API Secret">
<select name="testnet"><option value="true">Testnet / Paper</option><option value="false">Live keys stored, live orders still blocked</option></select>
<button type="submit">Save Bybit локально</button>
</form>
</div>

<div class="card">
<h2>Binance API local-only</h2>
<p>Configured: <b>{binance["configured"]}</b>, Key: <code>{html.escape(str(binance.get("api_key_masked")))}</code></p>
<form method="post" action="/exchange">
<input type="hidden" name="exchange" value="binance">
<input name="api_key" placeholder="Binance API Key">
<input name="api_secret" type="password" placeholder="Binance API Secret">
<select name="testnet"><option value="true">Testnet / Paper</option><option value="false">Live keys stored, live orders still blocked</option></select>
<button type="submit">Save Binance локально</button>
</form>
</div>

<div class="card">
<h2>Audit recommendations</h2>
<ul>{advice}</ul>
</div>

<div class="card">
<h2>Redis queues</h2>
<table><tr><th>Queue</th><th>Load</th></tr>{qrows}</table>
</div>

</body>
</html>
"""

def show_status():
    rep = build_report()
    print(json.dumps(rep, ensure_ascii=False, indent=2))

def cli_configure(exchange):
    print(f"Configure {exchange.upper()} API locally. Do NOT paste secrets into chat.")
    key = input("API Key: ").strip()
    secret = getpass.getpass("API Secret: ").strip()
    testnet_raw = input("Testnet? [Y/n]: ").strip().lower()
    testnet = False if testnet_raw == "n" else True
    print(json.dumps(save_exchange(exchange, key, secret, testnet), ensure_ascii=False, indent=2))
    build_report()

def proof():
    p = ROOT / "proofs/cybra_bot_bar_menu.sha256"
    if not p.exists():
        build_report()
    subprocess.call("sha256sum -c proofs/cybra_bot_bar_menu.sha256", shell=True, cwd=ROOT)

def serve(port):
    class Handler(BaseHTTPRequestHandler):
        def send_data(self, code, data, ctype="text/html; charset=utf-8"):
            raw = data.encode("utf-8") if isinstance(data, str) else data
            self.send_response(code)
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(len(raw)))
            self.end_headers()
            self.wfile.write(raw)

        def read_post(self):
            ln = int(self.headers.get("Content-Length", "0") or "0")
            raw = self.rfile.read(ln).decode("utf-8", errors="ignore")
            return parse_qs(raw)

        def do_GET(self):
            u = urlparse(self.path)
            q = parse_qs(u.query)
            if u.path == "/":
                rep = build_report()
                self.send_data(200, make_html(rep))
            elif u.path == "/json":
                self.send_data(200, json.dumps(build_report(), ensure_ascii=False, indent=2), "application/json; charset=utf-8")
            elif u.path == "/action":
                act = (q.get("do") or [""])[0]
                if act == "start":
                    res = call_supervised("start")
                elif act == "stop":
                    res = call_supervised("stop")
                elif act == "watchdog":
                    res = call_supervised("watchdog")
                elif act == "audit":
                    res = supervised_audit()
                elif act == "pip_on":
                    res = set_pip(True)
                elif act == "pip_off":
                    res = set_pip(False)
                elif act == "live_request":
                    res = live_order_request()
                elif act == "live_block":
                    res = live_order_block()
                else:
                    res = {"status": "UNKNOWN_ACTION", "action": act}
                build_report()
                safe = html.escape(json.dumps(res, ensure_ascii=False, indent=2))
                self.send_data(200, f"<html><body><h2>{html.escape(str(res.get('status')))}</h2><pre>{safe}</pre><p><a href='/'>Назад</a></p></body></html>")
            else:
                self.send_data(404, "not found")

        def do_POST(self):
            if self.path == "/exchange":
                data = self.read_post()
                exchange = (data.get("exchange") or [""])[0]
                key = (data.get("api_key") or [""])[0]
                secret = (data.get("api_secret") or [""])[0]
                testnet = ((data.get("testnet") or ["true"])[0] == "true")
                res = save_exchange(exchange, key, secret, testnet)
                build_report()
                safe = html.escape(json.dumps(res, ensure_ascii=False, indent=2))
                self.send_data(200, f"<html><body><h2>{html.escape(str(res.get('status')))}</h2><pre>{safe}</pre><p><a href='/'>Назад</a></p></body></html>")
            elif self.path == "/task":
                data = self.read_post()
                title = (data.get("title") or [""])[0]
                body = (data.get("body") or [""])[0]
                res = add_task(title, body)
                build_report()
                safe = html.escape(json.dumps(res, ensure_ascii=False, indent=2))
                self.send_data(200, f"<html><body><h2>{html.escape(str(res.get('status')))}</h2><pre>{safe}</pre><p><a href='/'>Назад</a></p></body></html>")
            else:
                self.send_data(404, "not found")

        def log_message(self, fmt, *args):
            return

    print(f"CYBRA Bot Bar Menu: http://127.0.0.1:{port}/")
    HTTPServer(("127.0.0.1", int(port)), Handler).serve_forever()

def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"

    if cmd == "status":
        show_status()
    elif cmd == "start":
        print(json.dumps(call_supervised("start"), ensure_ascii=False, indent=2))
        build_report()
    elif cmd == "stop":
        print(json.dumps(call_supervised("stop"), ensure_ascii=False, indent=2))
        build_report()
    elif cmd == "watchdog":
        print(json.dumps(call_supervised("watchdog"), ensure_ascii=False, indent=2))
        build_report()
    elif cmd == "audit":
        print(json.dumps(supervised_audit(), ensure_ascii=False, indent=2))
        build_report()
    elif cmd == "set-pip":
        val = sys.argv[2].lower() if len(sys.argv) > 2 else "on"
        pip_value = sys.argv[3] if len(sys.argv) > 3 else None
        print(json.dumps(set_pip(val in ["on", "true", "1", "yes"], pip_value), ensure_ascii=False, indent=2))
        build_report()
    elif cmd == "live-request":
        print(json.dumps(live_order_request(), ensure_ascii=False, indent=2))
        build_report()
    elif cmd == "live-block":
        print(json.dumps(live_order_block(), ensure_ascii=False, indent=2))
        build_report()
    elif cmd == "add-task":
        title = " ".join(sys.argv[2:]).strip() or input("Task title: ")
        body = input("Task body: ")
        print(json.dumps(add_task(title, body), ensure_ascii=False, indent=2))
        build_report()
    elif cmd == "configure-bybit":
        cli_configure("bybit")
    elif cmd == "configure-binance":
        cli_configure("binance")
    elif cmd == "proof":
        proof()
    elif cmd == "serve":
        port = sys.argv[2] if len(sys.argv) > 2 else "8800"
        serve(port)
    else:
        print("Commands: status | start | stop | watchdog | audit | set-pip on|off [value] | live-request | live-block | add-task | configure-bybit | configure-binance | proof | serve [port]")

if __name__ == "__main__":
    main()
PY

cat > cybra-bot-bar <<'SH'
#!/usr/bin/env bash
cd "$HOME/CYBRA" || exit 1
python3 scripts/bot_supervisor/cybra_bot_bar_menu.py "$@"
SH

chmod +x scripts/bot_supervisor/cybra_bot_bar_menu.py cybra-bot-bar
ln -sf "$HOME/CYBRA/cybra-bot-bar" "$PREFIX/bin/cybra-bot-bar" 2>/dev/null || true

cybra-bot-bar status
cybra-bot-bar proof
