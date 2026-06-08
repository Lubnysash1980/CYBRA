#!/usr/bin/env python3
import os, sys, json, time, hashlib, subprocess, shutil, signal, html
from pathlib import Path
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs

ROOT = Path.home() / "CYBRA"
PID_FILE = ROOT / "data/cybra_bot_supervisor/pids/bot.pid"
STATUS_FILE = ROOT / "data/cybra_bot_supervisor/reports/supervised_bot_status_latest.json"
LOG_FILE = ROOT / "data/cybra_bot_supervisor/logs/bot_supervised.log"
HARNESS_FILE = ROOT / "data/cybra_bot_supervisor/harness/cybra_bot_paper_harness.mjs"
WATCHDOG_FILE = ROOT / "data/cybra_bot_supervisor/watchdog/watchdog_latest.json"

QUEUES = [
    "it_department",
    "parliament_inbox",
    "cybra:audit:finance",
    "cybra:bot:supervised",
    "cybra:finance:evolution:pool",
    "cybra:meta:evolution:pool"
]

RISK_WORDS = [
    "force_trade", "ultimate_force", "no_window", "active",
    "createorder", "placeorder", "submitorder", "market_order",
    "leverage", "bybit", "api_secret", "api_key",
    "withdraw", "live_orders", "real_trading", "private_key", "mnemonic"
]

SAFETY = {
    "real_payment_now": False,
    "real_trading_now": False,
    "live_orders_enabled": False,
    "paper_trading": True,
    "testnet_mode": True,
    "automatic_external_tx": False,
    "automatic_withdrawals": False,
    "automatic_SWIFT": False,
    "automatic_real_rewards": False,
    "manual_OWNER_approval_required": True,
    "it_supervision_required": True,
    "cyber_parliament_supervision_required": True,
    "do_not_store_secrets_in_git": True,
    "direct_bot_execution_blocked": True,
    "paper_harness_only": True
}

def now():
    return time.strftime("%Y-%m-%dT%H:%M:%S")

def mkdir(p):
    Path(p).mkdir(parents=True, exist_ok=True)

def write_json(path, data):
    p = Path(path)
    mkdir(p.parent)
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")

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

def pid_alive(pid):
    try:
        os.kill(int(pid), 0)
        return True
    except Exception:
        return False

def current_pid():
    if PID_FILE.exists():
        try:
            return int(PID_FILE.read_text().strip())
        except Exception:
            return None
    return None

def find_bot_file():
    env_file = os.environ.get("CYBRA_BOT_FILE", "").strip()
    if env_file:
        p = Path(env_file).expanduser()
        if not p.is_absolute():
            p = ROOT / p
        if p.exists() and p.is_file():
            return p

    candidates = []
    patterns = [
        "**/module_64_part_02_Ultimate_Force_Trade_no_window_ACTIVE.mjs",
        "**/module_64_part_*.mjs",
        "**/run.mjs",
        "**/bot.mjs",
        "**/index.mjs",
        "**/main.mjs"
    ]
    skip = [".git", "node_modules", ".venv", "build/cybra_binary_safe", "data/cybra_bot_supervisor/harness"]

    for pat in patterns:
        for p in ROOT.glob(pat):
            sp = str(p)
            if any(x in sp for x in skip):
                continue
            if p.is_file():
                try:
                    candidates.append((p.stat().st_mtime, p))
                except Exception:
                    pass

    if not candidates:
        return None
    candidates.sort(key=lambda x: x[0], reverse=True)
    return candidates[0][1]

def scan_risk(bot_file):
    if not bot_file or not bot_file.exists():
        return {
            "risk": "NO_BOT_FILE",
            "risk_words": [],
            "secrets_markers_detected": [],
            "file": None,
            "file_sha256": None,
            "file_size": 0,
            "must_run_paper_only": True
        }

    txt = bot_file.read_text(encoding="utf-8", errors="ignore").lower()
    found = [w for w in RISK_WORDS if w.lower() in txt or w.lower() in bot_file.name.lower()]
    secrets = [w for w in ["api_key", "api_secret", "private_key", "seed", "mnemonic", "password"] if w in txt]

    return {
        "risk": "HIGH_TRADING_RISK" if found else "LOW",
        "risk_words": found,
        "secrets_markers_detected": secrets,
        "file": str(bot_file.relative_to(ROOT)),
        "file_sha256": sha_file(bot_file),
        "file_size": bot_file.stat().st_size,
        "must_run_paper_only": True
    }

