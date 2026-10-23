#!/usr/bin/env python3
import os, time, subprocess, json, socket
from pathlib import Path
from datetime import datetime, timezone

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
NODES_DIR = CYBRA / "nodes"
HEARTBEAT_DIR = NODES_DIR / "heartbeats"
DEVICE_ID = socket.gethostname().replace(" ", "_") or "device_1"
LOG = CYBRA / "logs/cluster_lb.log"

HEARTBEAT_DIR.mkdir(parents=True, exist_ok=True)
LOG.parent.mkdir(parents=True, exist_ok=True)

def log(msg):
    t = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    with open(LOG, "a") as f: f.write(f"[{t}] {msg}\n")

def run(cmd):
    try: return subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=15)
    except: return None

def update_heartbeat():
    """Пишемо наш пульс і відправляємо в Git"""
    hb_file = HEARTBEAT_DIR / f"{DEVICE_ID}.json"
    data = {"device": DEVICE_ID, "last_seen": time.time()}
    hb_file.write_text(json.dumps(data))
    # Тихо комітимо в Git
    run("git add nodes/heartbeats/ && git commit -m 'hb: cluster heartbeat' -q && git push origin main -q", cwd=CYBRA)

def get_active_devices():
    """Аналізуємо пульси інших пристроїв"""
    run("git pull origin main --rebase -q", cwd=CYBRA)
    active = []
    now = time.time()
    for f in HEARTBEAT_DIR.glob("*.json"):
        try:
            data = json.loads(f.read_text())
            if now - data["last_seen"] < 180:
                active.append(data["device"])
        except: pass
    return active

def main():
    log(f"=== CLUSTER MONITOR STARTED ({DEVICE_ID}) ===")
    while True:
        try:
            update_heartbeat()
            active = get_active_devices()
            log(f"🌍 Пристроїв онлайн: {len(active)} ({', '.join(active)})")
        except Exception as e:
            log(f"❌ ПОМИЛКА LB: {e}")
        time.sleep(60)

if __name__ == "__main__":
    main()
