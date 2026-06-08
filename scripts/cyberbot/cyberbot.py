#!/usr/bin/env python3
import os, sys, json, time, hashlib, subprocess, shutil, getpass, tarfile, html
from pathlib import Path
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs

ROOT = Path.home() / "CYBRA"
SECRET_DIR = ROOT / ".cybra_local_secret/exchanges"
REPORT = ROOT / "data/cyberbot/reports/cyberbot_status_latest.json"
CONFIG = ROOT / "data/cyberbot/config/cyberbot_config.json"

QUEUES = {
    "it": "it_department",
    "parliament": "parliament_inbox",
    "finance_audit": "cybra:audit:finance",
    "bot": "cybra:bot:supervised",
    "finance": "cybra:finance:evolution:pool",
    "meta": "cybra:meta:evolution:pool",
    "bybit": "cyberbot:bybit",
    "binance": "cyberbot:binance"
}

STANDARD_COMMITTEES = [
    "cyberbot_finance_committee",
    "cyberbot_bybit_committee",
    "cyberbot_binance_committee",
    "cyberbot_api_security_committee",
    "cyberbot_it_rework_committee",
    "cyberbot_parliament_review_committee",
    "cyberbot_risk_audit_committee"
]

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
    "do_not_store_secrets_in_git": True,
    "github_import_safe": True
}

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

def mask(v):
    if not v:
        return None
    v = str(v)
    if len(v) <= 8:
        return "***"
    return v[:4] + "..." + v[-4:]

def secret_file(exchange):
    return SECRET_DIR / f"{exchange}.json"

def exchange_status(exchange):
    p = secret_file(exchange)
    if not p.exists():
        return {
            "exchange": exchange,
            "configured": False,
            "api_key_masked": None,
            "api_secret_masked": None,
            "testnet": True,
            "status": "NOT_CONFIGURED"
        }
    data = read_json(p, {})
    return {
        "exchange": exchange,
        "configured": True,
        "api_key_masked": mask(data.get("api_key")),
        "api_secret_masked": mask(data.get("api_secret")),
        "testnet": bool(data.get("testnet", True)),
        "live_orders_enabled": False,
        "file": str(p.relative_to(ROOT)),
        "status": "CONFIGURED_LOCAL_ONLY"
    }

def save_exchange(exchange, key, secret, testnet=True):
    exchange = exchange.lower().strip()
    if exchange not in ["bybit", "binance"]:
        return {"status": "ERROR", "error": "unknown_exchange"}

    data = {
        "timestamp": now(),
        "exchange": exchange,
        "api_key": key.strip(),
        "api_secret": secret.strip(),
        "testnet": bool(testnet),
        "live_orders_enabled": False,
        "manual_OWNER_approval_required": True,
        "safety": SAFETY
    }
    write_json(secret_file(exchange), data, 0o600)

    event = {
        "timestamp": now(),
        "status": "EXCHANGE_API_CONFIG_SAVED_LOCAL_ONLY",
        "exchange": exchange,
        "api_key_masked": mask(key),
        "api_secret_masked": mask(secret),
        "testnet": bool(testnet),
        "secret_file": str(secret_file(exchange).relative_to(ROOT)),
        "git_safe": True,
        "safety": SAFETY
    }
    write_json(ROOT / f"data/cyberbot/actions/{exchange}_api_config_latest.json", event)
    redis_push(QUEUES["finance_audit"], event)
    redis_push(QUEUES["parliament"], event)
    redis_push(QUEUES[exchange], event)
    return event

def load_config():
    cfg = read_json(CONFIG, None)
    if not isinstance(cfg, dict):
        cfg = {
            "timestamp": now(),
            "pip_mode_enabled": True,
            "pip_value": 10,
            "paper_trading": True,
            "testnet_mode": True,
            "live_order_gate": "BLOCKED",
            "selected_exchange": "bybit",
            "safety": SAFETY
        }
        write_json(CONFIG, cfg)
    return cfg

def save_config(cfg):
    cfg["timestamp"] = now()
    cfg["safety"] = SAFETY
    cfg["live_orders_enabled"] = False
    write_json(CONFIG, cfg)

