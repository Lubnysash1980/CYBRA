#!/usr/bin/env python3
import os, sys, json, time, hashlib, subprocess, shutil, html
from pathlib import Path
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs

ROOT = Path.home() / "CYBRA"

SAFETY = {
    "real_payment_now": False,
    "real_trading_now": False,
    "automatic_external_tx": False,
    "automatic_withdrawals": False,
    "automatic_SWIFT": False,
    "automatic_real_rewards": False,
    "external_bridge_enabled": False,
    "dashboard_actions_are_internal_only": True
}

BRANCHES = {
    "finance": {
        "name": "FINANCE / фінансові задачі",
        "description": "банк, PSP, токени, proof, KIBRA finance",
        "pending": ["cybra:finance:evolution:pool", "cybra_finance_evolution"],
        "running": ["cybra:branch:finance:running"],
        "done": ["cybra:branch:finance:done", "cybra:completed:ai_tasks"],
        "returned": ["cybra:branch:finance:return", "cybra:return:ai_tasks"],
        "audit": ["cybra:branch:finance:audit", "cybra:audit:finance"],
        "process_patterns": ["finance", "cybra_finance", "kibra"],
        "expected_processes": 1,
        "storage": ["data/cybra_finance/it_department/tasks", "data/cybra_finance/reports", "data/cybra_proof_department"]
    },
    "meta": {
        "name": "META EVOLUTION / еволюція",
        "description": "екосистема задач, layers, AI-blocks, committees",
        "pending": ["cybra:meta:evolution:pool"],
        "running": ["cybra:branch:meta:running"],
        "done": ["cybra:branch:meta:done", "cybra:completed:ai_tasks"],
        "returned": ["cybra:branch:meta:return", "cybra:return:ai_tasks"],
        "audit": ["cybra:branch:meta:audit", "cybra:audit:meta"],
        "process_patterns": ["meta_evolution", "cybra-meta-evo"],
        "expected_processes": 1,
        "storage": ["data/cybra_meta_evolution/modules", "data/cybra_meta_evolution/blocks", "data/cybra_meta_evolution/reports"]
    },
    "kibra": {
        "name": "KIBRA POOLS / монета і пули",
        "description": "mining queue, task blocks, KIBRA chain",
        "pending": ["cybra:kibra:pool:mining_blocks", "cybra:ai:tasks:block_inbox", "ai_block_inbox"],
        "running": ["cybra:branch:kibra:running"],
        "done": ["cybra:branch:kibra:done"],
        "returned": ["cybra:branch:kibra:return"],
        "audit": ["cybra:branch:kibra:audit", "cybra:audit:kibra"],
        "process_patterns": ["kibra", "miner", "redis-server"],
        "expected_processes": 1,
        "storage": ["blockchain/kibra_chain/task_blocks", "blockchain/kibra_chain/mainnet", "blockchain/kibra_chain/meta_evolution_blocks"]
    },
    "structure": {
        "name": "IT STRUCTURE / структура",
        "description": "структура, binary-safe, proof, автозбір",
        "pending": ["it_department", "cybra_mgs_all"],
        "running": ["cybra:branch:structure:running"],
        "done": ["cybra:branch:structure:done"],
        "returned": ["cybra:branch:structure:return"],
        "audit": ["cybra:branch:structure:audit", "cybra:audit:structure"],
        "process_patterns": ["cybra-structure", "structure", "binary"],
        "expected_processes": 1,
        "storage": ["data/cybra_structure_autocollector", "data/cybra_binary_safe", "build/cybra_binary_safe"]
    },
    "oracle": {
        "name": "ORACLE / CODESPACE",
        "description": "Oracle VPS, Codespace, remote workers",
        "pending": ["cybra_oracle_tasks", "cybra_codespace_inbox"],
        "running": ["cybra:branch:oracle:running"],
        "done": ["cybra:branch:oracle:done"],
        "returned": ["cybra:branch:oracle:return"],
        "audit": ["cybra:branch:oracle:audit", "cybra:audit:oracle"],
        "process_patterns": ["oracle", "ssh", "codespace"],
        "expected_processes": 1,
        "storage": ["data/cybra_oracle/tasks", "scripts/oracle", ".github/workflows"]
    },
    "parliament": {
        "name": "CYBER PARLIAMENT / парламент",
        "description": "комітети, голосування, review, approval",
        "pending": ["parliament_inbox"],
        "running": ["cybra:branch:parliament:running"],
        "done": ["cybra:branch:parliament:done"],
        "returned": ["cybra:branch:parliament:return"],
        "audit": ["cybra:branch:parliament:audit", "cybra:audit:parliament"],
        "process_patterns": ["parliament", "uvicorn"],
        "expected_processes": 1,
        "storage": ["parliament", "posts", "feeds"]
    }
}

