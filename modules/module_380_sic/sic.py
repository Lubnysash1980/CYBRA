#!/usr/bin/env python3
"""System Integration Controller (SIC) — координатор всієї CYBRA.

Ролі:
  · Реєстр модулів + integration points (хто від кого залежить)
  · Event Bus — модулі публікують події, SIC роутить підписникам
  · Conflict Resolver — коли 2 модулі хочуть один ресурс
  · Orchestration — ланцюги дій (A → B → C)
  · Integration Matrix — карта зв'язків
  · Snapshot — повний стан системи для Worker/Parliament
"""
import json, os, subprocess, sys, time, hashlib
from pathlib import Path
from collections import defaultdict

H = Path.home() / "CYBRA"
M = H / "modules"
D = Path(__file__).resolve().parent
REGISTRY = D / "data" / "registry.json"
EVENTS = D / "data" / "events"
BUS = D / "data" / "bus.jsonl"
CONFLICTS = D / "data" / "conflicts.jsonl"

def _now(): return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
def _now_unix(): return int(time.time())

# ═══════════════════════════════════════════════════════════════
# REGISTRY — карта модулів + взаємодій
# ═══════════════════════════════════════════════════════════════
# Кожен модуль: {provides, consumes, resources, events_pub, events_sub}
REGISTRY_DATA = {
    # ── Ядро ──
    "121": {"name":"parliament", "provides":["governance","audit","hash_chain"],
            "consumes":["signatures","controllers_ok"], "resources":["data/proposals.jsonl"],
            "pub":["proposal_created","proposal_approved","vote_cast"],
            "sub":["controller_change","signature_added"]},
    "320": {"name":"controllers", "provides":["health_check"],
            "consumes":["all_module_state"], "resources":[],
            "pub":["controller_change"], "sub":[]},
    "330": {"name":"selfheal", "provides":["auto_heal"],
            "consumes":["controller_state","health"], "resources":[],
            "pub":["heal_action","heal_done"], "sub":["controller_change","health_drop"]},
    "340": {"name":"payment_confirm", "provides":["nbu_qr"],
            "consumes":["invoice","health_100"], "resources":[],
            "pub":["payment_initiated"], "sub":["invoice_signed"]},
    "341": {"name":"dual_confirm", "provides":["dual_signature"],
            "consumes":["invoice","signature"], "resources":[],
            "pub":["receipt_signed","receipt_expired"], "sub":["delivered","order_signed"]},
    "350": {"name":"controller_worker", "provides":["heal_loop"],
            "consumes":["controllers","health","completion","mapping"], "resources":[],
            "pub":["worker_cycle"], "sub":["health_drop","controller_change"]},
    "360": {"name":"mapping", "provides":["priority_map","role_map"],
            "consumes":["modules","controllers"], "resources":[],
            "pub":[], "sub":["module_added","module_removed"]},
    "370": {"name":"runtime", "provides":["job_execution"],
            "consumes":["jobs"], "resources":["data/jobs/"], "pub":["job_done","job_failed"],
            "sub":["submit_job"]},
    "371": {"name":"job_controller", "provides":["failover","runtime_guard"],
            "consumes":["runtime_state","binmixer_state"], "resources":[],
            "pub":["failover_started","failover_done"], "sub":["runtime_down","runtime_up"]},
    "380": {"name":"sic", "provides":["integration","routing","snapshot"],
            "consumes":["all"], "resources":["data/registry.json"], "pub":["sic_event"], "sub":["all"]},

    # ── Blockchain ──
    "108": {"name":"metamask_sign", "provides":["signature"],
            "consumes":["contract","health_100"], "resources":[],
            "pub":["signature_added"], "sub":["contract_created"]},
    "109": {"name":"metamask_verify", "provides":["verification"],
            "consumes":["signature"], "resources":[], "pub":[], "sub":["signature_added"]},
    "114": {"name":"autonode", "provides":["chain_state"],
            "consumes":["networks_config"], "resources":["run/autonode.json"],
            "pub":["block_new","rpc_fail","rpc_recover"], "sub":["network_switch"]},
    "119": {"name":"qr_sign", "provides":["qr_proof"],
            "consumes":["signature"], "resources":[], "pub":["qr_generated"], "sub":["signature_added"]},
    "124": {"name":"timelock", "provides":["timelock"],
            "consumes":["contract"], "resources":[], "pub":["lock_created","lock_released"], "sub":[]},
    "125": {"name":"anchor", "provides":["on_chain_anchor"],
            "consumes":["hash"], "resources":[], "pub":["anchor_confirmed"], "sub":[]},
    "137": {"name":"escrow", "provides":["escrow"],
            "consumes":["contract","payment"], "resources":[], "pub":["escrow_funded","escrow_released"], "sub":[]},

    # ── Контракти ──
    "1":  {"name":"create_contract", "provides":["contract"],
            "consumes":["buyer","items"], "resources":[], "pub":["contract_created"], "sub":[]},
    "11": {"name":"invoice", "provides":["invoice"],
            "consumes":["contract"], "resources":["data/"], "pub":["invoice_created"], "sub":["contract_created"]},
    "122":{"name":"validator", "provides":["validation"],
            "consumes":["contract"], "resources":[], "pub":["validated"], "sub":["contract_created"]},
    "123":{"name":"multisig", "provides":["multisig"],
            "consumes":["signatures"], "resources":[], "pub":["ms_complete"], "sub":["signature_added"]},
    "131":{"name":"kyc", "provides":["sanctions_check"],
            "consumes":["address"], "resources":["data/lists/"], "pub":["kyc_clean","kyc_sanctioned"], "sub":["address_added"]},

    # ── Дані ──
    "92": {"name":"autosave", "provides":["backup"],
            "consumes":["data"], "resources":["backups/"], "pub":["saved"], "sub":[]},
    "61": {"name":"backup_local", "provides":["local_backup"],
            "consumes":["data"], "resources":["backups/"], "pub":[], "sub":[]},
    "62": {"name":"backup_cloud", "provides":["cloud_backup"],
            "consumes":["data"], "resources":[], "pub":[], "sub":[]},

    # ── Infrastructure ──
    "128":{"name":"dashboard", "provides":["ui"], "consumes":["all_state"],
            "resources":["run/dash.pid"], "pub":[], "sub":["state_change"]},
    "143":{"name":"email", "provides":["send_email"], "consumes":["smtp_config"],
            "resources":[], "pub":["email_sent"], "sub":[]},
    "144":{"name":"lightning", "provides":["ln_payment"], "consumes":["ln_config"],
            "resources":[], "pub":["ln_invoice","ln_paid"], "sub":[]},
    "145":{"name":"ipfs", "provides":["ipfs_pin"], "consumes":["file"],
            "resources":[], "pub":["pinned"], "sub":[]},
    "146":{"name":"merkle", "provides":["batch_proof"], "consumes":["hashes"],
            "resources":[], "pub":[], "sub":[]},
}

