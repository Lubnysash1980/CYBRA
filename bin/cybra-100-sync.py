#!/usr/bin/env python3
import os, time, subprocess, json
from pathlib import Path
from datetime import datetime, timezone

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
LOG = CYBRA / "logs/sync_100.log"

def log(msg):
    t = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    with open(LOG, "a") as f: f.write(f"[{t}] {msg}\n")

def run(cmd):
    # SAFE: try: return subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=60, cwd=CYBRA)
    except: return None

def check_and_sync():
    log("🔄 Перевірка синхронізації з Нодою (GitHub)...")
    # Робимо тільки fetch та pull, ніяких Hard Reset!
    run("git fetch origin main -q")
    
    local_hash = run("git rev-parse HEAD").stdout.strip()
    remote_hash = run("git rev-parse origin/main").stdout.strip()
    
    if local_hash != remote_hash:
        log(f"📥 Знайдено оновлення. Локальна ({local_hash[:7]}) != Нода ({remote_hash[:7]})")
        log("⏳ Виконуємо git pull --rebase...")
        run("git pull origin main --rebase -q")
        log("✅ Синхронізовано з Нодою.")
    else:
        log("✅ Система в 100% стані Ноди.")

def main():
    log("=== SAFE SYNC 100 CONTROLLER STARTED ===")
    while True:
        try:
            check_and_sync()
        except Exception as e:
            log(f"❌ ПОМИЛКА SYNC: {e}")
        
        # Перевіряємо раз на 30 хвилин (щоб не навантажувати систему)
        time.sleep(1800)

if __name__ == "__main__":
    main()
