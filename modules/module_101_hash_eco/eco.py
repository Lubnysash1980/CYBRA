#!/usr/bin/env python3
"""Hash Ecosystem — 5 шарів хешів.
  1. Cascade snapshots
  2. Contracts (.sig)
  3. Health + 100% gate
  4. Parliament (proposals/votes)
  5. Combined master hash
"""
import hashlib, json, os, sys, time
from pathlib import Path

H = Path.home() / "CYBRA"
M = H / "modules"
SRC = Path.home() / ".cybra_src"
D = Path(__file__).resolve().parent

def _now(): return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

def layer_cascade():
    """Шар 1: каскад snapshot."""
    try:
        sys.path.insert(0, str(M/"module_401_cascade_verify"))
        import verify
        h, _ = verify.cascade_hash()
        return h
    except Exception: return "0"*64

def layer_contracts():
    """Шар 2: контракти (C-INV + .sig)."""
    E = M / "module_19_contract_tui_menu/evidence"
    if not E.exists(): return hashlib.sha256(b"empty").hexdigest()
    h = hashlib.sha256()
    for f in sorted(E.glob("C-INV-*")):
        try:
            h.update(f.name.encode())
            h.update(f.read_bytes())
        except Exception: pass
    return h.hexdigest()

def layer_health():
    """Шар 3: health + 100% gate."""
    parts = {}
    try:
        sys.path.insert(0, str(M/"module_121_parlament"))
        import health
        h = health.health_all()
        parts["health"] = h.get("overall", 0)
    except Exception: parts["health"] = 0
    try:
        sys.path.insert(0, str(M/"module_399_gate"))
        import gate
        ok, s = gate.is_100()
        parts["gate"] = ok
    except Exception: parts["gate"] = False
    try:
        import completion
        parts["completion"] = completion.completion_score().get("overall", 0)
    except Exception: parts["completion"] = 0
    return hashlib.sha256(json.dumps(parts, sort_keys=True).encode()).hexdigest(), parts

def layer_parliament():
    """Шар 4: парламент (proposals/votes/audit)."""
    try:
        sys.path.insert(0, str(M/"module_121_parlament"))
        import parliament as P
        r = P.verify_chain()
        return hashlib.sha256(json.dumps(r, sort_keys=True).encode()).hexdigest(), r
    except Exception: return "0"*64, {}

def layers():
    """Всі 5 шарів."""
    l1 = layer_cascade()
    l2 = layer_contracts()
    l3, h_info = layer_health()
    l4, p_info = layer_parliament()
    combined = {
        "cascade": l1, "contracts": l2, "health_gate": l3, "parliament": l4,
        "at": _now(),
    }
    master = hashlib.sha256(json.dumps(combined, sort_keys=True).encode()).hexdigest()
    return {
        "at": _now(),
        "layers": {
            "1_cascade": l1, "2_contracts": l2, "3_health_gate": l3, "4_parliament": l4,
        },
        "master": master,
        "health": h_info,
        "parliament": p_info,
    }

if __name__ == "__main__":
    import sys
    G='\033[32m'; R='\033[31m'; B='\033[36m'; BOLD='\033[1m'; D='\033[2m'; N='\033[0m'
    cmd = sys.argv[1] if len(sys.argv) > 1 else "show"
    if cmd in ("show",""):
        r = layers()
        print(f"\n  {B}{BOLD}═══ HASH ECOSYSTEM ═══{N}\n")
        print(f"  {B}Шар 1 · Cascade:{N}     {r['layers']['1_cascade'][:32]}…")
        print(f"  {B}Шар 2 · Contracts:{N}   {r['layers']['2_contracts'][:32]}…")
        print(f"  {B}Шар 3 · Health+Gate:{N} {r['layers']['3_health_gate'][:32]}…")
        print(f"  {B}Шар 4 · Parliament:{N}  {r['layers']['4_parliament'][:32]}…")
        print(f"\n  {B}{BOLD}MASTER HASH:{N}")
        print(f"  {G}{r['master']}{N}\n")
    elif cmd == "json":
        print(json.dumps(layers(), indent=2, ensure_ascii=False))
    elif cmd == "hash":
        print(layers()["master"])
