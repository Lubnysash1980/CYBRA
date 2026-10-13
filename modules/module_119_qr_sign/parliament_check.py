#!/usr/bin/env python3
"""Отримує підписантів і статус кворуму для CID з парламенту 121."""
import sys, os, json
from pathlib import Path

H = Path.home() / "CYBRA"
PRL = H / "modules/module_121_parlament"
sys.path.insert(0, str(PRL))

def get_approvers(cid):
    try:
        import parliament as P
    except ImportError:
        return {"approvers": [], "quorum_met": False, "pid": None}
    # шукаємо approved proposal для цього cid
    best = None
    for p in P.proposals():
        pl = p.get("payload") or {}
        if pl.get("cid") == cid and p.get("status") == "approved":
            best = p; break
    if not best:
        return {"approvers": [], "quorum_met": False, "pid": None}
    votes = P.votes_of(best["pid"])
    members = {m["addr"]: m for m in P.members()["members"]}
    approvers = []
    for v in votes:
        if v["choice"] == "yes":
            m = members.get(v["voter"].lower(), {})
            approvers.append({"addr": v["voter"],
                              "label": m.get("label","?"),
                              "role": m.get("role","?"),
                              "sig": v.get("signature","")[:20] + "…"})
    t = P.tally(best["pid"])
    return {
        "approvers": approvers,
        "quorum_met": bool(t and t["quorum_ok"] and t["approval_ok"]),
        "pid": best["pid"],
        "tally": t,
    }

if __name__ == "__main__":
    if len(sys.argv) < 2: print("usage: parliament_check.py <cid>"); sys.exit(1)
    print(json.dumps(get_approvers(sys.argv[1]), indent=2, ensure_ascii=False))
