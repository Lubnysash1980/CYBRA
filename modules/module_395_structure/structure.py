#!/usr/bin/env python3
"""Structure Guardian — карта canonical структури CYBRA.

Зберігає що де має бути. Перевіряє цілісність.
Знаходить мінімальний робочий граф якщо все зламано.
"""
import hashlib, json, os, sys, time
from pathlib import Path

H = Path.home() / "CYBRA"
M = H / "modules"
D = Path(__file__).resolve().parent
STRUCT = D / "data" / "structure.json"
MINIMAL = D / "data" / "minimal.json"

def _now(): return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

# ═══ CANONICAL STRUCTURE ═══
# Що де має бути (топ-рівень + критичні файли)
CANONICAL = {
    "root": ["modules","config","bin","public","logs","run"],
    "critical_modules": [
        "module_19_contract_tui_menu/bin/cybra_menu.sh",
        "module_108_metamask_sign/main.sh",
        "module_114_autonode/daemon.py",
        "module_121_parlament/parliament.py",
        "module_121_parlament/health.py",
        "module_121_parlament/controller_gate.py",
        "module_320_controllers/controllers.py",
        "module_330_selfheal/engine.py",
        "module_350_controller_worker/worker.py",
        "module_360_mapping/mapping.py",
        "module_380_sic/sic.py",
        "module_390_src/src.py",
    ],
    "critical_configs": [
        "config/networks.json",
        "config/metamask.env",
        "config/pm_processes.json",
    ],
    "external": [
        "../.cybra_src/bootstrap_seed.sh",
        "../.cybra_src/checkpoint.json",
    ],
}

# ═══ SCAN ═══
def _hash_file(p):
    if not p.exists(): return None
    try:
        h = hashlib.sha256()
        with open(p, "rb") as f:
            for chunk in iter(lambda: f.read(65536), b""):
                h.update(chunk)
        return h.hexdigest()
    except Exception: return None

def scan_current():
    """Повний знімок структури."""
    out = {"at": _now(), "files": {}, "missing": [], "extra_critical": []}
    # critical modules
    for rel in CANONICAL["critical_modules"]:
        p = M / rel
        h = _hash_file(p)
        if h:
            out["files"][f"modules/{rel}"] = {"hash": h, "size": p.stat().st_size}
        else:
            out["missing"].append(f"modules/{rel}")
    # configs
    for rel in CANONICAL["critical_configs"]:
        p = H / rel
        h = _hash_file(p)
        if h:
            out["files"][rel] = {"hash": h, "size": p.stat().st_size}
        else:
            out["missing"].append(rel)
    # external
    for rel in CANONICAL["external"]:
        p = (H / rel).resolve()
        h = _hash_file(p)
        if h:
            out["files"][rel] = {"hash": h, "size": p.stat().st_size}
        else:
            out["missing"].append(rel)
    # root dirs
    for d in CANONICAL["root"]:
        p = H / d
        if not p.exists():
            out["missing"].append(f"{d}/ (dir)")
    return out

def save_structure(snap=None):
    if snap is None: snap = scan_current()
    tmp = STRUCT.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(snap, indent=2, ensure_ascii=False))
    os.replace(tmp, STRUCT)
    return snap

def load_structure():
    if not STRUCT.exists(): return None
    try: return json.loads(STRUCT.read_text())
    except Exception: return None

# ═══ VERIFY ═══
def verify():
    """Порівнює поточний стан з canonical."""
    canonical = load_structure()
    current = scan_current()
    diff = {"ok": [], "missing": [], "changed": [], "at": _now()}
    if canonical:
        for rel, info in canonical["files"].items():
            if rel not in current["files"]:
                diff["missing"].append(rel)
            elif current["files"][rel]["hash"] != info["hash"]:
                diff["changed"].append({
                    "file": rel,
                    "old_hash": info["hash"][:12],
                    "new_hash": current["files"][rel]["hash"][:12],
                    "old_size": info["size"],
                    "new_size": current["files"][rel]["size"],
                })
            else:
                diff["ok"].append(rel)
    for rel in current["missing"]:
        if rel not in diff["missing"]:
            diff["missing"].append(rel)
    return diff

# ═══ MINIMAL GRAPH ═══
def build_minimal():
    """Мінімальний робочий граф — те без чого CYBRA не працює."""
    minimal = {
        "at": _now(),
        "description": "Мінімум для роботи CYBRA",
        "required": [
            "modules/module_19_contract_tui_menu/bin/cybra_menu.sh",
            "modules/module_121_parlament/parliament.py",
            "modules/module_121_parlament/health.py",
            "modules/module_320_controllers/controllers.py",
            "modules/module_330_selfheal/engine.py",
            "modules/module_390_src/src.py",
            "config/networks.json",
            "config/pm_processes.json",
            "bin/cybra",
        ],
        "processes": [
            "watchdog", "supervisor", "selfheal", "src",
        ],
        "fallback": "Якщо < 3 модулі з required — викликати 396 recovery",
    }
    MINIMAL.write_text(json.dumps(minimal, indent=2, ensure_ascii=False))
    return minimal

def minimal_ok():
    """Чи є мінімум."""
    if not MINIMAL.exists(): build_minimal()
    m = json.loads(MINIMAL.read_text())
    present = []
    missing = []
    for rel in m["required"]:
        p = H / rel
        if p.exists() and p.stat().st_size > 0:
            present.append(rel)
        else:
            missing.append(rel)
    return len(present) >= 3, {"present": present, "missing": missing}

# ═══ CLI ═══
if __name__ == "__main__":
    import sys
    G='\033[32m'; R='\033[31m'; Y='\033[33m'; B='\033[36m'; D='\033[2m'; BOLD='\033[1m'; N='\033[0m'
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"

    if cmd == "build":
        snap = save_structure()
        print(f"  ✓ structure: {len(snap['files'])} файлів")
        build_minimal()
        print(f"  ✓ minimal: {len(json.loads(MINIMAL.read_text())['required'])} required")

    elif cmd == "verify":
        d = verify()
        print(f"\n  {B}{BOLD}Structure Verify{N}\n")
        print(f"  {G}✓{N} OK:      {len(d['ok'])}")
        print(f"  {R}✗{N} Missing: {len(d['missing'])}")
        print(f"  {Y}!{N} Changed: {len(d['changed'])}")
        if d["missing"]:
            print(f"\n  {B}Відсутні:{N}")
            for m in d["missing"][:10]: print(f"    ✗ {m}")
        if d["changed"]:
            print(f"\n  {B}Змінені:{N}")
            for c in d["changed"][:10]:
                print(f"    ! {c['file']}: {c['old_size']}B → {c['new_size']}B")

    elif cmd == "minimal":
        ok, info = minimal_ok()
        col = G if ok else R
        print(f"\n  {col}Minimal graph: {'OK' if ok else 'BROKEN'}{N}")
        print(f"  present: {len(info['present'])}")
        for p in info["present"]: print(f"    {G}✓{N} {p}")
        print(f"  missing: {len(info['missing'])}")
        for p in info["missing"]: print(f"    {R}✗{N} {p}")

    elif cmd == "json":
        print(json.dumps(verify(), indent=2, ensure_ascii=False))
