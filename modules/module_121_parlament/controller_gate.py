#!/usr/bin/env python3
"""Controller Gate — парламент працює тільки при 100% контролерів.
Якщо хоч один контролер не ok → блокує голосування/підпис."""
import json, os, subprocess, sys
from pathlib import Path

H = Path.home() / "CYBRA"
M = H / "modules"
CONTROLLERS = M / "module_320_controllers/controllers.py"

def check():
    """Повертає (all_ok: bool, details: list)."""
    if not CONTROLLERS.exists():
        return False, [{"id": "controller_module", "name": "module_320", "ok": False, "msg": "не встановлено"}]
    try:
        r = subprocess.run(["python3", str(CONTROLLERS), "json"],
                          capture_output=True, text=True, timeout=30)
        if r.returncode != 0:
            return False, [{"id": "run", "ok": False, "msg": r.stderr[:200]}]
        data = json.loads(r.stdout)
        all_ok = all(c["ok"] for c in data)
        return all_ok, data
    except Exception as e:
        return False, [{"id": "error", "ok": False, "msg": str(e)[:200]}]

def require_all():
    """Використовується у parliament. Кидає RuntimeError якщо не 100%."""
    ok, details = check()
    if not ok:
        bad = [c for c in details if not c.get("ok")]
        msg = "controllers not 100%: " + ", ".join(
            f"{c.get('name','?')} ({c.get('msg','?')})" for c in bad[:3])
        raise RuntimeError(msg)
    return True

def report():
    ok, details = check()
    G='\033[32m'; R='\033[31m'; N='\033[0m'
    total = len(details)
    good = sum(1 for c in details if c.get("ok"))
    pct = round(good/total*100) if total else 0
    print(f"\n  Стан контролерів: {good}/{total} = {pct}%")
    for c in details:
        col = G if c.get("ok") else R
        mark = "✓" if c.get("ok") else "✗"
        print(f"  {col}{mark}{N} {c.get('name','?'):28s} {c.get('msg','')[:60]}")
    print()
    return ok, pct

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "check"
    if cmd == "check":
        ok, pct = report()
        sys.exit(0 if ok else 1)
    elif cmd == "require":
        try:
            require_all(); print("✓ 100% — OK"); sys.exit(0)
        except RuntimeError as e:
            print(f"✗ {e}"); sys.exit(1)