def create_harness():
    code = '''
const botFile = process.env.CYBRA_BOT_FILE || "NO_BOT_FILE";
const taskId = process.env.CYBRA_TASK_ID || "NO_TASK";
const risk = process.env.CYBRA_RISK || "UNKNOWN";
console.log("=== CYBRA PAPER/TESTNET SUPERVISED HARNESS STARTED ===");
console.log("Task:", taskId);
console.log("Bot file under supervision:", botFile);
console.log("Risk:", risk);
console.log("Mode: PAPER_TESTNET_ONLY");
console.log("Live orders: BLOCKED");
console.log("Withdrawals: BLOCKED");
console.log("SWIFT: BLOCKED");
console.log("Direct bot execution: BLOCKED");
console.log("IT supervision: ACTIVE");
console.log("CyberParliament supervision: ACTIVE");
let tick = 0;
function loop() {
  tick += 1;
  console.log(JSON.stringify({
    timestamp: new Date().toISOString(),
    status: "PAPER_HARNESS_TICK",
    tick,
    taskId,
    botFile,
    risk,
    real_trading_now: false,
    live_orders_enabled: false,
    automatic_withdrawals: false,
    automatic_SWIFT: false,
    direct_bot_execution_blocked: true
  }));
}
loop();
setInterval(loop, 5000);
'''
    write_text(HARNESS_FILE, code)
    return HARNESS_FILE

def create_task(bot_file, risk):
    task_id = "BOT-SUPERVISED-FIXED-" + time.strftime("%Y%m%d_%H%M%S")
    task = {
        "task_id": task_id,
        "timestamp": now(),
        "status": "BOT_SUPERVISION_TASK_CREATED",
        "title": "Bot under IT and CyberParliament supervision",
        "bot_file": str(bot_file.relative_to(ROOT)) if bot_file else None,
        "risk_scan": risk,
        "supervision": {
            "it_department": True,
            "cyber_parliament": True,
            "finance_audit": True,
            "watchdog": True,
            "redis_monitoring": True,
            "dashboard": True
        },
        "required_rules": [
            "paper mode only",
            "testnet mode only",
            "no live orders",
            "no withdrawals",
            "no SWIFT",
            "no real payments",
            "manual OWNER approval required before live mode"
        ],
        "safety": SAFETY
    }

    write_json(ROOT / f"data/cybra_bot_supervisor/tasks/{task_id}.json", task)
    write_json(ROOT / f"data/cybra_finance/it_department/tasks/{task_id}.json", task)
    write_json(ROOT / f"parliament/inbox/{task_id}.json", task)

    for q in QUEUES:
        redis_push(q, task)

    return task

