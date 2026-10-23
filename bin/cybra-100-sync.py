#!/usr/bin/env python3
import os, time, subprocess, json
from pathlib import Path
from datetime import datetime, timezone

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
LOG = CYBRA / "logs/sync_100.log"
GOAL_FILE = CYBRA / "cybra_goal.json"

def log(msg):
    t = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    with open(LOG, "a") as f: f.write(f"[{t}] {msg}\n")
    print(f"[{t}] {msg}")

def run(cmd):
    try: return subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=60, cwd=CYBRA)
    except: return None

def check_and_sync():
    """Перевіряє розбіжності з GitHub і робить Hard Reset, якщо треба."""
    # 1. Отримуємо свіжі дані з Ноди (GitHub)
    run("git fetch origin main -q")
    
    local_hash = run("git rev-parse HEAD").stdout.strip()
    remote_hash = run("git rev-parse origin/main").stdout.strip()
    
    # 2. Перевіряємо, чи є незакомічені зміни (бруд)
    status = run("git status --porcelain").stdout.strip()
    has_local_changes = len(status) > 0
    
    # 3. Перевіряємо, чи відрізняється локальна версія від Ноди
    is_outdated = local_hash != remote_hash
    
    if is_outdated or has_local_changes:
        log(f"⚠️ Виявлено розбіжність з 100% станом Ноди!")
        if is_outdated: log(f"   Локальна версія ({local_hash[:7]}) != Нода ({remote_hash[:7]})")
        if has_local_changes: log(f"   Є локальні зміни/сміття")
        
        log("🔄 Запускаємо автоматичний Hard Reset до 100% стану...")
        # Викликаємо наш скрипт жорсткого скидання
        res = run("bash bin/cybra-hard-reset.sh")
        if res and res.returncode == 0:
            log("✅ Успішно синхронізовано з Нодою (100% стан).")
        else:
            log("❌ Помилка під час Hard Reset.")
    else:
        # Все ідеально
        pass

def main():
    log("=== 100% STATE SYNC CONTROLLER STARTED ===")
    
    # При старті одразу робимо перевірку
    check_and_sync()
    
    while True:
        try:
            # Перевіряємо кожні 10 хвилин (щоб не спамити Git)
            time.sleep(600)
            check_and_sync()
        except Exception as e:
            log(f"❌ ПОМИЛКА SYNC: {e}")

if __name__ == "__main__":
    main()