RED = "\033[91m"
GREEN = "\033[92m"
YELLOW = "\033[93m"
GRAY = "\033[90m"
BOLD = "\033[1m"
RESET = "\033[0m"

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

def redis_llen(queue):
    if not shutil.which("redis-cli"):
        return 0
    r = subprocess.run(["redis-cli", "LLEN", queue], cwd=ROOT, text=True, capture_output=True)
    try:
        return int((r.stdout or "0").strip())
    except Exception:
        return 0

def redis_lpush(queue, payload):
    if not shutil.which("redis-cli"):
        return False
    raw = json.dumps(payload, ensure_ascii=False)
    r = subprocess.run(["redis-cli", "LPUSH", queue, raw], cwd=ROOT, text=True, capture_output=True)
    return r.returncode == 0

def count_files(path):
    p = ROOT / path
    if not p.exists():
        return 0
    return len([x for x in p.rglob("*.json") if x.is_file()])

def ps_text():
    r = run("ps -A 2>/dev/null || ps 2>/dev/null")
    return ((r.stdout or "") + "\n" + (r.stderr or "")).lower()

def count_processes_for_branch(branch, text):
    total = 0
    details = {}
    for pat in branch["process_patterns"]:
        c = text.count(pat.lower())
        details[pat] = c
        total += c
    return total, details

def git_status():
    if not (ROOT / ".git").exists():
        return {"repo": False, "branch": None, "dirty_files": 0}
    branch = run("git branch --show-current").stdout.strip()
    dirty = len(run("git status --porcelain").stdout.splitlines())
    return {"repo": True, "branch": branch, "dirty_files": dirty}

def status_word(pending, running, done, returned):
    if pending > 0 or returned > 0:
        return "НЕВИКОНАНЕ"
    if running > 0:
        return "ВИКОНУЄТЬСЯ"
    if done > 0:
        return "ВИКОНАНЕ"
    return "НЕЙТРАЛЬНО"

def terminal_color(word, text):
    if word == "НЕВИКОНАНЕ":
        return RED + text + RESET
    if word == "ВИКОНУЄТЬСЯ":
        return GREEN + text + RESET
    if word == "ВИКОНАНЕ":
        return GRAY + text + RESET
    return YELLOW + text + RESET

def css_class(word):
    if word == "НЕВИКОНАНЕ":
        return "red"
    if word == "ВИКОНУЄТЬСЯ":
        return "green"
    if word == "ВИКОНАНЕ":
        return "neutral"
    return "yellow"

def load_percent(pending, running, returned, missing_proc):
    raw = pending * 12 + returned * 15 + running * 6 + missing_proc * 20
    return max(0, min(100, raw))

def collect():
    redis_ok = ensure_redis()
    text = ps_text()
    git = git_status()

    branches = {}
    totals = {
        "pending": 0,
        "running": 0,
        "done": 0,
        "returned": 0,
        "audit": 0,
        "process_running": 0,
        "process_missing": 0
    }

    for slug, cfg in BRANCHES.items():
        pending_counts = {q: redis_llen(q) for q in cfg["pending"]}
        running_queue_counts = {q: redis_llen(q) for q in cfg["running"]}
        done_counts = {q: redis_llen(q) for q in cfg["done"]}
        returned_counts = {q: redis_llen(q) for q in cfg["returned"]}
        audit_counts = {q: redis_llen(q) for q in cfg["audit"]}

        pending = sum(pending_counts.values())
        running_queue = sum(running_queue_counts.values())
        done = sum(done_counts.values())
        returned = sum(returned_counts.values())
        audit = sum(audit_counts.values())

        process_running, process_details = count_processes_for_branch(cfg, text)
        expected = cfg["expected_processes"]
        process_missing = max(0, expected - process_running)

        storage_counts = {p: count_files(p) for p in cfg["storage"]}
        storage_total = sum(storage_counts.values())

        running_total = running_queue + process_running
        word = status_word(pending, running_total, done, returned)
        load = load_percent(pending, running_total, returned, process_missing)

        branches[slug] = {
            "slug": slug,
            "name": cfg["name"],
            "description": cfg["description"],
            "status": word,
            "pending": pending,
            "running": running_total,
            "running_queue": running_queue,
            "done": done,
            "returned": returned,
            "audit": audit,
            "process_running": process_running,
            "process_missing": process_missing,
            "process_expected": expected,
            "process_details": process_details,
            "load_percent": load,
            "pending_queues": pending_counts,
            "running_queues": running_queue_counts,
            "done_queues": done_counts,
            "returned_queues": returned_counts,
            "audit_queues": audit_counts,
            "storage_total": storage_total,
            "storage_counts": storage_counts
        }

        for k in totals:
            if k in branches[slug]:
                totals[k] += branches[slug][k]

    report = {
        "timestamp": now(),
        "status": "CYBRA_BRANCH_LOAD_MONITOR_OK",
        "redis_ok": redis_ok,
        "git": git,
        "totals": totals,
        "branches": branches,
        "legend": {
            "red": "НЕВИКОНАНЕ / pending / returned",
            "green": "ВИКОНУЄТЬСЯ / running / process active",
            "neutral": "ВИКОНАНЕ / done",
            "yellow": "НЕЙТРАЛЬНО / no active load"
        },
        "safety": SAFETY
    }

    return report

