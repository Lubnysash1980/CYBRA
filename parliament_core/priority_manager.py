#!/usr/bin/env python3
import os, sys, json, time, subprocess
from pathlib import Path
from datetime import datetime, timezone

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
MODS = CYBRA / "modules"
REGISTRY = CYBRA / "parliament_core/registry.json"
LOG = CYBRA / "logs/parliament_priority.log"
LOG.parent.mkdir(parents=True, exist_ok=True)

def log(msg):
    with open(LOG, "a") as f:
        f.write(f"[{datetime.now(timezone.utc).isoformat()}] {msg}\n")

def scan_modules():
    mods = []
    if not MODS.exists(): return mods
    for d in MODS.iterdir():
        if not d.is_dir() or not d.name.startswith("module_"): continue
        main = d / "main.sh"
        if main.exists():
            mods.append({"name": d.name, "path": str(main)})
    return mods

def daemon():
    log("=== Parliament Priority Daemon Started ===")
    while True:
        try:
            mods = scan_modules()
            data = {"updated": datetime.now(timezone.utc).isoformat(), "total": len(mods)}
            REGISTRY.write_text(json.dumps(data, indent=2))
            log(f"Scanned {len(mods)} modules")
        except Exception as e:
            log(f"ERROR: {e}")
        time.sleep(60)

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "daemon":
        daemon()
    else:
        print("Parliament Priority Manager. Run with 'daemon'.")
