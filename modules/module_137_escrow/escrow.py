#!/usr/bin/env python3
"""Escrow flow: підготовка TX для блокування коштів, підтвердження, реліз."""
import json, os, sys, time
from pathlib import Path
D = Path(__file__).resolve().parent
H = Path.home() / "CYBRA"
DATA = D / "data"; DATA.mkdir(exist_ok=True)

def _now(): return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

def create(cid, buyer, seller, amount_bnb, release_requires=("seller_proof","buyer_confirm")):
    """Готує escrow-угоду (без реального смарт-контракту — просто угода + TX plan)."""
    out = {
        "cid": cid, "buyer": buyer, "seller": seller,
        "amount_bnb": float(amount_bnb),
        "release_requires": list(release_requires),
        "status": "draft", "created": _now(),
        "steps": [],
    }
    p = DATA / f"{cid}_escrow.json"
    p.write_text(json.dumps(out, indent=2, ensure_ascii=False))
    return True, str(p)

def fund_plan(cid):
    """Готує TX для funding."""
    p = DATA / f"{cid}_escrow.json"
    if not p.exists(): return False, "немає escrow"
    e = json.loads(p.read_text())
    plan = {
        "action": "escrow_fund",
        "cid": cid,
        "from": e["buyer"],
        "to": e.get("contract_address", e["seller"]),  # без контракту → seller
        "amount_bnb": e["amount_bnb"],
        "chain_id": 56, "at": _now(),
    }
    out = DATA / f"{cid}_fund_tx.json"
    out.write_text(json.dumps(plan, indent=2, ensure_ascii=False))
    e["status"] = "awaiting_fund"; e["steps"].append({"at": _now(), "ev": "fund_plan_created"})
    p.write_text(json.dumps(e, indent=2, ensure_ascii=False))
    return True, str(out)

def release_plan(cid):
    p = DATA / f"{cid}_escrow.json"
    if not p.exists(): return False, "немає escrow"
    e = json.loads(p.read_text())
    plan = {
        "action": "escrow_release",
        "cid": cid,
        "from": e.get("contract_address", e["buyer"]),
        "to": e["seller"],
        "amount_bnb": e["amount_bnb"],
        "chain_id": 56, "at": _now(),
    }
    out = DATA / f"{cid}_release_tx.json"
    out.write_text(json.dumps(plan, indent=2, ensure_ascii=False))
    e["status"] = "release_pending"
    e["steps"].append({"at": _now(), "ev": "release_plan_created"})
    p.write_text(json.dumps(e, indent=2, ensure_ascii=False))
    return True, str(out)

def mark_funded(cid, tx_hash):
    p = DATA / f"{cid}_escrow.json"
    if not p.exists(): return False, "немає escrow"
    e = json.loads(p.read_text())
    e["status"] = "funded"; e["fund_tx"] = tx_hash
    e["steps"].append({"at": _now(), "ev": "funded", "tx": tx_hash})
    p.write_text(json.dumps(e, indent=2, ensure_ascii=False))
    return True, "funded"

def list_all():
    return [json.loads(f.read_text()) for f in DATA.glob("*_escrow.json")]

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "list"
    if cmd == "create":
        ok, m = create(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5])
        print(("✓ " if ok else "✗ ")+m)
    elif cmd == "fund":
        ok, m = fund_plan(sys.argv[2]); print(("✓ " if ok else "✗ ")+m)
    elif cmd == "release":
        ok, m = release_plan(sys.argv[2]); print(("✓ " if ok else "✗ ")+m)
    elif cmd == "mark":
        ok, m = mark_funded(sys.argv[2], sys.argv[3]); print(("✓ " if ok else "✗ ")+m)
    elif cmd == "list":
        for e in list_all():
            print(f"  [{e['status']:15s}] {e['cid'][:26]:28s} {e['amount_bnb']} BNB")
