#!/usr/bin/env python3
import os, time, subprocess, json, shutil
from pathlib import Path
from datetime import datetime, timezone

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
LOG = CYBRA / "logs/main-controller.log"
LOG.parent.mkdir(parents=True, exist_ok=True)

def log(msg):
    t = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    with open(LOG, "a") as f:
        f.write(f"[{t}] {msg}\n")

def run(cmd, cwd=None):
    try:
        return subprocess.run(cmd, shell=True, capture_output=True, text=True, cwd=cwd, timeout=30)
    except Exception as e:
        return None

def check_pm2():
    # Перевіряємо, чи живий сам PM2
    out = run("pm2 jlist")
    if not out or out.returncode != 0:
        log("⚠️ PM2 daemon впав. Відновлюємо (pm2 resurrect)...")
        run("pm2 resurrect")
        return

    try:
        procs = json.loads(out.stdout)
        online = [p["name"] for p in procs if p["pm2_env"]["status"] == "online"]
        
        # Якщо наш контролер не в списку онлайн (хоча він зараз виконується) - ігноруємо
        # Але якщо всі інші процеси впали - перезапускаємо
        if len(online) <= 1: # Тільки контролер живий
            log("⚠️ Всі процеси впали. Перезапускаємо (pm2 restart all)...")
            run("pm2 restart all")
    except Exception as e:
        log(f"Помилка читання PM2: {e}")

def sync_git():
    if not (CYBRA / ".git").exists(): return
    
    # Перевіряємо, чи є зміни
    status = run("git status --porcelain", cwd=CYBRA)
    if status and status.stdout.strip():
        log("🔄 Є локальні зміни. Синхронізація з нодою...")
        run("git add -A", cwd=CYBRA)
        run('git commit -m "auto: main controller sync" -q', cwd=CYBRA)
        run("git push origin main -q", cwd=CYBRA)
    
    # Забираємо зміни з ноди (щоб не затерти локальні, робимо rebase)
    run("git pull origin main --rebase -q", cwd=CYBRA)

def check_sandbox():
    sb = CYBRA / "sandbox"
    if sb.exists():
        out = run(f"du -sb {sb}")
        if out and out.returncode == 0:
            size = int(out.stdout.split()[0])
            limit = 65 * 1024 * 1024
            if size > limit:
                log(f"🧹 Sandbox переповнено ({size//1024//1024}MB). Очищаємо...")
                run(f"rm -rf {sb}/trash/* {sb}/tmp/*")
                cleanup = sb / "sandbox_cleanup.sh"
                if cleanup.exists():
                    run(f"bash {cleanup}")

def main():
    log("=== ГОЛОВНИЙ КОНТРОЛЕР ЗАПУЩЕНО ===")
    while True:
        try:
            check_pm2()
            check_sandbox()
            sync_git()
        except Exception as e:
            log(f"❌ ПОМИЛКА КОНТРОЛЕРА: {e}")
        
        # Чекаємо 60 секунд перед наступним циклом
        time.sleep(60)

if __name__ == "__main__":
    main()