def make_terminal(report):
    lines = []
    t = report["totals"]
    git = report["git"]

    lines.append(BOLD + "=== CYBRA BRANCH LOAD MONITOR V2 ===" + RESET)
    lines.append(f"Time: {report['timestamp']}")
    lines.append(f"Redis: {GREEN + 'OK' + RESET if report['redis_ok'] else RED + 'NO' + RESET}")
    lines.append(f"Git branch: {git.get('branch')} dirty ({git.get('dirty_files')})")
    lines.append("")
    lines.append(BOLD + "LEGEND" + RESET)
    lines.append(RED + "червоне = невиконане / pending / returned" + RESET)
    lines.append(GREEN + "зелене = виконується / process active" + RESET)
    lines.append(GRAY + "нейтральне = виконане / done" + RESET)
    lines.append("")
    lines.append(BOLD + "SUMMARY" + RESET)
    lines.append(f"Невиконане pending: {RED}({t['pending']}){RESET}")
    lines.append(f"Виконується running: {GREEN}({t['running']}){RESET}")
    lines.append(f"Виконане done: {GRAY}({t['done']}){RESET}")
    lines.append(f"Повернуте return: {RED}({t['returned']}){RESET}")
    lines.append(f"Аудит audit: {YELLOW}({t['audit']}){RESET}")
    lines.append(f"Процеси йдуть: {GREEN}({t['process_running']}){RESET}")
    lines.append(f"Процеси не йдуть/відсутні: {RED}({t['process_missing']}){RESET}")
    lines.append("")
    lines.append(BOLD + "BRANCHES / ГІЛКИ" + RESET)

    for slug, b in report["branches"].items():
        st = terminal_color(b["status"], b["status"])
        load_color = RED if b["load_percent"] >= 70 else YELLOW if b["load_percent"] >= 30 else GREEN
        lines.append("")
        lines.append(f"{BOLD}{b['name']}{RESET}")
        lines.append(f"  статус: {st}")
        lines.append(f"  навантаження: {load_color}({b['load_percent']}%){RESET}")
        lines.append(f"  невиконане: {RED}({b['pending']}){RESET} | виконується: {GREEN}({b['running']}){RESET} | виконане: {GRAY}({b['done']}){RESET}")
        lines.append(f"  return: {RED}({b['returned']}){RESET} | audit: {YELLOW}({b['audit']}){RESET}")
        lines.append(f"  процеси йдуть: {GREEN}({b['process_running']}){RESET} | не йдуть: {RED}({b['process_missing']}){RESET} | очікувано: ({b['process_expected']})")
        lines.append(f"  storage files: ({b['storage_total']})")
        lines.append("  queues:")
        for q, c in b["pending_queues"].items():
            lines.append(f"    pending {q}: {RED}({c}){RESET}")
        for q, c in b["running_queues"].items():
            lines.append(f"    running {q}: {GREEN}({c}){RESET}")
        for q, c in b["done_queues"].items():
            lines.append(f"    done {q}: {GRAY}({c}){RESET}")

    lines.append("")
    lines.append(BOLD + "ACTIONS / ДІЇ" + RESET)
    lines.append("  cybra-load audit finance")
    lines.append("  cybra-load return finance")
    lines.append("  cybra-load done finance")
    lines.append("  cybra-load rebalance finance")
    lines.append("  cybra-load serve 8796")
    return "\n".join(lines)