def build_registry():
    """Генерує повний реєстр з диску + базової карти."""
    reg = {}
    for mid, cfg in REGISTRY_DATA.items():
        path = None
        for d in sorted(M.glob(f"module_{mid.zfill(3)}_*")) + sorted(M.glob(f"module_{mid}_*")):
            if (d/"main.sh").exists(): path = d.name; break
        reg[mid] = {
            "id": mid, "name": cfg["name"],
            "path": path or f"builtin:{cfg['name']}",
            "provides": cfg.get("provides", []),
            "consumes": cfg.get("consumes", []),
            "resources": cfg.get("resources", []),
            "events_pub": cfg.get("pub", []),
            "events_sub": cfg.get("sub", []),
            "mapped": path is not None,
        }
    out = {"version":"1.0", "built":_now(), "total":len(reg), "modules":reg}
    REGISTRY.write_text(json.dumps(out, indent=2, ensure_ascii=False))
    return out

def load_registry():
    if not REGISTRY.exists(): return build_registry()
    try: return json.loads(REGISTRY.read_text())
    except Exception: return build_registry()

# ═══════════════════════════════════════════════════════════════
# INTEGRATION MATRIX — хто з ким
# ═══════════════════════════════════════════════════════════════
def integration_matrix():
    reg = load_registry()["modules"]
    matrix = defaultdict(lambda: {"in":[], "out":[], "shared_resources":[]})
    # providers index
    providers = defaultdict(list)
    for mid, m in reg.items():
        for p in m["provides"]: providers[p].append(mid)
    # resources index
    resources = defaultdict(list)
    for mid, m in reg.items():
        for r in m["resources"]: resources[r].append(mid)

    for mid, m in reg.items():
        # хто надає те що я споживаю
        for c in m["consumes"]:
            for p in providers.get(c, []):
                if p != mid:
                    matrix[mid]["in"].append({"from": p, "what": c})
        # хто споживає те що я надаю
        for p in m["provides"]:
            for oid, om in reg.items():
                if oid == mid: continue
                if p in om["consumes"]:
                    matrix[mid]["out"].append({"to": oid, "what": p})
        # конфлікти ресурсів
        for r in m["resources"]:
            others = [x for x in resources.get(r, []) if x != mid]
            if others:
                matrix[mid]["shared_resources"].append({"resource": r, "with": others})

    return dict(matrix)

