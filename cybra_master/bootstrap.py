import os
import time
import json
import subprocess

BASE = os.path.dirname(os.path.abspath(__file__))

STATE_FILE = os.path.expanduser("~/.cybra_infra_state/state.json")

print("🚀 CYBRA CONTROL PLANE BOOTING...")

# ----------------------------
# STATE LOADER (etcd-like)
# ----------------------------
def load_state():
    if os.path.exists(STATE_FILE):
        with open(STATE_FILE, "r") as f:
            return json.load(f)
    return {"nodes": [], "health": "unknown"}

def save_state(state):
    os.makedirs(os.path.dirname(STATE_FILE), exist_ok=True)
    with open(STATE_FILE, "w") as f:
        json.dump(state, f, indent=2)

# ----------------------------
# WATCHDOG (autoheal logic)
# ----------------------------
def health_check():
    try:
        result = subprocess.run(["ping", "-c", "1", "8.8.8.8"],
                                 capture_output=True)
        return result.returncode == 0
    except:
        return False

# ----------------------------
# GIT SYNC (GitOps core)
# ----------------------------
def git_sync():
    try:
        subprocess.run(["git", "add", "."], cwd=BASE)
        subprocess.run(["git", "commit", "-m", "auto-sync"], cwd=BASE)
        subprocess.run(["git", "push"], cwd=BASE)
    except Exception as e:
        print("Git sync failed:", e)

# ----------------------------
# ORCHESTRATOR LOOP
# ----------------------------
state = load_state()

tick = 0

while True:
    tick += 1

    print(f"🧠 tick={tick} | checking system...")

    healthy = health_check()
    state["health"] = "ok" if healthy else "degraded"

    if not healthy:
        print("⚠️ system degraded -> autoheal trigger")
        # here you would restart modules
        # subprocess.run(["bash", "restart.sh"])

    # GitOps sync every 10 cycles
    if tick % 10 == 0:
        print("📡 GitOps sync...")
        git_sync()

    save_state(state)

    time.sleep(5)
