#!/usr/bin/env python3
"""Репутація учасників на основі історії угод.
Готує TX для публікації у BSC."""
import json, os, sys, time
from pathlib import Path
H = Path.home() / "CYBRA"
D = Path(__file__).resolve().parent
DATA = D / "data"; DATA.mkdir(exist_ok=True)
DB = DATA / "scores.jsonl"

def _now(): return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

def add_rating(addr, cid, score, comment="", by="system"):
    """Score 1-5."""
    if not 1 <= score <= 5: return False, "score має бути 1-5"
    rec = {"addr": addr.lower(), "cid": cid, "score": int(score),
           "comment": comment, "by": by, "at": _now()}
    with open(DB, "a") as f: f.write(json.dumps(rec, ensure_ascii=False) + "\n")
    return True, "записано"

def score(addr):
    addr = addr.lower()
    if not DB.exists(): return {"addr": addr, "count": 0, "avg": None}
    ratings = []
    for line in DB.read_text().splitlines():
        try:
            e = json.loads(line)
            if e["addr"] == addr: ratings.append(e["score"])
        except Exception: pass
    if not ratings: return {"addr": addr, "count": 0, "avg": None}
    return {"addr": addr, "count": len(ratings),
            "avg": round(sum(ratings)/len(ratings), 2)}

def leaderboard(n=20):
    from collections import defaultdict
    if not DB.exists(): return []
    agg = defaultdict(list)
    for line in DB.read_text().splitlines():
        try:
            e = json.loads(line)
            agg[e["addr"]].append(e["score"])
        except Exception: pass
    out = [{"addr": a, "count": len(v), "avg": round(sum(v)/len(v),2)} for a,v in agg.items()]
    return sorted(out, key=lambda x: (-x["avg"], -x["count"]))[:n]

def prepare_anchor_tx(addr, from_addr):
    """Готує TX з data=score для публікації у BSC."""
    s = score(addr)
    payload = json.dumps({"addr": addr, "avg": s["avg"], "n": s["count"]})
    out = DATA / f"reputation_{addr[:10]}_{int(time.time())}.tx.json"
    tx = {"from": from_addr, "to": from_addr, "value": 0,
          "data": "0x" + payload.encode().hex(), "chain_id": 56,
          "created": _now(), "score": s}
    out.write_text(json.dumps(tx, indent=2, ensure_ascii=False))
    return True, str(out)

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "leaderboard"
    if cmd == "score":
        print(json.dumps(score(sys.argv[2]), indent=2))
    elif cmd == "rate":
        ok, m = add_rating(sys.argv[2], sys.argv[3], int(sys.argv[4]),
                          sys.argv[5] if len(sys.argv) > 5 else "")
        print(("✓ " if ok else "✗ ")+m)
    elif cmd == "leaderboard":
        G='\033[32m'; B='\033[36m'; D='\033[2m'; N='\033[0m'
        print(f"\n  {B}Reputation Leaderboard{N}\n")
        for i, x in enumerate(leaderboard(), 1):
            stars = "★"*int(round(x["avg"])) + "☆"*(5-int(round(x["avg"])))
            print(f"  {i:2d}. {x['addr'][:12]}…  {G}{stars}{N}  {x['avg']}  ({x['count']})")
    elif cmd == "anchor":
        ok, m = prepare_anchor_tx(sys.argv[2], sys.argv[3])
        print(("✓ " if ok else "✗ ")+m)
