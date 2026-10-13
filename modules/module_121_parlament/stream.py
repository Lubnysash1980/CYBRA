#!/usr/bin/env python3
"""Єдиний потік подій парламенту. Пише все: чек, дія, голос, sync, alert."""
import json, os, time, sys
from pathlib import Path

D = Path(__file__).resolve().parent
STREAM = D / "logs" / "stream.jsonl"
STREAM.parent.mkdir(exist_ok=True)

LEVELS = ["trace", "debug", "info", "warn", "error", "critical"]

def log(category, event, data=None, level="info"):
    entry = {
        "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "ts_unix": int(time.time()),
        "level": level,
        "cat": category,       # check | action | vote | proposal | sync | backup | alert | audit | system
        "ev": event,
        "data": data or {},
        "pid": os.getpid(),
        "mod": "121",
    }
    try:
        with open(STREAM, "a") as f:
            f.write(json.dumps(entry, ensure_ascii=False) + "\n")
    except Exception: pass
    # ротація
    try:
        if STREAM.stat().st_size > 5_000_000:
            lines = STREAM.read_text().splitlines()
            STREAM.write_text("\n".join(lines[-3000:]) + "\n")
    except Exception: pass
    return entry

# ─── шорткати ───────────────────────────────────────────────
def check(check_id, status, detail=""):
    return log("check", check_id, {"status": status, "detail": detail},
               level="warn" if status in ("warn","fail") else
                     "error" if status == "critical" else "info")

def action(action_id, ok, msg="", source="manual"):
    return log("action", action_id,
               {"ok": ok, "msg": msg[:200], "source": source},
               level="info" if ok else "warn")

def vote(pid, voter, choice):
    return log("vote", pid, {"voter": voter[:12]+"…", "choice": choice})

def proposal(pid, ptype, title, author):
    return log("proposal", pid, {"type": ptype, "title": title[:60], "author": author[:12]+"…"})

def sync(kind, ok, msg=""):
    return log("sync", kind, {"ok": ok, "msg": msg[:120]},
               level="info" if ok else "warn")

def backup(ok, msg="", url=""):
    return log("backup", "webdav", {"ok": ok, "msg": msg[:120], "url": url[:80]},
               level="info" if ok else "warn")

def alert(kind, text):
    return log("alert", kind, {"text": text[:200]}, level="warn")

def audit(kind, payload):
    return log("audit", kind, payload if isinstance(payload, dict) else {"v": str(payload)[:200]})

def system(ev, data=None, level="info"):
    return log("system", ev, data, level=level)

# ─── читання ────────────────────────────────────────────────
def read(n=100, category=None, level=None):
    if not STREAM.exists(): return []
    out = []
    for line in STREAM.read_text().splitlines()[-n*3:]:
        try: e = json.loads(line)
        except Exception: continue
        if category and e.get("cat") != category: continue
        if level and e.get("level") != level: continue
        out.append(e)
    return out[-n:]

def stats(window_sec=86400):
    """Скільки подій по категоріях за останні N секунд."""
    if not STREAM.exists(): return {}
    now = int(time.time())
    from collections import Counter
    cats = Counter(); levels = Counter()
    for line in STREAM.read_text().splitlines()[-10000:]:
        try: e = json.loads(line)
        except Exception: continue
        if now - e.get("ts_unix", 0) > window_sec: continue
        cats[e.get("cat","?")] += 1
        levels[e.get("level","?")] += 1
    return {"categories": dict(cats), "levels": dict(levels),
            "window_sec": window_sec}

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "tail"
    if cmd == "tail":
        n = int(sys.argv[2]) if len(sys.argv) > 2 else 20
        for e in read(n):
            lv = e["level"][:4].upper()
            print(f"  {e['ts']} [{lv:4s}] {e['cat']:9s} {e['ev'][:40]:40s} "
                  f"{json.dumps(e.get('data',{}), ensure_ascii=False)[:60]}")
    elif cmd == "stats":
        print(json.dumps(stats(), indent=2, ensure_ascii=False))
    elif cmd == "test":
        log("system", "manual test", {"msg": "hello"})
        print("✓")