def make_html(report):
    rows = []
    for slug, b in report["branches"].items():
        cl = css_class(b["status"])
        load_cl = "red" if b["load_percent"] >= 70 else "yellow" if b["load_percent"] >= 30 else "green"
        rows.append(f"""
<tr>
<td><b>{html.escape(b['name'])}</b><br><small>{html.escape(b['description'])}</small></td>
<td class="{cl}">{html.escape(b['status'])}</td>
<td class="red">({b['pending']})</td>
<td class="green">({b['running']})</td>
<td class="neutral">({b['done']})</td>
<td class="red">({b['returned']})</td>
<td class="yellow">({b['audit']})</td>
<td><span class="green">({b['process_running']})</span> / <span class="red">({b['process_missing']})</span></td>
<td class="{load_cl}">({b['load_percent']}%)</td>
<td>
<a class="btn yellow" href="/action?branch={slug}&do=audit">Аудит</a>
<a class="btn red" href="/action?branch={slug}&do=return">На доопрацювання</a>
<a class="btn neutral" href="/action?branch={slug}&do=done">Виконано</a>
<a class="btn green" href="/action?branch={slug}&do=rebalance">Розвантажити</a>
</td>
</tr>
""")

    t = report["totals"]
    page = f"""<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>CYBRA Branch Load Monitor</title>
<style>
body {{ font-family: system-ui, sans-serif; max-width: 1280px; margin: 30px auto; padding: 20px; }}
table {{ border-collapse: collapse; width: 100%; }}
td, th {{ border: 1px solid #ddd; padding: 8px; vertical-align: top; }}
.red {{ color: #c40000; font-weight: 800; }}
.green {{ color: #008a2e; font-weight: 800; }}
.yellow {{ color: #a36b00; font-weight: 800; }}
.neutral {{ color: #555; font-weight: 800; }}
.card {{ border: 1px solid #ddd; border-radius: 14px; padding: 16px; margin: 14px 0; }}
.btn {{ display:inline-block; padding:6px 9px; margin:3px; border:1px solid #999; border-radius:8px; text-decoration:none; }}
.btn.red {{ border-color:#c40000; }}
.btn.green {{ border-color:#008a2e; }}
.btn.yellow {{ border-color:#a36b00; }}
.btn.neutral {{ border-color:#555; }}
code {{ word-break: break-all; }}
</style>
</head>
<body>
<h1>CYBRA Branch Load Monitor V2</h1>

<div class="card">
<p><b>Legend:</b></p>
<p class="red">червоне = невиконане / pending / returned</p>
<p class="green">зелене = виконується / running / process active</p>
<p class="neutral">нейтральне = виконане / done</p>
</div>

<div class="card">
<p>Time: <code>{html.escape(report['timestamp'])}</code></p>
<p>Redis: <b>{report['redis_ok']}</b></p>
<p>Git branch: <code>{html.escape(str(report['git'].get('branch')))}</code>, dirty: <span class="yellow">({report['git'].get('dirty_files')})</span></p>
<p>Pending: <span class="red">({t['pending']})</span> | Running: <span class="green">({t['running']})</span> | Done: <span class="neutral">({t['done']})</span> | Return: <span class="red">({t['returned']})</span> | Audit: <span class="yellow">({t['audit']})</span></p>
<p>Processes running: <span class="green">({t['process_running']})</span> | Missing: <span class="red">({t['process_missing']})</span></p>
</div>

<table>
<tr>
<th>Гілка / структура</th>
<th>Статус</th>
<th>Невиконане</th>
<th>Виконується</th>
<th>Виконане</th>
<th>Return</th>
<th>Audit</th>
<th>Процеси йдуть / не йдуть</th>
<th>Навантаження</th>
<th>Кнопки</th>
</tr>
{''.join(rows)}
</table>

<p><a href="/json">JSON</a> | <a href="/">Refresh</a></p>
</body>
</html>
"""
    return page

