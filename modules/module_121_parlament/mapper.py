#!/usr/bin/env python3
"""Auto-mapping: аналізує контракт (з 108/111/INVOICE) і будує план виконання.
Кожен крок: рівень, екзекутор, payload, залежності."""
import json, os, sys
from pathlib import Path

H = Path.home() / "CYBRA"
D = Path(__file__).resolve().parent
sys.path.insert(0, str(D))

# шаблони: тип контракту → потрібні кроки
TEMPLATES = {
    "sale": {
        "name": "Продаж",
        "steps": [
            {"level":1, "executor":"sign",     "payload":{}},
            {"level":2, "executor":"escrow",   "payload":{"amount_bnb":"{amount}"}},
            {"level":3, "executor":"notify",   "payload":{"msg":"Очікує deliverable"}},
            {"level":4, "executor":"verify",   "payload":{"expected_hash":"{deliverable_hash}"}},
            {"level":5, "executor":"deviation","payload":{"expected":"{qty_expected}",
                                                          "actual":"{qty_actual}",
                                                          "threshold":3.0}},
            {"level":6, "executor":"wait",     "payload":{"window_sec":3600}},
            {"level":7, "executor":"release",  "payload":{"seller":"{seller}",
                                                          "amount_bnb":"{amount}"}},
        ],
    },
    "service": {
        "name": "Послуга",
        "steps": [
            {"level":1, "executor":"sign",     "payload":{}},
            {"level":2, "executor":"escrow",   "payload":{"amount_bnb":"{amount}"}},
            {"level":3, "executor":"notify",   "payload":{"msg":"Очікує акт"}},
            {"level":4, "executor":"verify",   "payload":{"expected_hash":"{act_hash}"}},
            {"level":5, "executor":"deviation","payload":{"expected":"{hours_expected}",
                                                          "actual":"{hours_actual}",
                                                          "threshold":3.0}},
            {"level":6, "executor":"wait",     "payload":{"window_sec":86400}},
            {"level":7, "executor":"release",  "payload":{"seller":"{seller}"}},
        ],
    },
    "rent": {
        "name": "Оренда",
        "steps": [
            {"level":1, "executor":"sign",     "payload":{}},
            {"level":2, "executor":"escrow",   "payload":{"amount_bnb":"{amount}"}},
            {"level":3, "executor":"notify",   "payload":{"msg":"Об'єкт передано"}},
            {"level":4, "executor":"verify",   "payload":{"expected_hash":"{condition_hash}"}},
            {"level":5, "executor":"deviation","payload":{"expected":"{condition_score}",
                                                          "actual":"{condition_actual}",
                                                          "threshold":5.0}},
            {"level":6, "executor":"wait",     "payload":{"window_sec":2592000}},
            {"level":7, "executor":"release",  "payload":{"seller":"{landlord}"}},
        ],
    },
}

def _load_contract(cid):
    """Пробуємо знайти контракт у різних місцях."""
    for p in [
        H / f"public/sign/{cid}.json",
        H / f"modules/module_19_contract_tui_menu/evidence/{cid}.json",
        H / f"modules/module_19_contract_tui_menu/evidence/{cid}_buyer.sig",
    ]:
        if p.exists():
            try: return json.loads(p.read_text())
            except Exception: pass
    return None

def _fill(template_str, ctx):
    """Підставляє {key} з ctx."""
    if not isinstance(template_str, str): return template_str
    if not (template_str.startswith("{") and template_str.endswith("}")):
        return template_str
    key = template_str[1:-1]
    return ctx.get(key)

def _fill_deep(o, ctx):
    if isinstance(o, str): return _fill(o, ctx)
    if isinstance(o, dict): return {k: _fill_deep(v, ctx) for k,v in o.items()}
    if isinstance(o, list): return [_fill_deep(v, ctx) for v in o]
    return o

def infer_type(contract):
    """Визначає тип контракту з payload."""
    if not contract: return "service"
    p = contract.get("payload") or {}
    t = p.get("type") or contract.get("type")
    if t in TEMPLATES: return t
    # евристика
    if p.get("deliverable_hash"): return "sale"
    if p.get("condition_hash"):   return "rent"
    return "service"

def map_contract(cid, ctx=None):
    """Повертає повний план виконання."""
    c = _load_contract(cid)
    ctype = infer_type(c)
    tpl = TEMPLATES[ctype]
    ctx = dict(ctx or {})
    if c:
        ctx.setdefault("buyer",  c.get("buyer"))
        ctx.setdefault("seller", c.get("seller"))
        ctx.setdefault("amount", (c.get("payload") or {}).get("amount_bnb", 0))
    plan = {
        "cid": cid, "type": ctype, "type_name": tpl["name"],
        "contract": c, "ctx": ctx,
        "steps": [],
    }
    for i, s in enumerate(tpl["steps"], 1):
        filled = _fill_deep(s["payload"], ctx)
        plan["steps"].append({
            "order": i, "level": s["level"], "executor": s["executor"],
            "payload": filled,
        })
    # зберегти
    out = D / "data" / "executions" / f"{cid}_plan.json"
    out.write_text(json.dumps(plan, indent=2, ensure_ascii=False))
    return plan

def print_plan(plan):
    G='\033[32m'; Y='\033[33m'; B='\033[36m'; DIM='\033[2m'; N='\033[0m'
    print(f"\n  {B}═══ План · {plan['cid']} ({plan['type_name']}) ═══{N}\n")
    for s in plan["steps"]:
        print(f"  L{s['level']}  [{s['executor']:10s}]  {json.dumps(s['payload'], ensure_ascii=False)[:60]}")
    print()

if __name__ == "__main__":
    if len(sys.argv) < 2: print("usage: mapper.py <cid>"); sys.exit(1)
    plan = map_contract(sys.argv[1])
    print_plan(plan)