def start():
    old = current_pid()
    if old and pid_alive(old):
        return status({"message": "already running"})

    bot_file = find_bot_file()
    risk = scan_risk(bot_file)
    task = create_task(bot_file, risk)

    if not shutil.which("node"):
        rep = {
            "timestamp": now(),
            "status": "NODE_NOT_FOUND",
            "pid": None,
            "alive": False,
            "task_id": task["task_id"],
            "bot_file_under_supervision": str(bot_file.relative_to(ROOT)) if bot_file else None,
            "risk_scan": risk,
            "safety": SAFETY
        }
        save(rep)
        return rep

    harness = create_harness()
    env = os.environ.copy()
    env.update({
        "CYBRA_SUPERVISED_BY_IT": "true",
        "CYBRA_SUPERVISED_BY_CYBERPARLIAMENT": "true",
        "PAPER_TRADING": "true",
        "BYBIT_TESTNET": "true",
        "TESTNET": "true",
        "DRY_RUN": "true",
        "REAL_TRADING_NOW": "false",
        "LIVE_ORDERS_ENABLED": "false",
        "ALLOW_LIVE_ORDERS": "false",
        "ALLOW_WITHDRAWALS": "false",
        "AUTOMATIC_SWIFT": "false",
        "CYBRA_OWNER_APPROVAL_REQUIRED": "true",
        "CYBRA_BOT_FILE": str(bot_file.relative_to(ROOT)) if bot_file else "NO_BOT_FILE",
        "CYBRA_TASK_ID": task["task_id"],
        "CYBRA_RISK": risk["risk"]
    })

    mkdir(LOG_FILE.parent)
    log = open(LOG_FILE, "a", encoding="utf-8")
    log.write("\\n\\n=== START " + now() + " ===\\n")
    log.write("MODE=PAPER_TESTNET_SUPERVISED\\n")
    log.write("DIRECT BOT EXECUTION BLOCKED\\n")
    log.flush()

    proc = subprocess.Popen(["node", str(harness)], cwd=ROOT, stdout=log, stderr=log, env=env, start_new_session=True)
    write_text(PID_FILE, str(proc.pid))

    rep = {
        "timestamp": now(),
        "status": "BOT_SUPERVISED_HARNESS_STARTED",
        "pid": proc.pid,
        "alive": True,
        "task_id": task["task_id"],
        "bot_file_under_supervision": str(bot_file.relative_to(ROOT)) if bot_file else None,
        "harness_file": str(harness.relative_to(ROOT)),
        "risk_scan": risk,
        "mode": "PAPER_TESTNET_SUPERVISED",
        "log_file": str(LOG_FILE.relative_to(ROOT)),
        "safety": SAFETY
    }
    save(rep)
    return rep

def stop():
    pid = current_pid()
    stopped = False
    if pid and pid_alive(pid):
        try:
            os.killpg(os.getpgid(pid), signal.SIGTERM)
            stopped = True
            time.sleep(1)
        except Exception:
            try:
                os.kill(pid, signal.SIGTERM)
                stopped = True
            except Exception:
                pass

    rep = {
        "timestamp": now(),
        "status": "BOT_SUPERVISOR_STOPPED" if stopped else "BOT_SUPERVISOR_NOT_RUNNING",
        "pid": pid,
        "alive": False,
        "safety": SAFETY
    }
    save(rep)
    return rep

def status(extra=None):
    pid = current_pid()
    alive = pid_alive(pid) if pid else False
    bot_file = find_bot_file()
    risk = scan_risk(bot_file)
    rep = {
        "timestamp": now(),
        "status": "BOT_SUPERVISED_RUNNING" if alive else "BOT_SUPERVISED_NOT_RUNNING",
        "pid": pid,
        "alive": alive,
        "bot_file_under_supervision": str(bot_file.relative_to(ROOT)) if bot_file else None,
        "harness_file": str(HARNESS_FILE.relative_to(ROOT)) if HARNESS_FILE.exists() else None,
        "risk_scan": risk,
        "supervision": {
            "it_department": True,
            "cyber_parliament": True,
            "finance_audit": True,
            "redis_monitoring": True,
            "watchdog": True
        },
        "queues": {q: redis_len(q) for q in QUEUES},
        "log_file": str(LOG_FILE.relative_to(ROOT)),
        "extra": extra or {},
        "safety": SAFETY
    }
    save(rep)
    return rep

def audit():
    rep = status()
    advice = []
    if rep["alive"]:
        advice.append("Супервізор працює. Paper/testnet harness активний.")
    else:
        advice.append("Супервізор не працює. Запуск: cybra-bot-supervised start")
    if rep["risk_scan"].get("risk_words"):
        advice.append("Знайдено trading-risk слова. Прямий live запуск заблокований.")
    if rep["risk_scan"].get("secrets_markers_detected"):
        advice.append("Є маркери секретів. Перевірити, щоб API keys/secrets не пішли в GitHub.")
    advice.append("IT Department і CyberParliament отримали supervision task.")
    advice.append("Реальні ордери, withdrawals, SWIFT, external tx заблоковані.")

    aud = {
        "timestamp": now(),
        "status": "BOT_SUPERVISION_AUDIT_DONE",
        "bot_status": rep,
        "advice": advice,
        "safety": SAFETY
    }
    write_json(ROOT / "data/cybra_bot_supervisor/audit/bot_supervision_audit_latest.json", aud)
    redis_push("cybra:audit:finance", aud)
    redis_push("parliament_inbox", aud)
    save(rep)
    return aud