def call(cmd):
    r = run(cmd)
    try:
        return json.loads(r.stdout)
    except Exception:
        return {
            "cmd": cmd,
            "returncode": r.returncode,
            "stdout": r.stdout[-2500:],
            "stderr": r.stderr[-2500:]
        }

def supervisor_status():
    if shutil.which("cybra-bot-bar"):
        return call("cybra-bot-bar status")
    if shutil.which("cybra-bot-supervised"):
        return call("cybra-bot-supervised status")
    return {"status": "SUPERVISOR_NOT_FOUND", "alive": False}

def supervisor_action(action):
    if shutil.which("cybra-bot-bar"):
        return call(f"cybra-bot-bar {action}")
    if shutil.which("cybra-bot-supervised"):
        return call(f"cybra-bot-supervised {action}")
    return {"status": "SUPERVISOR_NOT_FOUND", "action": action}

def set_pip(enabled=True, value=None):
    cfg = load_config()
    cfg["pip_mode_enabled"] = bool(enabled)
    if value is not None:
        try:
            cfg["pip_value"] = int(value)
        except Exception:
            pass
    save_config(cfg)

    event = {
        "timestamp": now(),
        "status": "CYBERBOT_PIP_UPDATED",
        "pip_mode_enabled": cfg["pip_mode_enabled"],
        "pip_value": cfg["pip_value"],
        "safety": SAFETY
    }
    write_json(ROOT / "data/cyberbot/actions/pip_latest.json", event)
    redis_push(QUEUES["bot"], event)
    return event

def live_request():
    cfg = load_config()
    cfg["live_order_gate"] = "REQUESTED_AUDIT_AND_OWNER_APPROVAL_REQUIRED"
    cfg["live_orders_enabled"] = False
    save_config(cfg)

    event = {
        "timestamp": now(),
        "status": "CYBERBOT_LIVE_ORDER_REQUEST_CREATED_BUT_NOT_ENABLED",
        "live_orders_enabled": False,
        "message": "Live-order request routed to IT + CyberParliament + audit. Real orders remain blocked.",
        "safety": SAFETY
    }
    write_json(ROOT / "data/cyberbot/actions/live_order_request_latest.json", event)
    redis_push(QUEUES["it"], event)
    redis_push(QUEUES["parliament"], event)
    redis_push(QUEUES["finance_audit"], event)
    return event

def live_block():
    cfg = load_config()
    cfg["live_order_gate"] = "BLOCKED"
    cfg["live_orders_enabled"] = False
    save_config(cfg)
    event = {
        "timestamp": now(),
        "status": "CYBERBOT_LIVE_ORDER_GATE_BLOCKED",
        "live_orders_enabled": False,
        "safety": SAFETY
    }
    write_json(ROOT / "data/cyberbot/actions/live_order_block_latest.json", event)
    redis_push(QUEUES["bot"], event)
    return event

def create_task(title, body="", exchange="all"):
    task_id = "CYBERBOT-TASK-" + time.strftime("%Y%m%d_%H%M%S")
    task = {
        "task_id": task_id,
        "timestamp": now(),
        "status": "CYBERBOT_AI_TASK_CREATED",
        "title": title or "Cyberbot task",
        "body": body or "",
        "exchange": exchange,
        "routes": {
            "it_department": True,
            "cyber_parliament": True,
            "finance_audit": True,
            "meta_evolution": True,
            "bybit": exchange in ["all", "bybit"],
            "binance": exchange in ["all", "binance"]
        },
        "safety": SAFETY
    }
    write_json(ROOT / f"data/cyberbot/tasks/{task_id}.json", task)
    write_json(ROOT / f"data/cybra_finance/it_department/tasks/{task_id}.json", task)
    write_json(ROOT / f"parliament/inbox/{task_id}.json", task)

    for q in [QUEUES["it"], QUEUES["parliament"], QUEUES["finance_audit"], QUEUES["meta"], QUEUES["bot"]]:
        redis_push(q, task)
    if exchange in ["all", "bybit"]:
        redis_push(QUEUES["bybit"], task)
    if exchange in ["all", "binance"]:
        redis_push(QUEUES["binance"], task)

    return task