# ═══════════════════════════════════════════════════════════════
# EVENT BUS — pub/sub
# ═══════════════════════════════════════════════════════════════
def publish(event_type, payload, source):
    """Публікує подію у bus."""
    ev = {
        "id": hashlib.sha256(f"{event_type}{_now_unix()}{source}".encode()).hexdigest()[:12],
        "type": event_type, "source": source, "payload": payload,
        "at": _now(), "at_unix": _now_unix(),
    }
    with open(BUS, "a") as f: f.write(json.dumps(ev, ensure_ascii=False) + "\n")
    # ротація
    try:
        if BUS.stat().st_size > 2_000_000:
            lines = BUS.read_text().splitlines()
            BUS.write_text("\n".join(lines[-2000:]) + "\n")
    except Exception: pass
    # роутинг
    subscribers = find_subscribers(event_type)
    return {"event": ev, "subscribers": subscribers}

def find_subscribers(event_type):
    reg = load_registry()["modules"]
    return [mid for mid, m in reg.items() if event_type in m["events_sub"]]

def recent_events(n=50):
    if not BUS.exists(): return []
    out = []
    for line in BUS.read_text().splitlines()[-n:]:
        try: out.append(json.loads(line))
        except Exception: pass
    return out

def dispatch(event_type, payload, source, dry_run=False):
    """Публікує + показує кому піде."""
    r = publish(event_type, payload, source)
    subs = r["subscribers"]
    results = []
    if not dry_run:
        for mid in subs:
            m = load_registry()["modules"].get(mid)
            if not m: continue
            # тут можна викликати main.sh або хук
            results.append({"module": mid, "name": m["name"], "dispatched": True})
    return {"event": r["event"], "subscribers": subs, "results": results}

