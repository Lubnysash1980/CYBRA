import os
import time
import hashlib
import subprocess
from pathlib import Path

WATCH_DIR = Path(".").resolve()
INTERVAL = 10

IGNORE_FILES = {
    ".git",
    "__pycache__",
    "wallet.json",
    "wallet_info.txt",
    "stats.json",
    "stats.csv"
}

STATE_FILE = ".git_sync_state"

def run(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True)

def hash_file(path):
    try:
        with open(path, "rb") as f:
            return hashlib.sha256(f.read()).hexdigest()
    except:
        return None

def scan_state():
    state = {}
    for root, dirs, files in os.walk(WATCH_DIR):
        dirs[:] = [d for d in dirs if d not in IGNORE_FILES]

        for file in files:
            if file in IGNORE_FILES:
                continue

            full_path = Path(root) / file
            h = hash_file(full_path)
            if h:
                state[str(full_path)] = h
    return state

def load_last_state():
    if not os.path.exists(STATE_FILE):
        return {}
    try:
        with open(STATE_FILE, "r") as f:
            return eval(f.read())
    except:
        return {}

def save_state(state):
    with open(STATE_FILE, "w") as f:
        f.write(str(state))

def has_changes(old, new):
    return old != new

def git_sync():
    print("[SYNC V2] staging changes...")

    run("git add -A")

    commit = run('git commit -m "cybra cluster auto-sync v2"')

    if "nothing to commit" in commit.stdout:
        print("[SYNC V2] no git changes")
        return False

    push = run("git push origin main")

    print("[SYNC V2] pushed")
    return True

def main():
    print("[SYNC V2] cluster daemon started")

    last_state = load_last_state()

    while True:
        try:
            current_state = scan_state()

            if has_changes(last_state, current_state):
                print("[SYNC V2] changes detected")
                if git_sync():
                    last_state = current_state
                    save_state(last_state)
            else:
                print("[SYNC V2] no changes")

            time.sleep(INTERVAL)

        except KeyboardInterrupt:
            print("[SYNC V2] stopped")
            break
        except Exception as e:
            print("[SYNC V2 ERROR]", e)
            time.sleep(INTERVAL)

if __name__ == "__main__":
    main()
