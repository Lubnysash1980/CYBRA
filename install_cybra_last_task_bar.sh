#!/usr/bin/env bash
set +e
cd "$HOME/CYBRA" || exit 1

echo "=== INSTALL CYBRA LAST TASK BAR MENU ==="

mkdir -p \
  scripts/task_dispatch \
  data/cybra_task_dispatch/{reports,actions,locked,completed,returned,bar_menu,audit} \
  data/cybra_bar/menus \
  parliament/inbox parliament/committees \
  posts feeds proofs dashboard/cybra_last_task_bar logs/task_dispatch runtime/redis

cat > scripts/task_dispatch/cybra_last_task_bar.py <<'PY'
#!/usr/bin/env python3
import os, sys, json, time, hashlib, subprocess, shutil, html
from pathlib import Path
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs

ROOT = Path.home() / "CYBRA"
LOCK_FILE = ROOT / "data/cybra_task_dispatch/locked/last_task_lock.json"

TASK_DIRS = [
    "data/cybra_meta_evolution/blocks",
    "data/cybra_meta_evolution/tasks",
    "data/cybra_ai_blocks",
    "blockchain/kibra_chain/task_blocks",
    "data/cybra_finance/it_department/tasks",
    "data/cybra_mainnet/tasks",
    "data/cybra_mgs/tasks",
    "data/cybra_oracle/tasks"
]

DEPARTMENTS = {
    "parliament": {
        "name": "Cyber Parliament",
        "queue": "parliament_inbox",
        "path": "parliament/inbox",
        "process_patterns": ["parliament", "uvicorn"]
    },
    "it": {
        "name": "IT Department",
        "queue": "it_department",
        "path": "data/cybra_finance/it_department/tasks",
        "process_patterns": ["it_department", "cybra", "python"]
    },
    "mgs": {
        "name": "MGS",
        "queue": "cybra_mgs_all",
        "path": "data/cybra_mgs/tasks",
        "process_patterns": ["mgs", "cybra"]
    },
    "oracle": {
        "name": "Oracle",
        "queue": "cybra_oracle_tasks",
        "path": "data/cybra_oracle/tasks",
        "process_patterns": ["oracle", "ssh"]
    },
    "meta": {
        "name": "Meta Evolution",
        "queue": "cybra:meta:evolution:pool",
        "path": "data/cybra_meta_evolution/tasks",
        "process_patterns": ["meta_evolution", "cybra-meta-evo"]
    },
    "proof": {
        "name": "Proof Department",
        "queue": "cybra:audit:proof",
        "path": "data/cybra_proof_department/reports",
        "process_patterns": ["proof", "sha256"]
    },
    "binary": {
        "name": "Binary Code Committee",
        "queue": "cybra:binary:tasks",
        "path": "data/cybra_it_department/meta_evolution_binary_committee",
        "process_patterns": ["binary", "structure"]
    }
}

STANDARD_COMMITTEES = [
    "finance_execution_committee",
    "analytics_scaling_committee",
    "binary_code_committee",
    "proof_committee",
    "risk_safety_committee",
    "cyber_parliament_review_committee",
    "it_rework_committee",
    "oracle_execution_committee"
]