# ═══════════════════════════════════════════════════════════════
# CONFLICT RESOLVER
# ═══════════════════════════════════════════════════════════════
def detect_conflicts():
    """Знаходить конфлікти між модулями."""
    conflicts = []
    reg = load_registry()["modules"]

    # 1. Спільні ресурси
    resources = defaultdict(list)
    for mid, m in reg.items():
        for r in m["resources"]:
            resources[r].append(mid)
    for r, ids in resources.items():
        if len(ids) > 1:
            conflicts.append({"type":"shared_resource", "resource": r,
                            "modules": ids, "severity":"warn",
                            "resolution": f"lock_resource({r})"})

    # 2. Кільцеві залежності
    graph = {mid: [] for mid in reg}
    for mid, m in reg.items():
        for c in m["consumes"]:
            for oid, om in reg.items():
                if oid != mid and c in om["provides"]:
                    graph[mid].append(oid)
    # DFS cycle detection
    visited = set(); stack = set(); cycles = []
    def dfs(node, path):
        if node in stack:
            cycles.append(path[path.index(node):] + [node])
            return
        if node in visited: return
        visited.add(node); stack.add(node)
        for nxt in graph.get(node, []):
            dfs(nxt, path + [nxt])
        stack.discard(node)
    for n in graph:
        if n not in visited: dfs(n, [n])
    for cyc in cycles:
        conflicts.append({"type":"cycle", "path": cyc, "severity":"critical",
                        "resolution": "break_cycle"})

    # 3. Pub без sub
    all_subs = set()
    for m in reg.values(): all_subs.update(m["events_sub"])
    for mid, m in reg.items():
        for ev in m["events_pub"]:
            if ev not in all_subs:
                conflicts.append({"type":"orphan_event", "module": mid,
                                "event": ev, "severity":"info",
                                "resolution":"log_only"})

    # лог
    if conflicts:
        with open(CONFLICTS, "a") as f:
            f.write(json.dumps({"at":_now(), "count":len(conflicts), "items":conflicts}) + "\n")

    return conflicts

def resolve_conflicts(auto=True):
    """Вирішує конфлікти."""
    conflicts = detect_conflicts()
    fixed = []
    for c in conflicts:
        if c["type"] == "shared_resource" and auto:
            # створюємо lockfile
            lock = D / "data" / f"lock_{c['resource'].replace('/','_')}.lock"
            if not lock.exists():
                lock.write_text(json.dumps({"at":_now(), "owners":c["modules"]}))
                fixed.append(("lock_created", c["resource"]))
        elif c["type"] == "cycle":
            fixed.append(("cycle_detected", "manual_review_required"))
    return {"total": len(conflicts), "fixed": fixed}

# ═══════════════════════════════════════════════════════════════
# ORCHESTRATION — ланцюги дій
# ═══════════════════════════════════════════════════════════════
ORCHESTRATIONS = {
    "new_contract": [
        {"step": 1, "event": "contract_created", "from": "1", "wait_for": None},
        {"step": 2, "event": "invoice_created", "from": "11", "wait_for": "contract_created"},
        {"step": 3, "event": "validated", "from": "122", "wait_for": "invoice_created"},
        {"step": 4, "event": "signature_added", "from": "108", "wait_for": "validated"},
        {"step": 5, "event": "qr_generated", "from": "119", "wait_for": "signature_added"},
    ],
    "payment_flow": [
        {"step": 1, "event": "invoice_signed", "from": "108", "wait_for": None},
        {"step": 2, "event": "nbu_qr", "from": "340", "wait_for": "invoice_signed"},
        {"step": 3, "event": "payment_initiated", "from": "340", "wait_for": "nbu_qr"},
        {"step": 4, "event": "delivered", "from": "341", "wait_for": "payment_initiated"},
        {"step": 5, "event": "receipt_signed", "from": "341", "wait_for": "delivered"},
    ],
    "failover": [
        {"step": 1, "event": "runtime_down", "from": "371", "wait_for": None},
        {"step": 2, "event": "failover_started", "from": "371", "wait_for": "runtime_down"},
        {"step": 3, "event": "failover_done", "from": "371", "wait_for": "failover_started"},
        {"step": 4, "event": "runtime_up", "from": "371", "wait_for": "failover_done"},
    ],
}

def orchestrate(name, dry_run=True):
    """Прогоняє ланцюг подій."""
    chain = ORCHESTRATIONS.get(name)
    if not chain: return None
    result = {"name": name, "steps": [], "at": _now()}
    for step in chain:
        sub = find_subscribers(step["event"])
        result["steps"].append({
            **step,
            "subscribers": sub,
            "status": "ready" if sub else "no_subscribers",
        })
    return result

