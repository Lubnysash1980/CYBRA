#!/usr/bin/env python3
"""Exoskeleton — зовнішня оболонка. Захищає критичні модулі від змін."""
import json, os, hashlib, time
from pathlib import Path
H = Path.home() / "CYBRA"
D = Path(__file__).resolve().parent
STATE = D / "data" / "shell.json"

CRITICAL = [
    "modules/module_121_parlament/parliament.py",
    "modules/module_121_parlament/controller_gate.py",
    "modules/module_19_contract_tui_menu/bin/cybra_menu.sh",
    "modules/module_108_metamask_sign/main.sh",
    "modules/module_320_controllers/controllers.py",
]

def _hash(p):
    if not p.exists(): return None
    return hashlib.sha256(p.read_bytes()).hexdigest()

def _load():
    if not STATE.exists(): return {"protected": {}}
    try: return json.loads(STATE.read_text())
    except Exception: return {"protected": {}}

def _save(d): STATE.write_text(json.dumps(d, indent=2))

def lock():
    """Зафіксувати поточні хеші."""
    d = _load()
    now = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    for rel in CRITICAL:
        p = H / rel
        h = _hash(p)
        if h:
            d["protected"][rel] = {"hash": h, "at": now}
    _save(d)
    return True, f"locked {len(d['protected'])} файлів"

def check():
    """Перевірити чи файли змінені."""
    d = _load()
    issues = []
    for rel, info in d.get("protected", {}).items():
        p = H / rel
        current = _hash(p)
        if current is None:
            issues.append({"file": rel, "reason": "missing"})
        elif current != info["hash"]:
            issues.append({"file": rel, "reason": "modified"})
    return issues

def is_ok():
    """True якщо все під захистом."""
    d = _load()
    if not d.get("protected"): return False
    return len(check()) == 0

if __name__ == "__main__":
    import sys
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "status":
        d = _load()
        issues = check()
        G='\033[32m'; R='\033[31m'; Y='\033[33m'; N='\033[0m'
        print(f"\n  Exoskeleton: {len(d.get('protected', {}))} файлів під захистом")
        if not d.get("protected"):
            print(f"  {Y}!{N} ще не активовано — викличи 'lock'")
        elif issues:
            print(f"  {R}✗{N} {len(issues)} проблем:")
            for i in issues:
                print(f"    · {i['file']}: {i['reason']}")
        else:
            print(f"  {G}✓{N} всі файли незмінні")
        print()
    elif cmd == "lock":
        ok, msg = lock(); print(f"✓ {msg}")
    elif cmd == "check":
        sys.exit(0 if is_ok() else 1)
