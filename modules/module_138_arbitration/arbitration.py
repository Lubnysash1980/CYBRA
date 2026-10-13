#!/usr/bin/env python3
"""Автоматичний арбітраж: правила для вирішення спорів на основі 65/121."""
import json, os, sys, time
from pathlib import Path
D = Path(__file__).resolve().parent
H = Path.home() / "CYBRA"
DATA = D / "data"; DATA.mkdir(exist_ok=True)
RULES = DATA / "rules.jsonl"

DEFAULT_RULES = [
    {"id":"dev_small",  "if":"deviation_pct <= 3",     "then":"accept",       "priority":10},
    {"id":"dev_med",    "if":"deviation_pct <= 10",    "then":"arbiter_vote", "priority":20},
    {"id":"dev_large",  "if":"deviation_pct > 10",     "then":"reject_refund","priority":30},
    {"id":"no_proof",   "if":"no proof after 7d",      "then":"refund",       "priority":40},
    {"id":"mutual_ok",  "if":"both confirm",           "then":"release",      "priority":5},
]

def _now(): return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

def load_rules():
    if not RULES.exists(): return list(DEFAULT_RULES)
    out = []
    for line in RULES.read_text().splitlines():
        try: out.append(json.loads(line))
        except Exception: pass
    return out or list(DEFAULT_RULES)

def add_rule(rid, cond, action, priority=50):
    with open(RULES, "a") as f:
        f.write(json.dumps({"id":rid,"if":cond,"then":action,"priority":priority,
                            "at":_now()}) + "\n")
    return True, "додано"

def evaluate(deviation_pct=None, proof_present=None, both_confirm=None, dispute_days=None):
    """Оцінює ситуацію і повертає рекомендоване рішення."""
    rules = sorted(load_rules(), key=lambda r: r.get("priority",50))
    # простий інтерпретатор — порівняння виразів
    ctx = {"deviation_pct": deviation_pct, "proof_present": proof_present,
           "both_confirm": both_confirm, "dispute_days": dispute_days}
    for r in rules:
        expr = r["if"]
        try:
            # переклад людських правил у Python-вирази
            py = expr
            py = py.replace("no proof after 7d", "not proof_present and dispute_days and dispute_days>=7")
            py = py.replace("both confirm", "both_confirm")
            if eval(py, {"__builtins__":{}}, ctx):
                return {"rule": r["id"], "decision": r["then"], "expr": expr, "at": _now()}
        except Exception:
            continue
    return {"decision": "manual", "reason": "жодне правило не спрацювало", "at": _now()}

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "rules"
    if cmd == "rules":
        for r in load_rules():
            print(f"  [{r.get('priority',50):3d}] {r['id']:14s} if {r['if']:35s} → {r['then']}")
    elif cmd == "eval":
        ctx = json.loads(sys.argv[2]) if len(sys.argv) > 2 else {}
        print(json.dumps(evaluate(**ctx), indent=2, ensure_ascii=False))
    elif cmd == "add":
        ok, m = add_rule(sys.argv[2], sys.argv[3], sys.argv[4])
        print(("✓ " if ok else "✗ ")+m)