# ═══════════════════════════════════════════════════════════════
# SNAPSHOT — повний стан для Worker/Parliament
# ═══════════════════════════════════════════════════════════════
def snapshot():
    """Повний знімок інтеграційної карти."""
    reg = load_registry()
    matrix = integration_matrix()
    conflicts = detect_conflicts()
    events = recent_events(10)
    return {
        "at": _now(),
        "modules_total": reg["total"],
        "modules_mapped": sum(1 for m in reg["modules"].values() if m["mapped"]),
        "matrix_edges": sum(len(v["in"]) for v in matrix.values()),
        "conflicts": len(conflicts),
        "recent_events": len(events),
        "top_conflicts": conflicts[:5],
        "recent": events[-5:],
    }

# ═══════════════════════════════════════════════════════════════
# CLI
# ═══════════════════════════════════════════════════════════════
if __name__ == "__main__":
    import sys
    G='\033[32m'; Y='\033[33m'; R='\033[31m'; B='\033[36m'; D='\033[2m'; BOLD='\033[1m'; N='\033[0m'
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"

    if cmd == "build":
        reg = build_registry()
        print(f"  {G}✓{N} registry: {reg['total']} модулів")

    elif cmd == "status":
        s = snapshot()
        print(f"\n  {B}{BOLD}═══ SIC Snapshot ═══{N}\n")
        print(f"  Модулів:       {s['modules_total']}")
        print(f"  Mapped:        {s['modules_mapped']}")
        print(f"  Integration:   {s['matrix_edges']} зв'язків")
        print(f"  Конфлікти:     {s['conflicts']}")
        print(f"  Events (last): {s['recent_events']}")
        if s["top_conflicts"]:
            print(f"\n  {B}Топ конфліктів:{N}")
            for c in s["top_conflicts"]:
                col = R if c["severity"]=="critical" else (Y if c["severity"]=="warn" else D)
                print(f"    {col}[{c['severity']}]{N} {c['type']}: {str(c.get('resource') or c.get('path') or c.get('event'))[:60]}")

    elif cmd == "matrix":
        m = integration_matrix()
        reg = load_registry()["modules"]
        for mid in sorted(m.keys(), key=lambda x: int(x)):
            d = m[mid]
            if not d["in"] and not d["out"]: continue
            name = reg[mid]["name"]
            print(f"\n  {B}[{mid}] {name}{N}")
            if d["in"]:
                for x in d["in"][:5]:
                    print(f"    ← {x['from']} ({x['what']})")
            if d["out"]:
                for x in d["out"][:5]:
                    print(f"    → {x['to']} ({x['what']})")
            if d["shared_resources"]:
                for x in d["shared_resources"]:
                    print(f"    ⚠ shared: {x['resource']} with {x['with']}")

    elif cmd == "conflicts":
        cs = detect_conflicts()
        if not cs:
            print(f"  {G}✓{N} конфліктів немає")
        else:
            for c in cs:
                col = R if c["severity"]=="critical" else (Y if c["severity"]=="warn" else D)
                print(f"  {col}[{c['severity']:8s}]{N} {c['type']:18s}  {str(c.get('resource') or c.get('path') or c.get('event') or '')[:60]}")

    elif cmd == "publish":
        ev_type = sys.argv[2]
        src = sys.argv[3] if len(sys.argv) > 3 else "manual"
        payload = json.loads(sys.argv[4]) if len(sys.argv) > 4 else {}
        r = dispatch(ev_type, payload, src)
        print(json.dumps(r, indent=2, ensure_ascii=False))

    elif cmd == "events":
        for e in recent_events(30):
            print(f"  {e['at']}  {e['type']:24s}  from {e['source']}")

    elif cmd == "orchestrate":
        name = sys.argv[2]
        r = orchestrate(name)
        if not r:
            print(f"  ✗ немає ланцюга {name}")
            sys.exit(1)
        print(json.dumps(r, indent=2, ensure_ascii=False))

    elif cmd == "orchestrations":
        for name in ORCHESTRATIONS:
            print(f"  · {name} ({len(ORCHESTRATIONS[name])} кроків)")

    elif cmd == "json":
        print(json.dumps(snapshot(), indent=2, ensure_ascii=False))
