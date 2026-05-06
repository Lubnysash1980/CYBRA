import time
import subprocess
import os
from pathlib import Path

WATCH_DIR = Path(".").resolve()
INTERVAL = 10  # секунд

def run(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True)

def has_changes():
    result = run("git status --porcelain")
    return bool(result.stdout.strip())

def sync():
    print("[AUTO-GIT] changes detected → syncing...")

    run("git add .")
    run('git commit -m "auto-sync: update cybra system"')
    run("git push origin main")

    print("[AUTO-GIT] sync complete")

def main():
    print("[AUTO-GIT] daemon started")

    while True:
        try:
            if has_changes():
                sync()
            time.sleep(INTERVAL)

        except KeyboardInterrupt:
            print("[AUTO-GIT] stopped")
            break
        except Exception as e:
            print("[AUTO-GIT ERROR]", e)
            time.sleep(INTERVAL)

if __name__ == "__main__":
    main()