def add_committee(name):
    name = "".join(ch if ch.isalnum() or ch in "_-" else "_" for ch in str(name).strip()) or "cyberbot_custom_committee"
    data = {
        "timestamp": now(),
        "status": "CYBERBOT_COMMITTEE_CREATED",
        "committee": name,
        "scope": "Cyberbot Bybit Binance IT Parliament",
        "safety": SAFETY
    }
    path = ROOT / "parliament/committees" / name / "committee.json"
    write_json(path, data)
    write_json(ROOT / f"data/cyberbot/committees/{name}.json", data)
    redis_push(f"cybra:committee:{name}", data)
    redis_push(QUEUES["parliament"], data)
    return data

def add_standard_committees():
    out = [add_committee(x) for x in STANDARD_COMMITTEES]
    return {
        "timestamp": now(),
        "status": "CYBERBOT_STANDARD_COMMITTEES_CREATED",
        "count": len(out),
        "committees": out,
        "safety": SAFETY
    }

def audit():
    st = build_status(save=False)
    advice = []
    if not st["bot"]["alive"]:
        advice.append("Supervisor не працює. Запуск: cyberbot start")
    else:
        advice.append("Supervisor працює під IT + CyberParliament.")

    if not st["exchanges"]["bybit"]["configured"]:
        advice.append("Bybit API не налаштований. Команда: cyberbot configure bybit")
    if not st["exchanges"]["binance"]["configured"]:
        advice.append("Binance API не налаштований. Команда: cyberbot configure binance")

    advice.append("Live orders залишаються blocked. Для live потрібен окремий OWNER approval.")
    advice.append("API ключі зберігаються тільки локально в .cybra_local_secret і не йдуть у GitHub.")
    advice.append("AI-задачі можна відправляти в IT, Parliament, audit і committees командою cyberbot task.")

    aud = {
        "timestamp": now(),
        "status": "CYBERBOT_AUDIT_DONE",
        "status_report": st,
        "advice": advice,
        "safety": SAFETY
    }
    write_json(ROOT / "data/cyberbot/audit/cyberbot_audit_latest.json", aud)
    redis_push(QUEUES["finance_audit"], aud)
    redis_push(QUEUES["parliament"], aud)
    save_outputs(st, advice)
    return aud

def build_status(save=True):
    cfg = load_config()
    sup = supervisor_status()

    alive = False
    if isinstance(sup, dict):
        alive = bool(sup.get("alive") or sup.get("bot", {}).get("alive"))

    bot_file = None
    if isinstance(sup, dict):
        bot_file = sup.get("bot_file_under_supervision") or sup.get("bot", {}).get("bot_file")

    risk_scan = {}
    if isinstance(sup, dict):
        risk_scan = sup.get("risk_scan") or sup.get("bot", {}).get("risk_scan") or {}

    report = {
        "timestamp": now(),
        "status": "CYBERBOT_STATUS_OK",
        "bot": {
            "alive": alive,
            "supervisor_status": sup.get("status") if isinstance(sup, dict) else "UNKNOWN",
            "bot_file": bot_file,
            "risk_scan": risk_scan
        },
        "supervision": {
            "it_active": True,
            "cyber_parliament_active": True,
            "finance_audit_active": True,
            "redis_monitoring_active": ensure_redis()
        },
        "exchanges": {
            "bybit": exchange_status("bybit"),
            "binance": exchange_status("binance")
        },
        "config": cfg,
        "queues": {k: {"redis_key": q, "load": redis_len(q)} for k, q in QUEUES.items()},
        "safety": SAFETY
    }
    if save:
        save_outputs(report)
    return report

