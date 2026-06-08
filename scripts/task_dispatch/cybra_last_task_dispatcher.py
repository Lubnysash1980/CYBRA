#!/usr/bin/env python3
import sys, json, time, hashlib, subprocess, shutil, re
from pathlib import Path

ROOT = Path.home() / "CYBRA"

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
        "path": "parliament/inbox"
    },
    "it": {
        "name": "IT Department",
        "queue": "it_department",
        "path": "data/cybra_finance/it_department/tasks"
    },
    "mgs": {
        "name": "MGS Department",
        "queue": "cybra_mgs_all",
        "path": "data/cybra_mgs/tasks"
    },
    "oracle": {
        "name": "Oracle Department",
        "queue": "cybra_oracle_tasks",
        "path": "data/cybra_oracle/tasks"
    },
    "meta": {
        "name": "Meta Evolution Department",
        "queue": "cybra:meta:evolution:pool",
        "path": "data/cybra_meta_evolution/tasks"
    },
    "proof": {
        "name": "Proof Department",
        "queue": "cybra:audit:proof",
        "path": "data/cybra_proof_department/reports"
    },
    "binary": {
        "name": "Binary Code Department",
        "queue": "cybra:binary:tasks",
        "path": "data/cybra_it_department/meta_evolution_binary_committee"
    }
}

DEFAULT_COMMITTEES = [
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
    "manual_OWNER_approval_required": True,
    "cyber_parliament_approval_required": True,
    "dispatcher_actions_are_internal_only": True
}

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

def ensure_redis():
    if not shutil.which("redis-cli"):
        return False
    r = subprocess.run("redis-cli ping", shell=True, cwd=ROOT, text=True, capture_output=True)
    if r.returncode == 0 and "PONG" in r.stdout:
        return True
    mkdir(ROOT / "runtime/redis")
    subprocess.run(
        "redis-server --daemonize yes --bind 127.0.0.1 --port 6379 --dir runtime/redis --save '' --appendonly no >/dev/null 2>&1",
        shell=True,
        cwd=ROOT
    )
    time.sleep(1)
    r = subprocess.run("redis-cli ping", shell=True, cwd=ROOT, text=True, capture_output=True)
    return r.returncode == 0 and "PONG" in r.stdout

def redis_push(queue, payload):
    if not ensure_redis():
        return False
    raw = json.dumps(payload, ensure_ascii=False)
    r = subprocess.run(["redis-cli", "LPUSH", queue, raw], cwd=ROOT, text=True, capture_output=True)
    return r.returncode == 0

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
            try:
                mtime = p.stat().st_mtime
            except Exception:
                mtime = 0
            candidates.append({
                "path": p,
                "mtime": mtime,
                "task": obj
            })

    if not candidates:
        return None

    candidates.sort(key=lambda x: x["mtime"], reverse=True)
    latest = candidates[0]
    task = latest["task"]

    task_id = task.get("task_id") or task.get("block_id") or task.get("id") or latest["path"].stem
    title = task.get("title") or task.get("objective") or task.get("status") or "NO_TITLE"
    status = task.get("status") or "UNKNOWN"

    return {
        "task_id": task_id,
        "title": title,
        "status": status,
        "source": rel(latest["path"]),
        "mtime": latest["mtime"],
        "sha256": sha_obj(task),
        "task": task
    }

def analyze_task(latest):
    task = latest["task"]
    raw = json.dumps(task, ensure_ascii=False).lower()

    finance = any(x in raw for x in ["finance", "bank", "psp", "payment", "token", "coin", "kibra", "wallet", "proof"])
    incomplete = any(x in raw for x in ["pending", "queued", "partial", "waiting", "review", "locked", "return", "rework", "unknown"])
    broken = any(x in raw for x in ["broken", "error", "fail", "invalid", "missing"])
    needs_parliament = any(x in raw for x in ["parliament", "approval", "vote", "owner"])
    needs_it = any(x in raw for x in ["it", "binary", "script", "module", "structure", "handler"])
    needs_proof = any(x in raw for x in ["proof", "sha256", "audit"])

    recommendation = []
    if incomplete:
        recommendation.append("return_to_rework")
    if needs_parliament:
        recommendation.append("return_to_parliament")
    if needs_it:
        recommendation.append("return_to_it")
    if finance:
        recommendation.append("merge_finance_departments")
    if needs_proof:
        recommendation.append("send_to_proof_audit")
    if broken:
        recommendation.append("repair_broken_layer")

    if not recommendation:
        recommendation.append("audit")

    return {
        "finance_related": finance,
        "incomplete_or_pending": incomplete,
        "broken_or_failed": broken,
        "needs_parliament": needs_parliament,
        "needs_it": needs_it,
        "needs_proof": needs_proof,
        "recommendation": recommendation
    }