def watchdog():
    rep = status()
    action = "none"
    if not rep["alive"]:
        action = "restart"
        start()
        rep = status({"watchdog_action": action})
    wd = {
        "timestamp": now(),
        "status": "WATCHDOG_CHECK_DONE",
        "action": action,
        "bot_status": rep,
        "safety": SAFETY
    }
    write_json(WATCHDOG_FILE, wd)
    redis_push("cybra:bot:supervised", wd)
    save(rep)
    return wd

def logs():
    if LOG_FILE.exists():
        return LOG_FILE.read_text(encoding="utf-8", errors="ignore")[-12000:]
    return "No log yet"

def save(rep):
    write_json(STATUS_FILE, rep)
    write_json(ROOT / "feeds/cybra_bot_supervisor.json", rep)

    menu = {
        "title": "CYBRA Bot Supervisor",
        "dashboard": "http://127.0.0.1:8798/",
        "commands": [
            "cybra-bot-supervised start",
            "cybra-bot-supervised status",
            "cybra-bot-supervised audit",
            "cybra-bot-supervised watchdog",
            "cybra-bot-supervised logs",
            "cybra-bot-supervised stop",
            "cybra-bot-supervised proof",
            "cybra-bot-supervised serve 8798"
        ],
        "safety": SAFETY
    }
    write_json(ROOT / "data/cybra_bar/menus/bot_supervisor_menu.json", menu)

    md = f"""# CYBRA Bot Supervisor

Status: **{rep.get("status")}**

PID: `{rep.get("pid")}`
Alive: `{rep.get("alive")}`
Bot file under supervision: `{rep.get("bot_file_under_supervision")}`
Harness file: `{rep.get("harness_file")}`
Mode: `PAPER_TESTNET_SUPERVISED`

## Safety

- real_trading_now: false
- live_orders_enabled: false
- paper_trading: true
- testnet_mode: true
- direct_bot_execution_blocked: true
- manual_OWNER_approval_required: true
"""
    write_text(ROOT / "posts/cybra_bot_supervisor.md", md)

    page = f"""<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>CYBRA Bot Supervisor</title>
<style>
body {{ font-family: system-ui, sans-serif; max-width: 1050px; margin: 30px auto; padding: 20px; }}
.card {{ border: 1px solid #ddd; border-radius: 14px; padding: 16px; margin: 14px 0; }}
.red {{ color: #c40000; font-weight: 800; }}
.green {{ color: #008a2e; font-weight: 800; }}
.btn {{ display:inline-block; padding:10px 12px; margin:5px; border:1px solid #999; border-radius:9px; text-decoration:none; }}
code {{ word-break: break-all; }}
pre {{ white-space: pre-wrap; background:#f6f6f6; padding:12px; border-radius:10px; }}
</style>
</head>
<body>
<h1>CYBRA Bot Supervisor</h1>
<div class="card">
<p>Status: <b>{html.escape(str(rep.get("status")))}</b></p>
<p>PID: <code>{html.escape(str(rep.get("pid")))}</code></p>
<p>Alive: <code>{html.escape(str(rep.get("alive")))}</code></p>
<p>Bot file: <code>{html.escape(str(rep.get("bot_file_under_supervision")))}</code></p>
<p>Harness: <code>{html.escape(str(rep.get("harness_file")))}</code></p>
<p>Mode: <b>PAPER / TESTNET / IT + CYBERPARLIAMENT</b></p>
</div>
<div class="card">
<a class="btn" href="/action?do=start">Start</a>
<a class="btn" href="/action?do=stop">Stop</a>
<a class="btn" href="/action?do=restart">Restart</a>
<a class="btn" href="/action?do=audit">Audit</a>
<a class="btn" href="/action?do=watchdog">Watchdog</a>
<a class="btn" href="/logs">Logs</a>
<a class="btn" href="/json">JSON</a>
</div>
<div class="card">
<p class="red">real_trading_now: false</p>
<p class="red">live_orders_enabled: false</p>
<p class="green">paper_trading: true</p>
<p class="green">testnet_mode: true</p>
<p class="red">direct_bot_execution_blocked: true</p>
</div>
</body>
</html>
"""
    write_text(ROOT / "dashboard/cybra_bot_supervisor/index.html", page)

    targets = [
        STATUS_FILE,
        ROOT / "feeds/cybra_bot_supervisor.json",
        ROOT / "posts/cybra_bot_supervisor.md",
        ROOT / "dashboard/cybra_bot_supervisor/index.html",
        ROOT / "data/cybra_bar/menus/bot_supervisor_menu.json",
        ROOT / "scripts/bot_supervisor/cybra_supervised_bot_runner_fixed.py",
        ROOT / "cybra-bot-supervised"
    ]

    proof = ""
    for p in targets:
        if p.exists():
            proof += f"{sha_file(p)}  {p.relative_to(ROOT)}\n"
    write_text(ROOT / "proofs/cybra_bot_supervisor.sha256", proof)