def save_report(report):
    write_json(ROOT / "data/cybra_load_monitor/reports/load_monitor_latest.json", report)
    write_json(ROOT / "feeds/cybra_load_monitor.json", report)

    terminal = make_terminal(report)
    write_text(ROOT / "posts/cybra_load_monitor.md", terminal)
    write_text(ROOT / "dashboard/cybra_load_monitor/index.html", make_html(report))

    targets = [
        ROOT / "data/cybra_load_monitor/reports/load_monitor_latest.json",
        ROOT / "feeds/cybra_load_monitor.json",
        ROOT / "posts/cybra_load_monitor.md",
        ROOT / "dashboard/cybra_load_monitor/index.html",
        ROOT / "scripts/monitor/cybra_redis_load_monitor_v2.py",
        ROOT / "cybra-load"
    ]

    proof = ""
    for p in targets:
        if p.exists():
            proof += f"{sha_file(p)}  {p.relative_to(ROOT)}\n"
    write_text(ROOT / "proofs/cybra_load_monitor.sha256", proof)

def build():
    report = collect()
    save_report(report)
    print(make_terminal(report))
    return report

def do_action(branch, action):
    ensure_redis()

    if branch not in BRANCHES:
        return {"status": "ERROR", "error": "unknown_branch", "branch": branch}

    allowed = {"audit", "return", "done", "rebalance"}
    if action not in allowed:
        return {"status": "ERROR", "error": "unknown_action", "action": action}

    cfg = BRANCHES[branch]
    record = {
        "timestamp": now(),
        "status": f"BRANCH_{action.upper()}_REQUEST_CREATED",
        "branch": branch,
        "branch_name": cfg["name"],
        "action": action,
        "source": "cybra_load_monitor_button_or_cli",
        "meaning": {
            "audit": "відправити гілку на аудит",
            "return": "повернути гілку на доопрацювання",
            "done": "позначити гілку як виконану",
            "rebalance": "створити запит на розвантаження гілки"
        }.get(action),
        "safety": SAFETY
    }

    action_dir = ROOT / "data/cybra_load_monitor/actions"
    mkdir(action_dir)
    fname = f"{int(time.time())}_{branch}_{action}.json"
    write_json(action_dir / fname, record)

    if action == "audit":
        for q in cfg["audit"]:
            redis_lpush(q, record)
        redis_lpush("cybra:audit:tasks", record)

    elif action == "return":
        for q in cfg["returned"]:
            redis_lpush(q, record)
        if cfg["pending"]:
            redis_lpush(cfg["pending"][0], record)
        redis_lpush("cybra:return:ai_tasks", record)

    elif action == "done":
        for q in cfg["done"]:
            redis_lpush(q, record)
        redis_lpush("cybra:completed:ai_tasks", record)

    elif action == "rebalance":
        redis_lpush("cybra:rebalance:tasks", record)
        if cfg["pending"]:
            redis_lpush(cfg["pending"][0], record)

    build()
    return record

def serve(port):
    class Handler(BaseHTTPRequestHandler):
        def send(self, code, data, ctype="text/html; charset=utf-8"):
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
                report = collect()
                save_report(report)
                self.send(200, make_html(report))

            elif u.path == "/json":
                report = collect()
                save_report(report)
                self.send(200, json.dumps(report, ensure_ascii=False, indent=2), "application/json; charset=utf-8")

            elif u.path == "/action":
                branch = (q.get("branch") or [""])[0]
                action = (q.get("do") or [""])[0]
                result = do_action(branch, action)
                page = f"<html><body><h2>{html.escape(result.get('status','DONE'))}</h2><pre>{html.escape(json.dumps(result, ensure_ascii=False, indent=2))}</pre><p><a href='/'>Назад</a></p></body></html>"
                self.send(200, page)

            else:
                self.send(404, "not found")

        def log_message(self, fmt, *args):
            return

    print(f"CYBRA load dashboard: http://127.0.0.1:{port}/")
    HTTPServer(("127.0.0.1", int(port)), Handler).serve_forever()

def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"

    if cmd in ("status", "run"):
        build()
    elif cmd == "json":
        report = collect()
        save_report(report)
        print(json.dumps(report, ensure_ascii=False, indent=2))
    elif cmd == "proof":
        subprocess.call("sha256sum -c proofs/cybra_load_monitor.sha256", shell=True, cwd=ROOT)
    elif cmd == "action":
        branch = sys.argv[2] if len(sys.argv) > 2 else "finance"
        action = sys.argv[3] if len(sys.argv) > 3 else "audit"
        print(json.dumps(do_action(branch, action), ensure_ascii=False, indent=2))
    elif cmd == "serve":
        port = sys.argv[2] if len(sys.argv) > 2 else "8795"
        serve(port)
    else:
        print("Commands: status | json | proof | action <branch> <audit|return|done|rebalance> | serve [port]")

if __name__ == "__main__":
    main()