def action_packet(latest, action, target=None, extra=None):
    packet_id = "LAST-TASK-DISPATCH-" + time.strftime("%Y%m%d_%H%M%S") + "-" + hashlib.sha256((latest["sha256"] + action).encode()).hexdigest()[:10]

    packet = {
        "packet_id": packet_id,
        "timestamp": now(),
        "status": "LAST_TASK_DISPATCH_CREATED",
        "action": action,
        "target": target,
        "source_task": {
            "task_id": latest["task_id"],
            "title": latest["title"],
            "status": latest["status"],
            "source": latest["source"],
            "sha256": latest["sha256"]
        },
        "payload": latest["task"],
        "extra": extra or {},
        "safety": SAFETY
    }

    return packet

def route_to_department(latest, dep_key):
    dep = DEPARTMENTS[dep_key]
    packet = action_packet(latest, f"RETURN_TO_{dep_key.upper()}", dep["name"])

    out_path = ROOT / dep["path"] / f"{packet['packet_id']}.json"
    write_json(out_path, packet)
    redis_ok = redis_push(dep["queue"], packet)

    report = {
        "timestamp": now(),
        "status": "LAST_TASK_RETURNED_TO_DEPARTMENT",
        "department": dep,
        "packet_file": rel(out_path),
        "redis_queue": dep["queue"],
        "redis_ok": redis_ok,
        "packet": packet
    }

    write_json(ROOT / f"data/cybra_task_dispatch/actions/{packet['packet_id']}.json", report)
    return report

def merge_departments(latest):
    packet = action_packet(latest, "MERGE_ALL_DEPARTMENTS_AROUND_TASK", "all_departments")

    routes = {}
    files = {}

    for key, dep in DEPARTMENTS.items():
        p = ROOT / dep["path"] / f"{packet['packet_id']}_{key}.json"
        write_json(p, packet)
        files[key] = rel(p)
        routes[key] = {
            "department": dep["name"],
            "queue": dep["queue"],
            "redis_ok": redis_push(dep["queue"], packet),
            "file": rel(p)
        }

    merged = {
        "timestamp": now(),
        "status": "ALL_DEPARTMENTS_MERGED_AROUND_LAST_TASK",
        "packet_id": packet["packet_id"],
        "source_task": packet["source_task"],
        "routes": routes,
        "files": files,
        "safety": SAFETY
    }

    write_json(ROOT / f"data/cybra_task_dispatch/merged/{packet['packet_id']}.json", merged)
    return merged

def add_committees(latest, committees=None):
    committees = committees or DEFAULT_COMMITTEES
    clean = []

    for c in committees:
        c = re.sub(r"[^a-zA-Z0-9_\-]", "_", str(c).strip())
        if c:
            clean.append(c)

    packet = action_packet(latest, "ADD_COMMITTEES_AROUND_TASK", "cyber_parliament_committees", {"committees": clean})

    created = []
    for c in clean:
        base = ROOT / "parliament" / "committees" / c / "tasks"
        mkdir(base)
        f = base / f"{packet['packet_id']}.json"
        write_json(f, packet)
        created.append({
            "committee": c,
            "file": rel(f),
            "queue": f"cybra:committee:{c}",
            "redis_ok": redis_push(f"cybra:committee:{c}", packet)
        })

    redis_push("parliament_inbox", packet)

    report = {
        "timestamp": now(),
        "status": "COMMITTEES_ADDED_AROUND_LAST_TASK",
        "packet_id": packet["packet_id"],
        "source_task": packet["source_task"],
        "committees": created,
        "safety": SAFETY
    }

    write_json(ROOT / f"data/cybra_task_dispatch/committees/{packet['packet_id']}.json", report)
    return report

def audit_task(latest):
    analysis = analyze_task(latest)
    packet = action_packet(latest, "AUDIT_LAST_TASK", "audit", {"analysis": analysis})

    queues = ["cybra:audit:tasks", "cybra:audit:finance", "cybra:audit:proof", "parliament_inbox"]
    routes = {q: redis_push(q, packet) for q in queues}

    report = {
        "timestamp": now(),
        "status": "LAST_TASK_SENT_TO_AUDIT",
        "analysis": analysis,
        "routes": routes,
        "packet": packet,
        "safety": SAFETY
    }

    write_json(ROOT / f"data/cybra_task_dispatch/actions/{packet['packet_id']}_audit.json", report)
    return report

