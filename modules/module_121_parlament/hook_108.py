#!/usr/bin/env python3
"""Викликається з 108 після створення контракту.
Якщо сума >= threshold — створює пропозицію у парламенті."""
import sys, os, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import parliament as P

def check(cid, amount_bnb, author):
    r = P.rules()
    if amount_bnb < r.get("contract_value_threshold_bnb", 1.0):
        return {"required": False}
    # якщо вже є пропозиція для цього CID — не дублювати
    for p in P.proposals():
        if p.get("type") == "contract_sign" and p.get("payload",{}).get("cid") == cid:
            return {"required": True, "pid": p["pid"], "existing": True}
    ok, why, pid = P.create_proposal(
        "contract_sign",
        f"Схвалення контракту {cid}",
        {"cid": cid, "amount_bnb": amount_bnb},
        author
    )
    return {"required": True, "pid": pid, "ok": ok, "why": why}

if __name__ == "__main__":
    if len(sys.argv) < 4:
        print("usage: hook_108.py <cid> <amount_bnb> <author>"); sys.exit(1)
    print(json.dumps(check(sys.argv[1], float(sys.argv[2]), sys.argv[3]),
                     indent=2, ensure_ascii=False))
