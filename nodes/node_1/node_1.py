import os, sys, json, time, hashlib, base64, hmac, subprocess
from pathlib import Path
from datetime import datetime, timezone

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
NODE_DIR = CYBRA / "nodes/node_1"
KEY_FILE = CYBRA / "nodes/keys/node_1.key"
STATE_FILE = NODE_DIR / "state/state.json"
LOG = NODE_DIR / "logs/node_1.log"

def load_key(): return KEY_FILE.read_bytes().strip()
def sign(data: str, key: bytes) -> str: return hmac.new(key, data.encode(), hashlib.sha256).hexdigest()

def log(msg):
    LOG.parent.mkdir(parents=True, exist_ok=True)
    with open(LOG, "a") as f: f.write(f"[{datetime.now(timezone.utc).isoformat()}] {msg}\n")

def get_state():
    if STATE_FILE.exists():
        try: return json.loads(STATE_FILE.read_text())
        except: pass
    return {"cycles": 0, "signed_actions": 0, "role": "guardian"}

def save_state(state):
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(json.dumps(state, indent=2))

def daemon():
    log("Node 1 (guardian) starting...")
    key = load_key()
    state = get_state()
    
    while True:
        try:
            state["cycles"] += 1
            payload = json.dumps({"node": 1, "cycle": state["cycles"], "role": "guardian"})
            signature = sign(payload, key)
            state["last_signature"] = signature[:16]
            state["signed_actions"] = state.get("signed_actions", 0) + 1
            save_state(state)
        except Exception as e:
            log(f"ERROR: {e}")
        time.sleep(60)

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "once":
        state = get_state()
        state["cycles"] += 1
        state["signed_actions"] = state.get("signed_actions", 0) + 1
        save_state(state)
        print("✅ Нода 1 виконала один цикл")
    else:
        daemon()