def auto_dispatch(latest):
    analysis = analyze_task(latest)
    results = []

    if analysis["needs_parliament"]:
        results.append(route_to_department(latest, "parliament"))

    if analysis["needs_it"]:
        results.append(route_to_department(latest, "it"))

    if analysis["finance_related"]:
        results.append(merge_departments(latest))

    if analysis["needs_proof"]:
        results.append(route_to_department(latest, "proof"))

    results.append(add_committees(latest))

    if analysis["incomplete_or_pending"] or analysis["broken_or_failed"]:
        ret = action_packet(latest, "RETURN_TO_REWORK_POOL", "cybra:return:ai_tasks", {"analysis": analysis})
        redis_push("cybra:return:ai_tasks", ret)
        redis_push("cybra:meta:evolution:pool", ret)
        write_json(ROOT / f"data/cybra_task_dispatch/actions/{ret['packet_id']}_return.json", ret)
        results.append(ret)

    report = {
        "timestamp": now(),
        "status": "AUTO_DISPATCH_DONE",
        "analysis": analysis,
        "results_count": len(results),
        "results": results,
        "safety": SAFETY
    }

    write_json(ROOT / "data/cybra_task_dispatch/reports/last_task_auto_dispatch_latest.json", report)
    return report

def write_report(kind, data):
    latest = find_latest_task()
    post = ROOT / "posts/cybra_last_task_dispatch.md"
    feed = ROOT / "feeds/cybra_last_task_dispatch.json"
    report_file = ROOT / "data/cybra_task_dispatch/reports/last_task_dispatch_latest.json"

    full = {
        "timestamp": now(),
        "status": "LAST_TASK_DISPATCH_REPORT",
        "kind": kind,
        "latest_task": latest,
        "result": data,
        "safety": SAFETY
    }

    write_json(report_file, full)
    write_json(feed, full)

    md = f"""# CYBRA Last Task Dispatcher

Status: **{full["status"]}**

Kind: `{kind}`

## Last task

- Task ID: `{latest.get("task_id") if latest else None}`
- Title: `{latest.get("title") if latest else None}`
- Status: `{latest.get("status") if latest else None}`
- Source: `{latest.get("source") if latest else None}`
- SHA256: `{latest.get("sha256") if latest else None}`

## Result

`{data.get("status") if isinstance(data, dict) else "DONE"}`

## Available actions

- `cybra-last-task inspect`
- `cybra-last-task parliament`
- `cybra-last-task it`
- `cybra-last-task merge`
- `cybra-last-task committees`
- `cybra-last-task audit`
- `cybra-last-task auto`

## Safety

- real_payment_now: false
- automatic_external_tx: false
- automatic_withdrawals: false
- automatic_SWIFT: false
- automatic_real_rewards: false
"""
    write_text(post, md)

    targets = [report_file, feed, post, ROOT / "scripts/task_dispatch/cybra_last_task_dispatcher.py", ROOT / "cybra-last-task"]
    proof = ""
    for p in targets:
        if p.exists():
            proof += f"{sha_file(p)}  {rel(p)}\n"
    write_text(ROOT / "proofs/cybra_last_task_dispatch.sha256", proof)

def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "inspect"
    latest = find_latest_task()

    if not latest:
        data = {"status": "NO_TASK_FOUND"}
        print(json.dumps(data, ensure_ascii=False, indent=2))
        return

    if cmd == "inspect":
        data = {
            "status": "LAST_TASK_INSPECTED",
            "latest": latest,
            "analysis": analyze_task(latest)
        }
    elif cmd == "parliament":
        data = route_to_department(latest, "parliament")
    elif cmd in ("it", "voiti", "it-department"):
        data = route_to_department(latest, "it")
    elif cmd == "merge":
        data = merge_departments(latest)
    elif cmd == "committees":
        committees = sys.argv[2:] if len(sys.argv) > 2 else None
        data = add_committees(latest, committees)
    elif cmd == "audit":
        data = audit_task(latest)
    elif cmd == "auto":
        data = auto_dispatch(latest)
    elif cmd == "proof":
        subprocess.call("sha256sum -c proofs/cybra_last_task_dispatch.sha256", shell=True, cwd=ROOT)
        return
    elif cmd == "status":
        p = ROOT / "posts/cybra_last_task_dispatch.md"
        print(p.read_text(encoding="utf-8") if p.exists() else "No report yet")
        return
    else:
        data = {"status": "UNKNOWN_COMMAND", "commands": ["inspect", "parliament", "it", "merge", "committees", "audit", "auto", "status", "proof"]}

    write_report(cmd, data)
    print(json.dumps(data, ensure_ascii=False, indent=2))

if __name__ == "__main__":
    main()