SAFETY = {
    "real_payment_now": False,
    "real_trading_now": False,
    "automatic_external_tx": False,
    "automatic_withdrawals": False,
    "automatic_SWIFT": False,
    "automatic_real_rewards": False,
    "external_bridge_enabled": False,
    "last_task_only": True,
    "manual_OWNER_approval_required": True,
    "dashboard_actions_are_internal_only": True
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

def rel(p):
    return str(Path(p).relative_to(ROOT))

def read_json(path, default=None):
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    except Exception:
        return default if default is not None else {}

def write_json(path, data):
    p = Path(path)
    mkdir(p.parent)
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")

def write_text(path, text):
    p = Path(path)
    mkdir(p.parent)
    p.write_text(text, encoding="utf-8")

def sha_obj(obj):
    return hashlib.sha256(json.dumps(obj, ensure_ascii=False, sort_keys=True).encode()).hexdigest()

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

def ps_text():
    r = run("ps -A 2>/dev/null || ps 2>/dev/null")
    return ((r.stdout or "") + "\n" + (r.stderr or "")).lower()

def find_latest_task():
    candidates = []
    for d in TASK_DIRS:
        base = ROOT / d
        if not base.exists():
            continue
        for p in base.glob("*.json"):
            if not p.is_file():
                continue
            obj = read_json(p, None)
            if not isinstance(obj, dict):
                continue
            candidates.append({
                "path": p,
                "mtime": p.stat().st_mtime,
                "task": obj
            })

    if not candidates:
        return None

    candidates.sort(key=lambda x: x["mtime"], reverse=True)
    item = candidates[0]
    obj = item["task"]

    task_id = obj.get("task_id") or obj.get("block_id") or obj.get("id") or item["path"].stem
    title = obj.get("title") or obj.get("objective") or obj.get("status") or "NO_TITLE"
    status = obj.get("status") or "UNKNOWN"

    return {
        "task_id": task_id,
        "title": title,
        "status": status,
        "source": rel(item["path"]),
        "sha256": sha_obj(obj),
        "mtime": item["mtime"],
        "task": obj
    }

def get_current_task():
    lock = read_json(LOCK_FILE, None)
    if isinstance(lock, dict) and lock.get("locked") and lock.get("source"):
        p = ROOT / lock["source"]
        obj = read_json(p, None)
        if isinstance(obj, dict):
            return {
                "task_id": lock.get("task_id") or obj.get("task_id") or obj.get("block_id") or p.stem,
                "title": lock.get("title") or obj.get("title") or obj.get("objective") or obj.get("status") or "NO_TITLE",
                "status": obj.get("status") or lock.get("status") or "UNKNOWN",
                "source": lock["source"],
                "sha256": sha_obj(obj),
                "locked": True,
                "task": obj
            }
    latest = find_latest_task()
    if latest:
        latest["locked"] = False
    return latest

def lock_task():
    t = find_latest_task()
    if not t:
        return {"status": "NO_TASK_FOUND"}
    lock = {
        "timestamp": now(),
        "locked": True,
        "task_id": t["task_id"],
        "title": t["title"],
        "status": t["status"],
        "source": t["source"],
        "sha256": t["sha256"],
        "rule": "all bar actions work only with this locked last task"
    }
    write_json(LOCK_FILE, lock)
    return {"status": "LAST_TASK_LOCKED", "lock": lock}

def unlock_task():
    write_json(LOCK_FILE, {"timestamp": now(), "locked": False})
    return {"status": "LAST_TASK_UNLOCKED"}

def clean_name(x):
    out = "".join(ch if ch.isalnum() or ch in "_-" else "_" for ch in str(x).strip())
    return out or "custom_committee"

def analyze_task(t):
    obj = t["task"]
    raw = json.dumps(obj, ensure_ascii=False).lower()

    checks = {
        "has_task_id": bool(t.get("task_id")),
        "has_title": t.get("title") != "NO_TITLE",
        "has_status": t.get("status") != "UNKNOWN",
        "has_safety": isinstance(obj.get("safety"), dict),
        "has_proof_or_hash": ("proof" in raw or "sha256" in raw or "hash" in raw),
        "has_parliament_route": ("parliament" in raw or "approval" in raw or "vote" in raw),
        "has_it_route": ("it" in raw or "module" in raw or "script" in raw or "binary" in raw or "structure" in raw),
        "has_committees": ("committee" in raw or "комітет" in raw),
        "has_redis_or_pool": ("redis" in raw or "pool" in raw or "queue" in raw),
        "has_usha_or_encryption": ("usha" in raw or "encrypt" in raw or "sealed" in raw),
        "has_binary_layer": ("binary" in raw or "pyc" in raw or "bin.gz" in raw),
        "finance_scope": any(x in raw for x in ["finance", "bank", "psp", "payment", "token", "coin", "wallet", "kibra"])
    }

    problems = []
    advice = []

    if not checks["has_safety"]:
        problems.append("Нема safety-блоку.")
        advice.append("Додати safety-блок: без реальних платежів, SWIFT, external tx, withdrawals.")
    if not checks["has_parliament_route"]:
        problems.append("Не видно маршруту в Cyber Parliament.")
        advice.append("Натиснути кнопку Parliament або Auto-route.")
    if not checks["has_it_route"]:
        problems.append("Не видно IT/module/binary маршруту.")
        advice.append("Повернути в IT Department або додати Binary Committee.")
    if not checks["has_committees"]:
        problems.append("Не видно комітетів навколо задачі.")
        advice.append("Натиснути Standard Committees або додати свої комітети.")
    if not checks["has_proof_or_hash"]:
        problems.append("Не видно proof/hash.")
        advice.append("Відправити на аудит proof department.")
    if not checks["has_redis_or_pool"]:
        problems.append("Не видно Redis/pool маршруту.")
        advice.append("Повернути задачу в meta evolution pool або KIBRA pool.")
    if not checks["has_usha_or_encryption"]:
        problems.append("Не видно USHA/sealed/encrypted tunnel.")
        advice.append("Додати sealed routing через USHA tunnel.")
    if not checks["has_binary_layer"]:
        problems.append("Не видно binary-safe layer.")
        advice.append("Підключити Binary Code Committee.")

    if not problems:
        problems.append("Критичних проблем не виявлено.")
        advice.append("Можна перевірити вручну і натиснути Done або Audit для додаткового контролю.")

    incomplete = any(x in raw for x in ["pending", "partial", "waiting", "unknown", "return", "rework", "failed", "broken", "error"])
    if incomplete:
        advice.append("Ознаки незавершеності знайдені: краще Return або Auto-route.")

    return {
        "timestamp": now(),
        "status": "LAST_TASK_AUDIT_ANALYSIS",
        "checks": checks,
        "problems": problems,
        "advice": advice,
        "explanation": "Аудит перевіряє, чи задача має парламент, IT-модулі, комітети, proof, Redis/pool, USHA tunnel, binary-safe layer і safety. Якщо чогось нема — радить, куди перемкнути задачу.",
        "safety": SAFETY
    }

def action_packet(t, action, target, extra=None):
    packet_id = "BAR-LAST-TASK-" + time.strftime("%Y%m%d_%H%M%S") + "-" + hashlib.sha256((t["sha256"] + action + target).encode()).hexdigest()[:10]
    return {
        "packet_id": packet_id,
        "timestamp": now(),
        "status": f"LAST_TASK_{action.upper()}",
        "action": action,
        "target": target,
        "source_task_id": t["task_id"],
        "source_task_title": t["title"],
        "source_task_status": t["status"],
        "source_task_file": t["source"],
        "source_task_sha256": t["sha256"],
        "payload": t["task"],
        "extra": extra or {},
        "safety": SAFETY
    }

def save_action(packet):
    p = ROOT / "data/cybra_task_dispatch/actions" / f"{packet['packet_id']}.json"
    write_json(p, packet)
    return rel(p)

def route_department(t, dep_key):
    dep = DEPARTMENTS[dep_key]
    packet = action_packet(t, "route", dep_key, {"department": dep["name"]})
    out = ROOT / dep["path"] / f"{packet['packet_id']}.json"
    write_json(out, packet)
    redis_ok = redis_push(dep["queue"], packet)
    packet["result"] = {"file": rel(out), "queue": dep["queue"], "redis_ok": redis_ok}
    save_action(packet)
    return packet

def merge_all(t):
    packet = action_packet(t, "merge_all_departments", "all")
    routes = {}
    for key, dep in DEPARTMENTS.items():
        out = ROOT / dep["path"] / f"{packet['packet_id']}_{key}.json"
        write_json(out, packet)
        routes[key] = {
            "department": dep["name"],
            "file": rel(out),
            "queue": dep["queue"],
            "redis_ok": redis_push(dep["queue"], packet)
        }
    packet["result"] = {"routes": routes}
    write_json(ROOT / "data/cybra_task_dispatch/actions" / f"{packet['packet_id']}_merge.json", packet)
    return packet

def add_committees(t, committees):
    committees = [clean_name(x) for x in committees]
    packet = action_packet(t, "add_committees", "parliament_committees", {"committees": committees})
    created = []

    for c in committees:
        base = ROOT / "parliament/committees" / c / "tasks"
        mkdir(base)
        out = base / f"{packet['packet_id']}.json"
        write_json(out, packet)
        q = f"cybra:committee:{c}"
        created.append({"committee": c, "file": rel(out), "queue": q, "redis_ok": redis_push(q, packet)})

    redis_push("parliament_inbox", packet)
    packet["result"] = {"committees": created}
    write_json(ROOT / "data/cybra_task_dispatch/committees" / f"{packet['packet_id']}.json", packet)
    save_action(packet)
    return packet

def audit(t):
    analysis = analyze_task(t)
    packet = action_packet(t, "audit", "audit", {"analysis": analysis})
    queues = ["cybra:audit:last_task", "cybra:audit:finance", "cybra:audit:proof", "parliament_inbox"]
    packet["result"] = {"queues": {q: redis_push(q, packet) for q in queues}}
    write_json(ROOT / "data/cybra_task_dispatch/audit/last_task_audit_latest.json", packet)
    save_action(packet)
    return packet

def return_task(t):
    packet = action_packet(t, "return_to_rework", "rework_pool")
    out = ROOT / "data/cybra_task_dispatch/returned" / f"{packet['packet_id']}.json"
    write_json(out, packet)
    packet["result"] = {
        "file": rel(out),
        "queues": {
            "cybra:return:ai_tasks": redis_push("cybra:return:ai_tasks", packet),
            "cybra:meta:evolution:pool": redis_push("cybra:meta:evolution:pool", packet)
        }
    }
    save_action(packet)
    return packet

def done_task(t):
    packet = action_packet(t, "done", "completed")
    out = ROOT / "data/cybra_task_dispatch/completed" / f"{packet['packet_id']}.json"
    write_json(out, packet)
    packet["result"] = {
        "file": rel(out),
        "queue": "cybra:completed:ai_tasks",
        "redis_ok": redis_push("cybra:completed:ai_tasks", packet)
    }
    save_action(packet)
    return packet

def auto_route(t):
    analysis = analyze_task(t)
    results = []

    results.append(audit(t))

    if not analysis["checks"]["has_parliament_route"]:
        results.append(route_department(t, "parliament"))
    if not analysis["checks"]["has_it_route"]:
        results.append(route_department(t, "it"))
    if not analysis["checks"]["has_proof_or_hash"]:
        results.append(route_department(t, "proof"))
    if not analysis["checks"]["has_binary_layer"]:
        results.append(route_department(t, "binary"))
    if not analysis["checks"]["has_committees"]:
        results.append(add_committees(t, STANDARD_COMMITTEES))

    if len(analysis["problems"]) > 1 or "Критичних проблем не виявлено." not in analysis["problems"]:
        results.append(return_task(t))

    packet = action_packet(t, "auto_route", "auto", {"analysis": analysis, "results_count": len(results)})
    packet["result"] = {"results_count": len(results), "results": [x.get("packet_id") for x in results]}
    save_action(packet)
    return packet

def action_counts(t):
    base = ROOT / "data/cybra_task_dispatch/actions"
    counts = {"audit": 0, "route": 0, "merge": 0, "committees": 0, "return": 0, "done": 0, "auto": 0, "all": 0}
    if not base.exists():
        return counts
    for p in base.glob("*.json"):
        obj = read_json(p, {})
        if obj.get("source_task_sha256") != t["sha256"]:
            continue
        counts["all"] += 1
        a = str(obj.get("action", ""))
        if "audit" in a:
            counts["audit"] += 1
        if "route" in a:
            counts["route"] += 1
        if "merge" in a:
            counts["merge"] += 1
        if "committee" in a:
            counts["committees"] += 1
        if "return" in a:
            counts["return"] += 1
        if "done" in a:
            counts["done"] += 1
        if "auto" in a:
            counts["auto"] += 1
    return counts

def department_state():
    text = ps_text()
    state = {}
    for key, dep in DEPARTMENTS.items():
        proc = sum(text.count(x.lower()) for x in dep["process_patterns"])
        qlen = redis_len(dep["queue"])
        state[key] = {
            "department": dep["name"],
            "queue": dep["queue"],
            "queue_load": qlen,
            "processes_running": proc,
            "processes_missing": 0 if proc > 0 else 1,
            "status": "RUNNING" if proc > 0 else "NO_PROCESS"
        }
    return state

def report():
    t = get_current_task()
    if not t:
        return {"status": "NO_TASK_FOUND"}
    analysis = analyze_task(t)
    counts = action_counts(t)
    deps = department_state()

    pending = counts["return"] + redis_len("cybra:return:ai_tasks") + redis_len("cybra:meta:evolution:pool")
    running = sum(x["processes_running"] for x in deps.values())
    done = counts["done"] + redis_len("cybra:completed:ai_tasks")
    audit_count = counts["audit"] + redis_len("cybra:audit:last_task")

    load = min(100, pending * 12 + audit_count * 7 + max(0, 7 - running) * 6)

    rep = {
        "timestamp": now(),
        "status": "CYBRA_LAST_TASK_BAR_REPORT",
        "task": t,
        "analysis": analysis,
        "action_counts_for_this_task": counts,
        "department_state": deps,
        "summary": {
            "red_unfinished": pending,
            "green_running_processes": running,
            "neutral_done": done,
            "yellow_audit": audit_count,
            "load_percent": load
        },
        "commands": [
            "cybra-last-task-bar status",
            "cybra-last-task-bar lock",
            "cybra-last-task-bar audit",
            "cybra-last-task-bar parliament",
            "cybra-last-task-bar it",
            "cybra-last-task-bar merge",
            "cybra-last-task-bar committees",
            "cybra-last-task-bar committee NAME",
            "cybra-last-task-bar auto",
            "cybra-last-task-bar return",
            "cybra-last-task-bar done",
            "cybra-last-task-bar menu",
            "cybra-last-task-bar serve 8797"
        ],
        "safety": SAFETY
    }
    return rep

def save_report(rep):
    write_json(ROOT / "data/cybra_task_dispatch/reports/last_task_bar_latest.json", rep)
    write_json(ROOT / "feeds/cybra_last_task_bar.json", rep)

    menu = {
        "title": "CYBRA Last Task Bar Menu",
        "scope": "locked last task only",
        "commands": rep.get("commands", []),
        "dashboard": "http://127.0.0.1:8797/",
        "safety": SAFETY
    }
    write_json(ROOT / "data/cybra_bar/menus/last_task_menu.json", menu)

    txt = make_terminal(rep)
    write_text(ROOT / "posts/cybra_last_task_bar.md", txt)
    write_text(ROOT / "dashboard/cybra_last_task_bar/index.html", make_html(rep))

    targets = [
        ROOT / "data/cybra_task_dispatch/reports/last_task_bar_latest.json",
        ROOT / "feeds/cybra_last_task_bar.json",
        ROOT / "posts/cybra_last_task_bar.md",
        ROOT / "dashboard/cybra_last_task_bar/index.html",
        ROOT / "data/cybra_bar/menus/last_task_menu.json",
        ROOT / "scripts/task_dispatch/cybra_last_task_bar.py",
        ROOT / "cybra-last-task-bar"
    ]
    proof = ""
    for p in targets:
        if p.exists():
            proof += f"{sha_file(p)}  {rel(p)}\n"
    write_text(ROOT / "proofs/cybra_last_task_bar.sha256", proof)

def make_terminal(rep):
    if rep.get("status") == "NO_TASK_FOUND":
        return "NO_TASK_FOUND"

    s = rep["summary"]
    t = rep["task"]
    a = rep["analysis"]

    lines = []
    lines.append(BOLD + "=== CYBRA LAST TASK BAR ===" + RESET)
    lines.append(f"Task lock: {'YES' if t.get('locked') else 'NO'}")
    lines.append(f"Task ID: {t.get('task_id')}")
    lines.append(f"Title: {t.get('title')}")
    lines.append(f"Status: {t.get('status')}")
    lines.append(f"Source: {t.get('source')}")
    lines.append(f"SHA256: {t.get('sha256')}")
    lines.append("")
    lines.append(BOLD + "COLORS" + RESET)
    lines.append(RED + f"червоне / невиконане: ({s['red_unfinished']})" + RESET)
    lines.append(GREEN + f"зелене / виконується процесів: ({s['green_running_processes']})" + RESET)
    lines.append(GRAY + f"нейтральне / виконане: ({s['neutral_done']})" + RESET)
    lines.append(YELLOW + f"аудит: ({s['yellow_audit']})" + RESET)
    lines.append(f"навантаження: ({s['load_percent']}%)")
    lines.append("")
    lines.append(BOLD + "AUDIT PROBLEMS" + RESET)
    for p in a["problems"]:
        lines.append("- " + p)
    lines.append("")
    lines.append(BOLD + "AUDIT ADVICE" + RESET)
    for p in a["advice"]:
        lines.append("- " + p)
    lines.append("")
    lines.append(BOLD + "DEPARTMENTS / ПРОЦЕСИ Й ЧЕРГИ" + RESET)
    for key, d in rep["department_state"].items():
        proc = GREEN + f"({d['processes_running']})" + RESET if d["processes_running"] else RED + "(0)" + RESET
        miss = RED + f"({d['processes_missing']})" + RESET
        q = RED + f"({d['queue_load']})" + RESET if d["queue_load"] else GRAY + "(0)" + RESET
        lines.append(f"{d['department']}: queue {q}, processes {proc}, missing {miss}")
    lines.append("")
    lines.append(BOLD + "COMMANDS" + RESET)
    for c in rep["commands"]:
        lines.append("  " + c)
    return "\n".join(lines)

def make_html(rep):
    if rep.get("status") == "NO_TASK_FOUND":
        return "<html><body><h1>NO_TASK_FOUND</h1></body></html>"

    t = rep["task"]
    s = rep["summary"]
    a = rep["analysis"]

    dep_rows = ""
    for key, d in rep["department_state"].items():
        dep_rows += f"""
<tr>
<td>{html.escape(d['department'])}</td>
<td><code>{html.escape(d['queue'])}</code></td>
<td class="red">({d['queue_load']})</td>
<td class="green">({d['processes_running']})</td>
<td class="red">({d['processes_missing']})</td>
<td>{html.escape(d['status'])}</td>
</tr>
"""

    problems = "".join(f"<li>{html.escape(x)}</li>" for x in a["problems"])
    advice = "".join(f"<li>{html.escape(x)}</li>" for x in a["advice"])

    return f"""<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>CYBRA Last Task Bar</title>
<style>
body {{ font-family: system-ui, sans-serif; max-width: 1250px; margin: 28px auto; padding: 20px; }}
.card {{ border:1px solid #ddd; border-radius:14px; padding:16px; margin:14px 0; }}
.red {{ color:#c40000; font-weight:800; }}
.green {{ color:#008a2e; font-weight:800; }}
.yellow {{ color:#a36b00; font-weight:800; }}
.neutral {{ color:#555; font-weight:800; }}
.btn {{ display:inline-block; padding:10px 12px; margin:5px; border:1px solid #999; border-radius:9px; text-decoration:none; }}
.btn.red {{ border-color:#c40000; }}
.btn.green {{ border-color:#008a2e; }}
.btn.yellow {{ border-color:#a36b00; }}
.btn.neutral {{ border-color:#555; }}
table {{ border-collapse: collapse; width:100%; }}
td, th {{ border:1px solid #ddd; padding:8px; vertical-align:top; }}
code {{ word-break: break-all; }}
</style>
</head>
<body>
<h1>CYBRA Last Task Bar</h1>

<div class="card">
<p><b>Працюємо тільки з останнім/locked task.</b></p>
<p>Lock: <b>{'YES' if t.get('locked') else 'NO'}</b></p>
<p>Task ID: <code>{html.escape(str(t.get('task_id')))}</code></p>
<p>Title: <code>{html.escape(str(t.get('title')))}</code></p>
<p>Status: <code>{html.escape(str(t.get('status')))}</code></p>
<p>Source: <code>{html.escape(str(t.get('source')))}</code></p>
<p>SHA256: <code>{html.escape(str(t.get('sha256')))}</code></p>
</div>

<div class="card">
<p class="red">Червоне / невиконане: ({s['red_unfinished']})</p>
<p class="green">Зелене / виконується процесів: ({s['green_running_processes']})</p>
<p class="neutral">Нейтральне / виконане: ({s['neutral_done']})</p>
<p class="yellow">Аудит: ({s['yellow_audit']})</p>
<p>Навантаження: <b>({s['load_percent']}%)</b></p>
</div>

<div class="card">
<h2>Кнопки перемикання</h2>
<a class="btn yellow" href="/action?do=lock">Lock last task</a>
<a class="btn neutral" href="/action?do=unlock">Unlock</a>
<a class="btn yellow" href="/action?do=audit">Аудит</a>
<a class="btn green" href="/action?do=parliament">У парламент</a>
<a class="btn green" href="/action?do=it">В IT-відділ</a>
<a class="btn green" href="/action?do=merge">Об'єднати всі відділи</a>
<a class="btn green" href="/action?do=committees">Стандартні комітети</a>
<a class="btn yellow" href="/action?do=auto">Auto-route</a>
<a class="btn red" href="/action?do=return">На доопрацювання</a>
<a class="btn neutral" href="/action?do=done">Виконано</a>

<form action="/action" method="get" style="margin-top:12px;">
<input type="hidden" name="do" value="committee">
<input name="name" placeholder="new_committee_name">
<button type="submit">Додати свій комітет</button>
</form>
</div>

<div class="card">
<h2>Аудит: проблеми</h2>
<ul>{problems}</ul>
<h2>Аудит: що далі</h2>
<ul>{advice}</ul>
<p>{html.escape(a['explanation'])}</p>
</div>

<h2>Відділи / процеси / черги</h2>
<table>
<tr><th>Відділ</th><th>Queue</th><th>Навантаження</th><th>Процеси йдуть</th><th>Не йдуть</th><th>Статус</th></tr>
{dep_rows}
</table>

<p><a href="/">Refresh</a> | <a href="/json">JSON</a></p>
</body>
</html>
"""

def action(do, name=None):
    if do == "lock":
        res = lock_task()
    elif do == "unlock":
        res = unlock_task()
    else:
        t = get_current_task()
        if not t:
            return {"status": "NO_TASK_FOUND"}

        if do == "audit":
            res = audit(t)
        elif do == "parliament":
            res = route_department(t, "parliament")
        elif do == "it":
            res = route_department(t, "it")
        elif do == "merge":
            res = merge_all(t)
        elif do == "committees":
            res = add_committees(t, STANDARD_COMMITTEES)
        elif do == "committee":
            res = add_committees(t, [name or "custom_committee"])
        elif do == "auto":
            res = auto_route(t)
        elif do == "return":
            res = return_task(t)
        elif do == "done":
            res = done_task(t)
        else:
            res = {"status": "UNKNOWN_ACTION", "action": do}

    rep = report()
    save_report(rep)
    return res

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
                rep = report()
                save_report(rep)
                self.send_data(200, make_html(rep))

            elif u.path == "/json":
                rep = report()
                save_report(rep)
                self.send_data(200, json.dumps(rep, ensure_ascii=False, indent=2), "application/json; charset=utf-8")

            elif u.path == "/action":
                do = (q.get("do") or [""])[0]
                name = (q.get("name") or [""])[0]
                res = action(do, name)
                page = f"<html><body><h2>{html.escape(str(res.get('status')))}</h2><pre>{html.escape(json.dumps(res, ensure_ascii=False, indent=2))}</pre><p><a href='/'>Назад</a></p></body></html>"
                self.send_data(200, page)

            else:
                self.send_data(404, "not found")

        def log_message(self, fmt, *args):
            return

    print(f"CYBRA Last Task Bar: http://127.0.0.1:{port}/")
    HTTPServer(("127.0.0.1", int(port)), Handler).serve_forever()

def terminal_menu():
    action("lock")
    while True:
        rep = report()
        save_report(rep)
        print(make_terminal(rep))
        print("")
        print("1) audit")
        print("2) parliament")
        print("3) it")
        print("4) merge all departments")
        print("5) standard committees")
        print("6) custom committee")
        print("7) auto-route")
        print("8) return to rework")
        print("9) done")
        print("0) exit")
        choice = input("Choose: ").strip()

        if choice == "1":
            print(json.dumps(action("audit"), ensure_ascii=False, indent=2))
        elif choice == "2":
            print(json.dumps(action("parliament"), ensure_ascii=False, indent=2))
        elif choice == "3":
            print(json.dumps(action("it"), ensure_ascii=False, indent=2))
        elif choice == "4":
            print(json.dumps(action("merge"), ensure_ascii=False, indent=2))
        elif choice == "5":
            print(json.dumps(action("committees"), ensure_ascii=False, indent=2))
        elif choice == "6":
            name = input("Committee name: ").strip()
            print(json.dumps(action("committee", name), ensure_ascii=False, indent=2))
        elif choice == "7":
            print(json.dumps(action("auto"), ensure_ascii=False, indent=2))
        elif choice == "8":
            print(json.dumps(action("return"), ensure_ascii=False, indent=2))
        elif choice == "9":
            print(json.dumps(action("done"), ensure_ascii=False, indent=2))
        elif choice == "0":
            break

def proof():
    p = ROOT / "proofs/cybra_last_task_bar.sha256"
    if not p.exists():
        print("No proof yet. Run: cybra-last-task-bar status")
        return
    subprocess.call("sha256sum -c proofs/cybra_last_task_bar.sha256", shell=True, cwd=ROOT)

def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"

    if cmd == "status":
        rep = report()
        save_report(rep)
        print(make_terminal(rep))
    elif cmd == "json":
        rep = report()
        save_report(rep)
        print(json.dumps(rep, ensure_ascii=False, indent=2))
    elif cmd == "lock":
        print(json.dumps(action("lock"), ensure_ascii=False, indent=2))
    elif cmd == "unlock":
        print(json.dumps(action("unlock"), ensure_ascii=False, indent=2))
    elif cmd in ["audit", "parliament", "it", "merge", "committees", "auto", "return", "done"]:
        print(json.dumps(action(cmd), ensure_ascii=False, indent=2))
    elif cmd == "committee":
        name = sys.argv[2] if len(sys.argv) > 2 else "custom_committee"
        print(json.dumps(action("committee", name), ensure_ascii=False, indent=2))
    elif cmd == "menu":
        terminal_menu()
    elif cmd == "serve":
        port = sys.argv[2] if len(sys.argv) > 2 else "8797"
        serve(port)
    elif cmd == "proof":
        proof()
    else:
        print("Commands: status | json | lock | unlock | audit | parliament | it | merge | committees | committee NAME | auto | return | done | menu | serve [port] | proof")

if __name__ == "__main__":
    main()
PY

cat > cybra-last-task-bar <<'SH'
#!/usr/bin/env bash
cd "$HOME/CYBRA" || exit 1
python3 scripts/task_dispatch/cybra_last_task_bar.py "$@"
SH

cat > cybra-last-task-menu <<'SH'
#!/usr/bin/env bash
cd "$HOME/CYBRA" || exit 1
python3 scripts/task_dispatch/cybra_last_task_bar.py menu
SH

chmod +x scripts/task_dispatch/cybra_last_task_bar.py cybra-last-task-bar cybra-last-task-menu
ln -sf "$HOME/CYBRA/cybra-last-task-bar" "$PREFIX/bin/cybra-last-task-bar" 2>/dev/null || true
ln -sf "$HOME/CYBRA/cybra-last-task-menu" "$PREFIX/bin/cybra-last-task-menu" 2>/dev/null || true

cybra-last-task-bar lock
cybra-last-task-bar status
cybra-last-task-bar proof
