#!/usr/bin/env python3
"""Перевірка відхилень і автозаміна. 3% default.
Правила автозаміни: якщо replacement вказано — пропонує заміну.
Якщо відхилення > auto_reject_pct — відмова."""
import json, os, sys, time
from pathlib import Path

D = Path(__file__).resolve().parent
EX = D / "data" / "executions"
CFG = D / "data" / "deviation.json"

DEFAULT = {
    "threshold_pct": 3.0,
    "auto_reject_pct": 15.0,   # понад 15% — автоматична відмова
    "auto_replace": True,      # дозволити автозаміну якщо replacement є
    "require_vote_pct": 10.0,  # 10-15% — винести на голосування
}

def cfg():
    c = dict(DEFAULT)
    if CFG.exists():
        try: c.update(json.loads(CFG.read_text()))
        except Exception: pass
    return c

def save_cfg(c): CFG.write_text(json.dumps(c, indent=2))

def check(cid, level, expected, actual, replacement=None, item_name=None):
    c = cfg()
    if expected == 0:
        return {"action":"reject", "reason":"expected=0", "deviation_pct": None}
    dev = abs(actual - expected) / expected * 100
    res = {
        "cid": cid, "level": level, "item": item_name,
        "expected": expected, "actual": actual,
        "deviation_pct": round(dev, 4),
        "threshold": c["threshold_pct"],
        "auto_reject": c["auto_reject_pct"],
        "require_vote": c["require_vote_pct"],
        "at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }
    if dev <= c["threshold_pct"]:
        res["action"] = "accept"
        res["reason"] = f"{dev:.2f}% ≤ {c['threshold_pct']}%"
    elif dev <= c["require_vote_pct"]:
        res["action"] = "vote"
        res["reason"] = f"{dev:.2f}% у зоні голосування"
    elif dev <= c["auto_reject_pct"]:
        if c["auto_replace"] and replacement is not None:
            res["action"] = "auto_replace"
            res["replacement"] = replacement
            res["reason"] = f"{dev:.2f}% > {c['threshold_pct']}% → автозаміна"
        else:
            res["action"] = "reject"
            res["reason"] = f"{dev:.2f}% > {c['threshold_pct']}%, replacement відсутній"
    else:
        res["action"] = "auto_reject"
        res["reason"] = f"{dev:.2f}% > {c['auto_reject_pct']}% → відмова"

    # log
    log = EX / f"{cid}_deviations.jsonl"
    with open(log, "a") as f:
        f.write(json.dumps(res, ensure_ascii=False) + "\n")

    # hook
    if res["action"] != "accept":
        try:
            import hooks, alerts
            hooks.fire("deviation", cid=cid, level=level, payload=res)
            alerts.send("deviation",
                        f"{cid} L{level}: {res['reason']}",
                        f"expected={expected} actual={actual} dev={res['deviation_pct']}%")
        except Exception: pass
    return res

def stats(cid=None):
    """Скільки accept/vote/replace/reject по контракту або в цілому."""
    files = [EX / f"{cid}_deviations.jsonl"] if cid else list(EX.glob("*_deviations.jsonl"))
    from collections import Counter
    c = Counter()
    for f in files:
        if not f.exists(): continue
        for line in f.read_text().splitlines():
            try: c[json.loads(line)["action"]] += 1
            except Exception: pass
    return dict(c)

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "check"
    if cmd == "check":
        if len(sys.argv) < 6:
            print("usage: deviation.py check <cid> <level> <expected> <actual> [replacement]")
            sys.exit(1)
        r = check(sys.argv[2], int(sys.argv[3]), float(sys.argv[4]), float(sys.argv[5]),
                  float(sys.argv[6]) if len(sys.argv) > 6 else None)
        print(json.dumps(r, indent=2, ensure_ascii=False))
    elif cmd == "cfg":
        print(json.dumps(cfg(), indent=2))
    elif cmd == "set":
        c = cfg()
        for kv in sys.argv[2:]:
            if "=" in kv:
                k, v = kv.split("=", 1)
                try: v = float(v) if "." in v else int(v)
                except ValueError: pass
                c[k] = v
        save_cfg(c); print("✓")
    elif cmd == "stats":
        print(json.dumps(stats(sys.argv[2] if len(sys.argv) > 2 else None), indent=2))