def save_outputs(report, advice=None):
    advice = advice or [
        "Перевірити Bybit/Binance API status.",
        "Створювати AI tasks для IT + Parliament.",
        "Live orders blocked до окремого OWNER approval.",
        "Для іншого пристрою використовувати Cyberbot GitHub import."
    ]

    write_json(REPORT, report)
    write_json(ROOT / "feeds/cyberbot_status.json", report)

    menu = {
        "title": "Cyberbot Bar Menu",
        "github_import_command": "curl -fsSL https://raw.githubusercontent.com/Lubnysash1980/CYBRA/main/install_cyberbot_import_bar_menu.sh | bash",
        "commands": [
            "cyberbot status",
            "cyberbot menu",
            "cyberbot start",
            "cyberbot stop",
            "cyberbot audit",
            "cyberbot configure bybit",
            "cyberbot configure binance",
            "cyberbot set-pip on 10",
            "cyberbot live-request",
            "cyberbot live-block",
            "cyberbot task",
            "cyberbot committees",
            "cyberbot patch",
            "cyberbot serve 8802"
        ],
        "safety": SAFETY
    }
    write_json(ROOT / "data/cybra_bar/menus/cyberbot_menu.json", menu)

    md = f"""# Cyberbot

Status: **{report.get("status")}**

## Bot

- Alive: `{report["bot"]["alive"]}`
- Supervisor: `{report["bot"]["supervisor_status"]}`
- Bot file: `{report["bot"]["bot_file"]}`

## Exchanges

- Bybit configured: `{report["exchanges"]["bybit"]["configured"]}`
- Binance configured: `{report["exchanges"]["binance"]["configured"]}`

## Supervision

- IT active: true
- CyberParliament active: true
- Finance audit active: true

## Switches

- PIP mode: `{report["config"].get("pip_mode_enabled")}`
- PIP value: `{report["config"].get("pip_value")}`
- Live-order gate: `{report["config"].get("live_order_gate")}`
- Live orders enabled: false

## Safety

- real_trading_now: false
- live_orders_enabled: false
- API keys local only: true
"""
    write_text(ROOT / "posts/cyberbot_status.md", md)
    write_text(ROOT / "dashboard/cyberbot/index.html", make_html(report, advice))

    targets = [
        REPORT,
        ROOT / "feeds/cyberbot_status.json",
        ROOT / "posts/cyberbot_status.md",
        ROOT / "dashboard/cyberbot/index.html",
        ROOT / "data/cybra_bar/menus/cyberbot_menu.json",
        ROOT / "scripts/cyberbot/cyberbot.py",
        ROOT / "cyberbot",
        ROOT / "Cyberbot",
        ROOT / "cyberbot-menu"
    ]
    proof = ""
    for p in targets:
        if p.exists():
            proof += f"{sha_file(p)}  {p.relative_to(ROOT)}\n"
    write_text(ROOT / "proofs/cyberbot_status.sha256", proof)

def make_html(report, advice):
    qrows = "".join(f"<tr><td>{html.escape(k)}</td><td><code>{html.escape(v['redis_key'])}</code></td><td>({v['load']})</td></tr>" for k, v in report["queues"].items())
    adv = "".join("<li>"+html.escape(str(x))+"</li>" for x in advice)
    return f"""<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>Cyberbot</title>
<style>
body {{ font-family: system-ui, sans-serif; max-width: 1200px; margin: 28px auto; padding: 20px; }}
.card {{ border:1px solid #ddd; border-radius:14px; padding:16px; margin:14px 0; }}
.red {{ color:#c40000; font-weight:800; }}
.green {{ color:#008a2e; font-weight:800; }}
.btn {{ display:inline-block; padding:10px 12px; margin:5px; border:1px solid #999; border-radius:9px; text-decoration:none; }}
input, textarea, select {{ width:100%; padding:8px; margin:4px 0 10px 0; }}
table {{ border-collapse: collapse; width:100%; }}
td, th {{ border:1px solid #ddd; padding:8px; }}
code {{ word-break: break-all; }}
</style>
</head>
<body>
<h1>Cyberbot Bar Menu</h1>

<div class="card">
<p>Bot alive: <b>{report["bot"]["alive"]}</b></p>
<p>IT active: <b>true</b></p>
<p>CyberParliament active: <b>true</b></p>
<p>Bybit: <b>{report["exchanges"]["bybit"]["configured"]}</b></p>
<p>Binance: <b>{report["exchanges"]["binance"]["configured"]}</b></p>
<p class="red">Live orders enabled: false</p>
</div>

<div class="card">
<a class="btn green" href="/action?do=start">Start</a>
<a class="btn red" href="/action?do=stop">Stop</a>
<a class="btn" href="/action?do=audit">Audit</a>
<a class="btn" href="/action?do=committees">Standard committees</a>
<a class="btn" href="/action?do=pip_on">PIP ON</a>
<a class="btn" href="/action?do=pip_off">PIP OFF</a>
<a class="btn red" href="/action?do=live_block">Block live</a>
<a class="btn" href="/action?do=live_request">Live request</a>
<a class="btn" href="/json">JSON</a>
</div>

<div class="card">
<h2>Create AI task</h2>
<form method="post" action="/task">
<input name="title" placeholder="Task title">
<textarea name="body" placeholder="Task body"></textarea>
<select name="exchange"><option value="all">all</option><option value="bybit">bybit</option><option value="binance">binance</option></select>
<button type="submit">Send to IT + Parliament + audit</button>
</form>
</div>

<div class="card">
<h2>Bybit local API</h2>
<p>Key: <code>{html.escape(str(report["exchanges"]["bybit"].get("api_key_masked")))}</code></p>
<form method="post" action="/exchange">
<input type="hidden" name="exchange" value="bybit">
<input name="api_key" placeholder="Bybit API Key">
<input name="api_secret" type="password" placeholder="Bybit API Secret">
<select name="testnet"><option value="true">Testnet/Paper</option><option value="false">Live key stored, live orders blocked</option></select>
<button type="submit">Save Bybit local-only</button>
</form>
</div>

<div class="card">
<h2>Binance local API</h2>
<p>Key: <code>{html.escape(str(report["exchanges"]["binance"].get("api_key_masked")))}</code></p>
<form method="post" action="/exchange">
<input type="hidden" name="exchange" value="binance">
<input name="api_key" placeholder="Binance API Key">
<input name="api_secret" type="password" placeholder="Binance API Secret">
<select name="testnet"><option value="true">Testnet/Paper</option><option value="false">Live key stored, live orders blocked</option></select>
<button type="submit">Save Binance local-only</button>
</form>
</div>

<div class="card">
<h2>Audit advice</h2>
<ul>{adv}</ul>
</div>

<table><tr><th>Queue</th><th>Redis</th><th>Load</th></tr>{qrows}</table>
</body>
</html>
"""

