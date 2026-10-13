#!/usr/bin/env python3
"""Менеджер шаблонів контрактів."""
import json, sys, os
from pathlib import Path
D = Path(__file__).resolve().parent
TPL = D / "templates"

def list_all():
    return sorted([json.loads(f.read_text()) for f in TPL.glob("*.json")],
                  key=lambda x: x.get("name",""))

def get(name):
    p = TPL / f"{name}.json"
    if not p.exists(): return None
    return json.loads(p.read_text())

def fill(name, values):
    t = get(name)
    if not t: return None, f"шаблон {name} не знайдено"
    missing = [f["id"] for f in t["fields"]
               if f.get("required") and not values.get(f["id"])]
    if missing: return None, f"відсутні поля: {missing}"
    contract = {
        "type": t["type"], "template": name,
        "payload": {k: values.get(k) for k in [f["id"] for f in t["fields"]]},
        "terms": t.get("default_terms",""),
        "created": __import__("time").strftime("%Y-%m-%dT%H:%M:%SZ", __import__("time").gmtime()),
    }
    return contract, "ok"

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "list"
    if cmd == "list":
        for t in list_all():
            print(f"  {t['type']:10s} {t['name']:20s}  полів: {len(t['fields'])}")
    elif cmd == "show":
        t = get(sys.argv[2])
        if t: print(json.dumps(t, indent=2, ensure_ascii=False))
    elif cmd == "fill":
        # fill <name> <json>
        c, err = fill(sys.argv[2], json.loads(sys.argv[3]))
        if c: print(json.dumps(c, indent=2, ensure_ascii=False))
        else: print("✗ "+err); sys.exit(1)