def proof():
    p = ROOT / "proofs/cybra_bot_supervisor.sha256"
    if not p.exists():
        print("No proof yet. Run status first.")
        return
    subprocess.call("sha256sum -c proofs/cybra_bot_supervisor.sha256", shell=True, cwd=ROOT)

def serve(port):
    class Handler(BaseHTTPRequestHandler):
        def send_data(self, code, data, ctype="text/html; charset=utf-8"):
            raw = data.encode("utf-8") if isinstance(data, str) else data
            self.send_response(code)
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(len(raw)))
            self.end_headers()
            self.wfile.write(raw)

        def do_GET(self):
            u = urlparse(self.path)
            q = parse_qs(u.query)
            if u.path == "/":
                status()
                self.send_data(200, (ROOT / "dashboard/cybra_bot_supervisor/index.html").read_text(encoding="utf-8"))
            elif u.path == "/json":
                self.send_data(200, json.dumps(status(), ensure_ascii=False, indent=2), "application/json; charset=utf-8")
            elif u.path == "/logs":
                safe = logs().replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                self.send_data(200, "<html><body><h1>Logs</h1><pre>" + safe + "</pre><p><a href='/'>Back</a></p></body></html>")
            elif u.path == "/action":
                act = (q.get("do") or [""])[0]
                if act == "start":
                    res = start()
                elif act == "stop":
                    res = stop()
                elif act == "restart":
                    stop()
                    res = start()
                elif act == "audit":
                    res = audit()
                elif act == "watchdog":
                    res = watchdog()
                else:
                    res = {"status": "UNKNOWN_ACTION", "action": act}
                safe = json.dumps(res, ensure_ascii=False, indent=2).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                self.send_data(200, "<html><body><h2>" + html.escape(str(res.get("status"))) + "</h2><pre>" + safe + "</pre><p><a href='/'>Back</a></p></body></html>")
            else:
                self.send_data(404, "not found")

        def log_message(self, fmt, *args):
            return

    print(f"CYBRA Bot Supervisor: http://127.0.0.1:{port}/")
    HTTPServer(("127.0.0.1", int(port)), Handler).serve_forever()

def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "start":
        print(json.dumps(start(), ensure_ascii=False, indent=2))
    elif cmd == "stop":
        print(json.dumps(stop(), ensure_ascii=False, indent=2))
    elif cmd == "restart":
        stop()
        print(json.dumps(start(), ensure_ascii=False, indent=2))
    elif cmd == "status":
        print(json.dumps(status(), ensure_ascii=False, indent=2))
    elif cmd == "audit":
        print(json.dumps(audit(), ensure_ascii=False, indent=2))
    elif cmd == "watchdog":
        print(json.dumps(watchdog(), ensure_ascii=False, indent=2))
    elif cmd == "logs":
        print(logs())
    elif cmd == "proof":
        proof()
    elif cmd == "serve":
        port = sys.argv[2] if len(sys.argv) > 2 else "8798"
        serve(port)
    else:
        print("Commands: start | stop | restart | status | audit | watchdog | logs | proof | serve [port]")

if __name__ == "__main__":
    main()