def cli_configure(exchange):
    print(f"Configure {exchange.upper()} API locally. Do not paste secrets into chat.")
    key = input("API Key: ").strip()
    secret = getpass.getpass("API Secret: ").strip()
    testnet_raw = input("Testnet? [Y/n]: ").strip().lower()
    testnet = False if testnet_raw == "n" else True
    print(json.dumps(save_exchange(exchange, key, secret, testnet), ensure_ascii=False, indent=2))
    build_status()

def terminal_menu():
    while True:
        st = build_status()
        print("\n=== CYBERBOT MENU ===")
        print(f"Bot alive: {st['bot']['alive']}")
        print(f"Bybit configured: {st['exchanges']['bybit']['configured']}")
        print(f"Binance configured: {st['exchanges']['binance']['configured']}")
        print(f"PIP: {st['config'].get('pip_mode_enabled')} value={st['config'].get('pip_value')}")
        print(f"Live gate: {st['config'].get('live_order_gate')} / enabled=false")
        print("1) status")
        print("2) start supervisor")
        print("3) stop supervisor")
        print("4) audit")
        print("5) configure Bybit")
        print("6) configure Binance")
        print("7) PIP ON")
        print("8) PIP OFF")
        print("9) create AI task")
        print("10) standard committees")
        print("11) live request")
        print("12) live block")
        print("13) patch for another device")
        print("0) exit")
        c = input("Choose: ").strip()
        if c == "1":
            print(json.dumps(build_status(), ensure_ascii=False, indent=2))
        elif c == "2":
            print(json.dumps(supervisor_action("start"), ensure_ascii=False, indent=2))
        elif c == "3":
            print(json.dumps(supervisor_action("stop"), ensure_ascii=False, indent=2))
        elif c == "4":
            print(json.dumps(audit(), ensure_ascii=False, indent=2))
        elif c == "5":
            cli_configure("bybit")
        elif c == "6":
            cli_configure("binance")
        elif c == "7":
            print(json.dumps(set_pip(True, 10), ensure_ascii=False, indent=2))
        elif c == "8":
            print(json.dumps(set_pip(False), ensure_ascii=False, indent=2))
        elif c == "9":
            title = input("Task title: ")
            body = input("Task body: ")
            print(json.dumps(create_task(title, body), ensure_ascii=False, indent=2))
        elif c == "10":
            print(json.dumps(add_standard_committees(), ensure_ascii=False, indent=2))
        elif c == "11":
            print(json.dumps(live_request(), ensure_ascii=False, indent=2))
        elif c == "12":
            print(json.dumps(live_block(), ensure_ascii=False, indent=2))
        elif c == "13":
            print(json.dumps(make_patch(), ensure_ascii=False, indent=2))
        elif c == "0":
            break

