#!/usr/bin/env python3
"""Time-lock: контракт активний через N годин після підпису.
Можна скасувати до активації."""
import json, os, sys, time
from pathlib import Path
D = Path(__file__).resolve().parent
DATA = D / "data"; DATA.mkdir(exist_ok=True)
LOCKS = DATA / "locks.json"

def _now(): return int(time.time())
def _load():
    if not LOCKS.exists(): return {}
    try: return json.loads(LOCKS.read_text())
    except Exception: return {}
def _save(d):
    tmp = str(LOCKS)+".tmp"; Path(tmp).write_text(json.dumps(d, indent=2))
    os.replace(tmp, LOCKS)

def create(cid, delay_sec, actor="system", can_cancel_until_activation=True):
    d = _load()
    if cid in d: return False, "вже є"
    now = _now()
    d[cid] = {"cid": cid, "created": now, "activate_at": now + delay_sec,
              "status": "pending", "actor": actor,
              "cancel_until": now + delay_sec if can_cancel_until_activation else None,
              "history": [{"at": now, "ev": "created", "by": actor}]}
    _save(d); return True, f"activate at {time.strftime('%Y-%m-%d %H:%M', time.localtime(now+delay_sec))}"

def cancel(cid, actor="founder", reason=""):
    d = _load()
    if cid not in d: return False, "не знайдено"
    e = d[cid]
    if e["status"] != "pending": return False, f"status={e['status']}"
    if e.get("cancel_until") and _now() > e["cancel_until"]:
        return False, "вікно скасування минуло"
    e["status"] = "cancelled"
    e["history"].append({"at": _now(), "ev": "cancelled", "by": actor, "reason": reason})
    _save(d); return True, "скасовано"

def check(cid):
    d = _load()
    if cid not in d: return {"exists": False}
    e = d[cid]
    if e["status"] == "pending" and _now() >= e["activate_at"]:
        e["status"] = "active"
        e["history"].append({"at": _now(), "ev": "activated"})
        _save(d)
    return {"exists": True, **e}

def tick_all():
    d = _load(); moved = []
    for cid, e in list(d.items()):
        if e["status"] == "pending" and _now() >= e["activate_at"]:
            e["status"] = "active"
            e["history"].append({"at": _now(), "ev": "activated"})
            moved.append(cid)
    _save(d); return moved

def list_all():
    return sorted(_load().values(), key=lambda x: x["created"], reverse=True)

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "list"
    if cmd == "create":
        ok, m = create(sys.argv[2], int(sys.argv[3]), sys.argv[4] if len(sys.argv) > 4 else "system")
        print(("✓ " if ok else "✗ ")+m)
    elif cmd == "cancel":
        ok, m = cancel(sys.argv[2]); print(("✓ " if ok else "✗ ")+m)
    elif cmd == "check":
        print(json.dumps(check(sys.argv[2]), indent=2))
    elif cmd == "tick":
        print(json.dumps({"activated": tick_all()}))
    elif cmd == "list":
        G='\033[32m'; Y='\033[33m'; R='\033[31m'; D='\033[2m'; N='\033[0m'
        for e in list_all():
            c = {"active":G, "pending":Y, "cancelled":R}.get(e["status"], D)
            t = time.strftime("%Y-%m-%d %H:%M", time.localtime(e["activate_at"]))
            print(f"  {c}{e['status']:10s}{N} {e['cid'][:26]:28s} at {t}")
