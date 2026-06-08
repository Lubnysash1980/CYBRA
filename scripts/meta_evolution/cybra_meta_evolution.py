#!/usr/bin/env python3
import os, sys, json, time, hashlib, subprocess, shutil
from pathlib import Path

ROOT = Path.home() / "CYBRA"

QUEUES = [
    "cybra:meta:evolution:pool",
    "cybra:kibra:pool:mining_blocks",
    "cybra:ai:tasks:block_inbox",
    "cybra:finance:evolution:pool",
    "ai_block_inbox",
    "cybra_mgs_all",
    "cybra_oracle_tasks",
    "parliament_inbox",
    "cybra:completed:ai_tasks",
    "cybra:return:ai_tasks"
]

TASK_DIRS = [
    "data/cybra_finance/it_department/tasks",
    "data/cybra_mainnet/tasks",
    "data/cybra_ai_blocks",
    "data/cybra_mgs/tasks",
    "data/cybra_oracle/tasks",
    "blockchain/kibra_chain/task_blocks"
]

SAFETY = {
    "real_payment_now": False,
    "real_trading_now": False,
    "automatic_external_tx": False,
    "automatic_withdrawals": False,
    "automatic_SWIFT": False,
    "automatic_real_rewards": False,
    "external_bridge_enabled": False,
    "finance_scope_only": True,
    "meta_evolution_only": True,
    "analytics_may_only_create_evolution_tasks": True,
    "broken_blocks_repaired_by_peeling_last_layer": True,
    "owner_final_pass_required": True
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

def redis_push(queue, payload):
    if not shutil.which("redis-cli"):
        return False
    try:
        subprocess.run(
            "redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes --bind 127.0.0.1 --port 6379 --dir runtime/redis --save '' --appendonly no >/dev/null 2>&1",
            shell=True,
            cwd=ROOT
        )
        raw = json.dumps(payload, ensure_ascii=False)
        r = subprocess.run(["redis-cli", "LPUSH", queue, raw], cwd=ROOT, text=True, capture_output=True)
        return r.returncode == 0
    except Exception:
        return False

def ensure_usha_key():
    secret_dir = ROOT / ".cybra_local_secret"
    mkdir(secret_dir)
    key = secret_dir / "usha.key"
    if not key.exists():
        key.write_bytes(os.urandom(32))
        try:
            os.chmod(key, 0o600)
        except Exception:
            pass
    return key

def usha_seal(payload, name):
    outbox = ROOT / "data/cybra_meta_evolution/outbox"
    mkdir(outbox)

    raw = outbox / f"{name}.json"
    sealed = outbox / f"{name}.enc"
    fallback = outbox / f"{name}.sealed.json"

    write_json(raw, payload)
    key = ensure_usha_key()

    openssl = shutil.which("openssl")
    if openssl:
        r = subprocess.run([
            openssl, "enc", "-aes-256-cbc", "-pbkdf2", "-salt",
            "-in", str(raw),
            "-out", str(sealed),
            "-pass", f"file:{key}"
        ], text=True, capture_output=True)
        if r.returncode == 0 and sealed.exists():
            return {
                "mode": "USHA_OPENSSL_AES_256_CBC_PBKDF2",
                "raw": rel(raw),
                "sealed": rel(sealed),
                "sha256": sha_file(sealed),
                "key_location": ".cybra_local_secret/usha.key",
                "git_safe": True
            }

    local = {
        "mode": "USHA_LOCAL_HASH_SEAL",
        "raw": rel(raw),
        "sha256_local_seal": hashlib.sha256(key.read_bytes() + raw.read_bytes()).hexdigest()
    }
    write_json(fallback, local)
    return {
        "mode": "USHA_LOCAL_HASH_SEAL",
        "raw": rel(raw),
        "sealed": rel(fallback),
        "sha256": sha_file(fallback),
        "key_location": ".cybra_local_secret/usha.key",
        "git_safe": True
    }

def create_departments():
    departments = {
        "analytics": {
            "department": "CYBRA META EVOLUTION ANALYTICS DEPARTMENT",
            "status": "ACTIVE",
            "scope": "FINANCE_TASKS_ONLY",
            "rule": "ANALYTICS_MUST_ONLY_CONSIDER_EVOLUTIONARY_ACTIONS",
            "allowed_actions": [
                "EVOLUTION_ADD_MODULE_LAYER",
                "EVOLUTION_CREATE_AI_TASK_BLOCK",
                "EVOLUTION_ROUTE_TO_POOL",
                "EVOLUTION_CREATE_COMMITTEE",
                "EVOLUTION_CREATE_HANDLER",
                "EVOLUTION_CREATE_SCHEDULE",
                "EVOLUTION_REPAIR_BROKEN_BLOCK_BY_PEELING_LAST_LAYER",
                "EVOLUTION_RESUBMIT_TO_POOL",
                "EVOLUTION_MARK_DONE_AFTER_OWNER_PASS",
                "EVOLUTION_RETURN_TO_REWORK_IF_NOT_PASS"
            ],
            "safety": SAFETY
        },
        "repair": {
            "department": "CYBRA META EVOLUTION BROKEN BLOCK REPAIR DEPARTMENT",
            "status": "ACTIVE",
            "rule": "BROKEN_BLOCKS_RETURN_TO_POOL_AFTER_LAST_BROKEN_LAYER_IS_REMOVED",
            "safety": SAFETY
        },
        "finance_committee": {
            "department": "CYBRA META EVOLUTION FINANCE COMMITTEE",
            "status": "ACTIVE",
            "scope": "finance tasks, finance proof, finance risk, token proof",
            "safety": SAFETY
        },
        "binary_committee": {
            "department": "CYBRA META EVOLUTION BINARY CODE COMMITTEE",
            "status": "ACTIVE",
            "rule": "rewrite/package missing modules into binary-safe artifacts when needed",
            "safety": SAFETY
        }
    }

    write_json(ROOT / "data/cybra_it_department/meta_evolution_analytics_department/department.json", departments["analytics"])
    write_json(ROOT / "data/cybra_it_department/meta_evolution_repair_department/department.json", departments["repair"])
    write_json(ROOT / "data/cybra_it_department/meta_evolution_finance_committee/department.json", departments["finance_committee"])
    write_json(ROOT / "data/cybra_it_department/meta_evolution_binary_committee/department.json", departments["binary_committee"])

    return {
        "timestamp": now(),
        "status": "META_EVOLUTION_DEPARTMENTS_CREATED",
        "departments": departments
    }

def is_finance_task(obj, path):
    raw = json.dumps(obj, ensure_ascii=False).lower()
    path_l = str(path).lower()
    keys = ["finance", "bank", "psp", "payment", "token", "coin", "kibra", "cybra_finance", "mainnet", "wallet", "proof"]
    return any(k in raw or k in path_l for k in keys)

def discover_tasks():
    tasks = []
    seen = set()

    for d in TASK_DIRS:
        base = ROOT / d
        if not base.exists():
            continue
        for p in sorted(base.glob("*.json")):
            obj = read_json(p, {})
            if not isinstance(obj, dict):
                continue
            if not is_finance_task(obj, p):
                continue

            raw_hash = sha_obj(obj)
            if raw_hash in seen:
                continue
            seen.add(raw_hash)

            tasks.append({
                "source": rel(p),
                "sha256": raw_hash,
                "task_id": obj.get("task_id") or obj.get("id") or obj.get("block_id") or p.stem,
                "title": obj.get("title") or obj.get("objective") or obj.get("status") or "NO_TITLE",
                "status": obj.get("status") or "UNKNOWN",
                "raw": obj
            })

    report = {
        "timestamp": now(),
        "status": "FINANCE_TASKS_DISCOVERED_FOR_META_EVOLUTION",
        "tasks_count": len(tasks),
        "tasks": tasks,
        "rule": "finance only, evolutionary actions only",
        "safety": SAFETY
    }

    write_json(ROOT / "data/cybra_meta_evolution/analytics/discovered_tasks_latest.json", report)
    return report

def existing_layers_for_task(task_hash):
    module_dir = ROOT / "data/cybra_meta_evolution/modules"
    if not module_dir.exists():
        return []
    out = []
    for p in module_dir.glob("*.json"):
        obj = read_json(p, {})
        if obj.get("parent_task_sha256") == task_hash:
            out.append(obj)
    return sorted(out, key=lambda x: x.get("layer_number", 0))

def create_task_ecosystem(task):
    base_id = task["task_id"]
    eco_id = "ECO-" + hashlib.sha256((task["sha256"] + now()).encode()).hexdigest()[:12]

    committees = [
        "finance_execution_committee",
        "analytics_scaling_committee",
        "binary_code_committee",
        "proof_committee",
        "risk_safety_committee",
        "cyber_parliament_review_committee"
    ]

    handlers = [
        "task_intake_handler",
        "finance_scope_handler",
        "module_layer_handler",
        "binary_rewrite_handler",
        "proof_handler",
        "pool_route_handler",
        "broken_layer_repair_handler",
        "owner_pass_handler",
        "return_to_rework_handler"
    ]

    schedules = [
        "every_cycle_scan_unfinished",
        "on_broken_block_peel_last_layer",
        "on_owner_pass_move_to_completed",
        "on_owner_not_pass_return_to_pool",
        "on_missing_module_create_next_layer"
    ]

    ecosystem = {
        "ecosystem_id": eco_id,
        "timestamp": now(),
        "status": "TASK_ECOSYSTEM_CREATED",
        "parent_task_id": base_id,
        "parent_task_sha256": task["sha256"],
        "scope": "FINANCE_ONLY",
        "committees": committees,
        "handlers": handlers,
        "schedules": schedules,
        "policy": {
            "build_modules_around_task": True,
            "scale_into_multiprocess": True,
            "scale_into_superprocess": True,
            "create_new_committees_when_needed": True,
            "return_unfinished_to_rework": True,
            "owner_pass_marks_done": True
        },
        "safety": SAFETY
    }

    write_json(ROOT / f"data/cybra_meta_evolution/tasks/{eco_id}.json", ecosystem)
    write_json(ROOT / f"data/cybra_meta_evolution/handlers/{eco_id}_handlers.json", {
        "ecosystem_id": eco_id,
        "handlers": handlers,
        "safety": SAFETY
    })
    write_json(ROOT / f"data/cybra_meta_evolution/schedules/{eco_id}_schedules.json", {
        "ecosystem_id": eco_id,
        "schedules": schedules,
        "safety": SAFETY
    })

    return ecosystem

def create_layer(task, ecosystem):
    old_layers = existing_layers_for_task(task["sha256"])
    layer_number = len(old_layers) + 1

    layer_id = "META-EVO-LAYER-" + time.strftime("%Y%m%d_%H%M%S") + "-" + hashlib.sha256((task["sha256"] + str(layer_number)).encode()).hexdigest()[:10]

    layer = {
        "layer_id": layer_id,
        "timestamp": now(),
        "status": "EVOLUTION_LAYER_CREATED",
        "action_type": "EVOLUTION_ADD_MODULE_LAYER",
        "parent_task_id": task["task_id"],
        "parent_task_sha256": task["sha256"],
        "ecosystem_id": ecosystem["ecosystem_id"],
        "layer_number": layer_number,
        "module_policy": {
            "add_module_around_task": True,
            "do_not_mutate_original_task": True,
            "scale_analytics_until_task_solution": True,
            "next_layer_allowed_if_task_not_solved": True,
            "finance_scope_only": True
        },
        "evolution_goal": {
            "task_title": task["title"],
            "solution_path": "module_by_module_until_solved",
            "analytics_scope": "evolutionary_actions_only"
        },
        "safety": SAFETY
    }
    layer["sha256"] = sha_obj(layer)

    write_json(ROOT / f"data/cybra_meta_evolution/modules/{layer_id}.json", layer)
    return layer

def create_ai_block_from_layer(layer):
    block_id = "AI-META-EVO-BLOCK-" + time.strftime("%Y%m%d_%H%M%S") + "-" + layer["sha256"][:10]

    block = {
        "block_id": block_id,
        "timestamp": now(),
        "status": "AI_META_EVOLUTION_BLOCK_CREATED",
        "action_type": "EVOLUTION_CREATE_AI_TASK_BLOCK",
        "source_layer_id": layer["layer_id"],
        "source_layer_sha256": layer["sha256"],
        "parent_task_id": layer["parent_task_id"],
        "parent_task_sha256": layer["parent_task_sha256"],
        "ecosystem_id": layer["ecosystem_id"],
        "layer_number": layer["layer_number"],
        "pool_policy": {
            "route_to_kibra_pool": True,
            "route_through_usha_tunnel": True,
            "if_broken_peel_last_layer_and_return": True,
            "if_owner_pass_mark_completed": True,
            "if_not_pass_return_to_rework_pool": True
        },
        "payload": {
            "analytics_scope": "evolution_only_finance_only",
            "task_solution_strategy": "add_module_layer_until_solution",
            "module_layer": layer
        },
        "safety": SAFETY
    }
    block["sha256"] = sha_obj(block)

    write_json(ROOT / f"data/cybra_meta_evolution/blocks/{block_id}.json", block)
    write_json(ROOT / f"blockchain/kibra_chain/meta_evolution_blocks/{block_id}.json", block)
    write_json(ROOT / f"blockchain/kibra_chain/task_blocks/{block_id}.json", block)

    seal = usha_seal(block, block_id)
    routes = {q: redis_push(q, block) for q in QUEUES}

    routed = {
        "timestamp": now(),
        "status": "AI_META_EVOLUTION_BLOCK_ROUTED_TO_POOLS",
        "block_id": block_id,
        "block_file": f"data/cybra_meta_evolution/blocks/{block_id}.json",
        "kibra_block_file": f"blockchain/kibra_chain/meta_evolution_blocks/{block_id}.json",
        "usha_seal": seal,
        "queues": routes,
        "safety": SAFETY
    }

    write_json(ROOT / f"data/cybra_meta_evolution/queues/{block_id}_route.json", routed)
    return routed

def validate_block(obj):
    if not isinstance(obj, dict):
        return False, "not_json_object"
    if not (obj.get("block_id") or obj.get("task_id") or obj.get("layer_id")):
        return False, "missing_id"
    action = obj.get("action_type")
    if action and not str(action).startswith("EVOLUTION_"):
        return False, "non_evolution_action"
    if obj.get("safety", {}).get("automatic_external_tx") is True:
        return False, "external_tx_enabled"
    if obj.get("safety", {}).get("automatic_withdrawals") is True:
        return False, "withdrawals_enabled"
    if obj.get("safety", {}).get("automatic_SWIFT") is True:
        return False, "swift_enabled"
    return True, "ok"

def repair_broken_blocks():
    repair_dir = ROOT / "data/cybra_meta_evolution/repair"
    mkdir(repair_dir)

    candidates = []
    for d in [
        ROOT / "data/cybra_meta_evolution/blocks",
        ROOT / "blockchain/kibra_chain/meta_evolution_blocks",
        ROOT / "blockchain/kibra_chain/task_blocks"
    ]:
        if not d.exists():
            continue
        for p in sorted(d.glob("*.json")):
            obj = read_json(p, None)
            ok, reason = validate_block(obj)
            if not ok:
                candidates.append((p, obj, reason))

    repaired = []

    for p, obj, reason in candidates:
        original_hash = sha_obj(obj) if isinstance(obj, dict) else hashlib.sha256(str(obj).encode()).hexdigest()
        repair_id = "REPAIR-BROKEN-BLOCK-" + time.strftime("%Y%m%d_%H%M%S") + "-" + original_hash[:10]

        archived = repair_dir / f"{repair_id}_original.json"
        write_json(archived, {
            "timestamp": now(),
            "status": "BROKEN_BLOCK_ARCHIVED",
            "source": rel(p),
            "reason": reason,
            "original": obj
        })

        fixed = dict(obj) if isinstance(obj, dict) else {
            "block_id": repair_id,
            "timestamp": now(),
            "status": "REPAIRED_FROM_NON_OBJECT",
            "payload": {}
        }

        layers = fixed.get("layers")
        if isinstance(layers, list) and layers:
            removed = layers.pop()
        else:
            removed = fixed.pop("last_layer", None)

        fixed["repair_id"] = repair_id
        fixed["timestamp"] = now()
        fixed["status"] = "BROKEN_BLOCK_REPAIRED_LAST_LAYER_PEELED"
        fixed["action_type"] = "EVOLUTION_REPAIR_BROKEN_BLOCK_BY_PEELING_LAST_LAYER"
        fixed["broken_reason"] = reason
        fixed["removed_last_broken_layer"] = removed
        fixed["safety"] = SAFETY
        fixed["sha256"] = sha_obj(fixed)

        repaired_file = repair_dir / f"{repair_id}_repaired.json"
        write_json(repaired_file, fixed)

        seal = usha_seal(fixed, repair_id)
        routes = {q: redis_push(q, fixed) for q in QUEUES}

        repaired.append({
            "repair_id": repair_id,
            "source": rel(p),
            "reason": reason,
            "archived": rel(archived),
            "repaired": rel(repaired_file),
            "usha_seal": seal,
            "routes": routes
        })

    report = {
        "timestamp": now(),
        "status": "BROKEN_BLOCK_REPAIR_DONE",
        "broken_count": len(candidates),
        "repaired_count": len(repaired),
        "repaired": repaired,
        "policy": "remove last broken layer and send back to pools",
        "safety": SAFETY
    }

    write_json(ROOT / "data/cybra_meta_evolution/repair/broken_block_repair_latest.json", report)
    return report

def mark_done_or_return(owner_pass=False):
    latest = read_json(ROOT / "data/cybra_meta_evolution/reports/meta_evolution_cycle_latest.json", {})
    status = "OWNER_PASS_COMPLETED" if owner_pass else "RETURNED_TO_REWORK_POOL"

    record = {
        "timestamp": now(),
        "status": status,
        "owner_pass": owner_pass,
        "source_cycle": latest,
        "policy": {
            "if_owner_pass_task_completed": True,
            "if_not_pass_return_to_pool": True
        },
        "safety": SAFETY
    }

    if owner_pass:
        path = ROOT / "data/cybra_meta_evolution/completed/latest_completed_ai_task.json"
        redis_push("cybra:completed:ai_tasks", record)
    else:
        path = ROOT / "data/cybra_meta_evolution/returned/latest_returned_ai_task.json"
        redis_push("cybra:return:ai_tasks", record)
        redis_push("cybra:meta:evolution:pool", record)

    write_json(path, record)
    return record

def evolve_once():
    departments = create_departments()
    discovered = discover_tasks()

    ecosystems = []
    layers = []
    routes = []

    for task in discovered["tasks"]:
        eco = create_task_ecosystem(task)
        ecosystems.append(eco)
        layer = create_layer(task, eco)
        layers.append(layer)
        routes.append(create_ai_block_from_layer(layer))

    repair = repair_broken_blocks()

    report = {
        "timestamp": now(),
        "status": "META_EVOLUTION_FINANCE_CYCLE_DONE",
        "rule": "finance only; analytics considered evolutionary actions only",
        "tasks_discovered": discovered["tasks_count"],
        "ecosystems_created": len(ecosystems),
        "layers_created": len(layers),
        "ai_blocks_routed": len(routes),
        "broken_blocks_repaired": repair.get("repaired_count", 0),
        "departments": departments,
        "routes": routes,
        "repair": repair,
        "safety": SAFETY
    }

    write_json(ROOT / "data/cybra_meta_evolution/reports/meta_evolution_cycle_latest.json", report)
    write_json(ROOT / "feeds/cybra_meta_evolution_cycle.json", report)

    md = f"""# CYBRA Meta Evolution Finance Ecosystem

Status: **{report["status"]}**

## Rule

Analytics considers **finance evolutionary actions only**.

## Cycle

- Finance tasks discovered: `{report["tasks_discovered"]}`
- Task ecosystems created: `{report["ecosystems_created"]}`
- Module layers created: `{report["layers_created"]}`
- AI blocks routed to pools: `{report["ai_blocks_routed"]}`
- Broken blocks repaired: `{report["broken_blocks_repaired"]}`

## Flow

Finance task → ecosystem → committees → handlers → schedules → module layer → AI block → USHA sealed tunnel → KIBRA pools.

Broken block → remove last broken layer → send back to pool.

Owner pass → completed queue.  
No pass → return to rework pool.

## Safety

- real_payment_now: false
- automatic_external_tx: false
- automatic_withdrawals: false
- automatic_SWIFT: false
- automatic_real_rewards: false
"""
    write_text(ROOT / "posts/cybra_meta_evolution_cycle.md", md)

    html = f"""<!doctype html>
<html>
<head><meta charset="utf-8"><title>CYBRA Meta Evolution Finance</title></head>
<body>
<h1>CYBRA Meta Evolution Finance Ecosystem</h1>
<p>Status: <b>{report["status"]}</b></p>
<p>Finance tasks discovered: <code>{report["tasks_discovered"]}</code></p>
<p>Ecosystems: <code>{report["ecosystems_created"]}</code></p>
<p>Layers: <code>{report["layers_created"]}</code></p>
<p>AI blocks routed: <code>{report["ai_blocks_routed"]}</code></p>
<p>Broken repaired: <code>{report["broken_blocks_repaired"]}</code></p>
<p>Rule: finance evolutionary actions only.</p>
</body>
</html>
"""
    write_text(ROOT / "dashboard/cybra_meta_evolution/index.html", html)

    proof_targets = [
        ROOT / "data/cybra_meta_evolution/reports/meta_evolution_cycle_latest.json",
        ROOT / "data/cybra_meta_evolution/analytics/discovered_tasks_latest.json",
        ROOT / "data/cybra_meta_evolution/repair/broken_block_repair_latest.json",
        ROOT / "posts/cybra_meta_evolution_cycle.md",
        ROOT / "feeds/cybra_meta_evolution_cycle.json",
        ROOT / "dashboard/cybra_meta_evolution/index.html",
        ROOT / "scripts/meta_evolution/cybra_meta_evolution.py"
    ]

    lines = []
    for p in proof_targets:
        if p.exists():
            lines.append(f"{sha_file(p)}  {rel(p)}\n")
    write_text(ROOT / "proofs/cybra_meta_evolution_cycle.sha256", "".join(lines))

    return report

def status():
    p = ROOT / "posts/cybra_meta_evolution_cycle.md"
    print(p.read_text(encoding="utf-8") if p.exists() else "No cycle yet. Run: cybra-meta-evo cycle")

def proof():
    p = ROOT / "proofs/cybra_meta_evolution_cycle.sha256"
    if not p.exists():
        print("No proof yet")
        return
    subprocess.call("sha256sum -c proofs/cybra_meta_evolution_cycle.sha256", shell=True, cwd=ROOT)

def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "cycle"
    if cmd == "departments":
        print(json.dumps(create_departments(), ensure_ascii=False, indent=2))
    elif cmd == "scan":
        print(json.dumps(discover_tasks(), ensure_ascii=False, indent=2))
    elif cmd == "cycle":
        print(json.dumps(evolve_once(), ensure_ascii=False, indent=2))
    elif cmd == "repair":
        print(json.dumps(repair_broken_blocks(), ensure_ascii=False, indent=2))
    elif cmd == "done":
        print(json.dumps(mark_done_or_return(True), ensure_ascii=False, indent=2))
    elif cmd == "return":
        print(json.dumps(mark_done_or_return(False), ensure_ascii=False, indent=2))
    elif cmd == "status":
        status()
    elif cmd == "proof":
        proof()
    else:
        print("Commands: cycle | scan | repair | departments | done | return | status | proof")

if __name__ == "__main__":
    main()