def make_patch():
    patch_dir = ROOT / "data/cyberbot/patches"
    mkdir(patch_dir)
    ts = time.strftime("%Y%m%d_%H%M%S")
    patch = patch_dir / f"cyberbot_patch_{ts}.tar.gz"

    safe = [
        "install_cyberbot_import_bar_menu.sh",
        "scripts/cyberbot",
        "cyberbot",
        "Cyberbot",
        "cyberbot-menu",
        "data/cybra_bar/menus/cyberbot_menu.json",
        "posts/cyberbot_status.md",
        "feeds/cyberbot_status.json",
        "dashboard/cyberbot",
        "proofs/cyberbot_status.sha256"
    ]

    with tarfile.open(patch, "w:gz") as tar:
        for relp in safe:
            p = ROOT / relp
            if not p.exists():
                continue
            if p.is_file():
                tar.add(p, arcname=relp)
            else:
                for child in p.rglob("*"):
                    if child.is_file() and ".cybra_local_secret" not in str(child):
                        tar.add(child, arcname=str(child.relative_to(ROOT)))

    info = {
        "timestamp": now(),
        "status": "CYBERBOT_PATCH_CREATED",
        "patch_file": str(patch.relative_to(ROOT)),
        "sha256": sha_file(patch),
        "secret_included": False,
        "safety": SAFETY
    }
    write_json(ROOT / "data/cyberbot/reports/cyberbot_patch_latest.json", info)
    return info

def github_import_file():
    text = """#!/usr/bin/env bash
set +e
cd "$HOME" || exit 1
if [ ! -d CYBRA/.git ]; then
  git clone git@github.com:Lubnysash1980/CYBRA.git CYBRA || git clone https://github.com/Lubnysash1980/CYBRA.git CYBRA
fi
cd "$HOME/CYBRA" || exit 1
git pull --rebase origin main || true
bash install_cyberbot_import_bar_menu.sh
cyberbot status
"""
    p = ROOT / "cyberbot-import-from-github.sh"
    write_text(p, text)
    try:
        os.chmod(p, 0o755)
    except Exception:
        pass
    return p

def proof():
    if not (ROOT / "proofs/cyberbot_status.sha256").exists():
        build_status()
    subprocess.call("sha256sum -c proofs/cyberbot_status.sha256", shell=True, cwd=ROOT)

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
                self.send_data(200, make_html(build_status(), ["Cyberbot ready."]))
            elif u.path == "/json":
                self.send_data(200, json.dumps(build_status(), ensure_ascii=False, indent=2), "application/json; charset=utf-8")
            elif u.path == "/action":
                act = (q.get("do") or [""])[0]
                if act == "start":
                    res = supervisor_action("start")
                elif act == "stop":
                    res = supervisor_action("stop")
                elif act == "audit":
                    res = audit()
                elif act == "committees":
                    res = add_standard_committees()
                elif act == "pip_on":
                    res = set_pip(True, 10)
                elif act == "pip_off":
                    res = set_pip(False)
                elif act == "live_request":
                    res = live_request()
                elif act == "live_block":
                    res = live_block()
                else:
                    res = {"status": "UNKNOWN_ACTION", "action": act}
                safe = html.escape(json.dumps(res, ensure_ascii=False, indent=2))
                self.send_data(200, f"<html><body><h2>{html.escape(str(res.get('status')))}</h2><pre>{safe}</pre><p><a href='/'>Назад</a></p></body></html>")
            else:
                self.send_data(404, "not found")

        def do_POST(self):
            data = self.read_post()
            if self.path == "/exchange":
                exchange = (data.get("exchange") or [""])[0]
                key = (data.get("api_key") or [""])[0]
                secret = (data.get("api_secret") or [""])[0]
                testnet = ((data.get("testnet") or ["true"])[0] == "true")
                res = save_exchange(exchange, key, secret, testnet)
            elif self.path == "/task":
                title = (data.get("title") or [""])[0]
                body = (data.get("body") or [""])[0]
                exchange = (data.get("exchange") or ["all"])[0]
                res = create_task(title, body, exchange)
            else:
                res = {"status": "UNKNOWN_POST"}
            build_status()
            safe = html.escape(json.dumps(res, ensure_ascii=False, indent=2))
            self.send_data(200, f"<html><body><h2>{html.escape(str(res.get('status')))}</h2><pre>{safe}</pre><p><a href='/'>Назад</a></p></body></html>")

        def log_message(self, fmt, *args):
            return

    print(f"Cyberbot dashboard: http://127.0.0.1:{port}/")
    HTTPServer(("127.0.0.1", int(port)), Handler).serve_forever()

