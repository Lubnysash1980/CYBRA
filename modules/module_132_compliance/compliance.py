#!/usr/bin/env python3
"""Перевірка контракту на відповідність: GDPR, MiCA (базове), AML."""
import json, os, sys, re, time
from pathlib import Path
D = Path(__file__).resolve().parent
DATA = D / "data"; DATA.mkdir(exist_ok=True)

RULES = [
    # (id, назва, рівень, regex або умова)
    ("gdpr.pii", "PII: імена/телефони/email у terms", "warn",
     re.compile(r'\b(\+?\d{7,15}|[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-z]{2,})\b')),
    ("gdpr.residency", "Вказано резиденцію сторін", "warn", None),
    ("mica.kyc", "KYC для суми > 1000 EUR", "warn", None),
    ("mica.disclosure", "Розкриття ризиків", "warn", None),
    ("aml.origin", "Походження коштів", "info", None),
    ("eu.withdrawal", "Право відмови 14 днів (EU)", "info", None),
]

def check(contract):
    terms = contract.get("terms","") or ""
    payload = contract.get("payload", {}) or {}
    amount = float(payload.get("amount_bnb", 0) or 0)
    out = []
    for rid, name, lvl, pattern in RULES:
        ok_ = True; detail = "—"
        if rid == "gdpr.pii" and pattern:
            m = pattern.search(terms)
            if m:
                ok_ = False; detail = f"знайдено: {m.group()[:20]}"
        elif rid == "mica.kyc":
            if amount * 500 > 1000:  # приблизно BNB→EUR
                ok_ = False; detail = f"сума ~{amount*500:.0f} EUR — потрібен KYC"
        elif rid == "gdpr.residency":
            ok_ = bool(payload.get("buyer") and payload.get("seller"))
            detail = "обидві сторони вказані" if ok_ else "немає однієї з сторін"
        else:
            detail = "не автоматизовано"
        out.append({"id":rid, "name":name, "level":lvl, "ok":ok_, "detail":detail})
    passed = sum(1 for r in out if r["ok"])
    return {"cid": contract.get("cid"), "passed": passed, "total": len(out),
            "results": out}

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("usage: compliance.py <cid>"); sys.exit(1)
    H = Path.home() / "CYBRA"
    cid = sys.argv[1]
    contract = {"cid": cid, "terms": "", "payload": {}}
    for p in [H/f"public/sign/{cid}.json",
              H/f"modules/module_19_contract_tui_menu/evidence/{cid}.json"]:
        if p.exists():
            try: contract = json.loads(p.read_text()); break
            except Exception: pass
    r = check(contract)
    G='\033[32m'; Y='\033[33m'; R='\033[31m'; B='\033[36m'; N='\033[0m'
    print(f"\n  {B}═══ Compliance Check · {cid} ═══{N}")
    print(f"  Passed: {r['passed']}/{r['total']}\n")
    for x in r["results"]:
        mark = f"{G}✓{N}" if x["ok"] else f"{Y}!{N}"
        print(f"  {mark} [{x['level']:6s}] {x['name']:42s} {x['detail']}")
    out = DATA / f"{cid}_compliance.json"
    out.write_text(json.dumps(r, indent=2, ensure_ascii=False))
