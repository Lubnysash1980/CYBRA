#!/usr/bin/env python3
import os, time, subprocess, json
from pathlib import Path
from datetime import datetime, timezone

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
GOAL_FILE = CYBRA / "cybra_goal.json"
LOG = CYBRA / "logs/ultimate_backend.log"
LOG.parent.mkdir(parents=True, exist_ok=True)

def log(msg):
    t = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    with open(LOG, "a") as f:
        f.write(f"[{t}] {msg}\n")

def run(cmd, cwd=None):
    try:
        return subprocess.run(cmd, shell=True, capture_output=True, text=True, cwd=cwd, timeout=60)
    except Exception as e:
        log(f"Cmd Error: {e}")
        return None

def check_goal():
    if not GOAL_FILE.exists():
        log("⚠️ Файл цілі відсутній! Відновлюємо...")
        return False
    return True

def auto_pull():
    # Автоматичне підтягування оновлень (автопакети)
    log("🔄 Перевірка оновлень з ноди (GitHub)...")
    run("git pull origin main --rebase -q", cwd=CYBRA)

def auto_save():
    # Автосейв (збереження стану PM2 та коміт, якщо є зміни)
    run("pm2 save -q", cwd=CYBRA)
    
    status = run("git status --porcelain", cwd=CYBRA)
    if status and status.stdout.strip():
        log("💾 Знайдено зміни. Робимо автосейв (Commit + Push)...")
        run("git add -A", cwd=CYBRA)
        run('git commit -m "auto-backend: system auto-save" -q', cwd=CYBRA)
        run("git push origin main -q", cwd=CYBRA)

def main():
    log("=== ULTIMATE BACKEND STARTED ===")
    while True:
        try:
            if check_goal():
                auto_pull()
                auto_save()
        except Exception as e:
            log(f"❌ BACKEND ERROR: {e}")
        
        # Перевірка кожні 5 хвилин
        time.sleep(300)

if __name__ == "__main__":
    main()