def git_commit():
    github_import_file()
    build_status()
    cmd = """
git add -f install_cyberbot_import_bar_menu.sh cyberbot-import-from-github.sh scripts/cyberbot/cyberbot.py cyberbot Cyberbot cyberbot-menu data/cyberbot data/cybra_bar/menus/cyberbot_menu.json data/cybra_finance/it_department/tasks parliament/inbox parliament/committees posts/cyberbot_status.md feeds/cyberbot_status.json dashboard/cyberbot proofs/cyberbot_status.sha256 .gitignore
git commit -m 'add Cyberbot GitHub import bar menu for Bybit Binance' || true
git pull --rebase --autostash origin main || true
git push origin main || true
"""
    r = run(cmd)
    return {
        "status": "GIT_COMMIT_PUSH_ATTEMPTED",
        "stdout": r.stdout[-4000:],
        "stderr": r.stderr[-4000:],
        "returncode": r.returncode
    }

def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"

    if cmd == "status":
        print(json.dumps(build_status(), ensure_ascii=False, indent=2))
    elif cmd == "menu":
        terminal_menu()
    elif cmd == "start":
        print(json.dumps(supervisor_action("start"), ensure_ascii=False, indent=2)); build_status()
    elif cmd == "stop":
        print(json.dumps(supervisor_action("stop"), ensure_ascii=False, indent=2)); build_status()
    elif cmd == "audit":
        print(json.dumps(audit(), ensure_ascii=False, indent=2))
    elif cmd == "configure":
        exchange = sys.argv[2] if len(sys.argv) > 2 else "bybit"
        cli_configure(exchange)
    elif cmd == "set-pip":
        val = sys.argv[2].lower() if len(sys.argv) > 2 else "on"
        pip_value = sys.argv[3] if len(sys.argv) > 3 else None
        print(json.dumps(set_pip(val in ["on", "true", "1", "yes"], pip_value), ensure_ascii=False, indent=2)); build_status()
    elif cmd == "live-request":
        print(json.dumps(live_request(), ensure_ascii=False, indent=2)); build_status()
    elif cmd == "live-block":
        print(json.dumps(live_block(), ensure_ascii=False, indent=2)); build_status()
    elif cmd == "task":
        title = " ".join(sys.argv[2:]).strip() or input("Task title: ")
        body = input("Task body: ")
        print(json.dumps(create_task(title, body), ensure_ascii=False, indent=2)); build_status()
    elif cmd == "committee":
        name = sys.argv[2] if len(sys.argv) > 2 else input("Committee name: ")
        print(json.dumps(add_committee(name), ensure_ascii=False, indent=2)); build_status()
    elif cmd == "committees":
        print(json.dumps(add_standard_committees(), ensure_ascii=False, indent=2)); build_status()
    elif cmd == "patch":
        print(json.dumps(make_patch(), ensure_ascii=False, indent=2))
    elif cmd == "import-file":
        print(str(github_import_file()))
    elif cmd == "git-commit":
        print(json.dumps(git_commit(), ensure_ascii=False, indent=2))
    elif cmd == "proof":
        proof()
    elif cmd == "serve":
        port = sys.argv[2] if len(sys.argv) > 2 else "8802"
        serve(port)
    else:
        print("Commands: status | menu | start | stop | audit | configure bybit|binance | set-pip on|off [value] | live-request | live-block | task | committee NAME | committees | patch | import-file | git-commit | proof | serve [port]")

if __name__ == "__main__":
    main()
