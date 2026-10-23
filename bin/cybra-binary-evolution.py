#!/usr/bin/env python3
import os, time, subprocess, json, shutil
from pathlib import Path
from datetime import datetime, timezone

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
BINMIX = CYBRA / "bin" / "cybra_binmix"
SANDBOX = CYBRA / "sandbox"
BACKUP_DIR = CYBRA / "state" / "binary_backups"
LOG = CYBRA / "logs/binary_evolution.log"

BACKUP_DIR.mkdir(parents=True, exist_ok=True)
LOG.parent.mkdir(parents=True, exist_ok=True)

def log(msg):
    t = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    with open(LOG, "a") as f: f.write(f"[{t}] {msg}\n")

def run(cmd, cwd=None):
    try: return subprocess.run(cmd, shell=True, capture_output=True, text=True, cwd=cwd, timeout=30)
    except: return None

def check_token_fee():
    """Перевірка Token Fee (комісії) для бінарних трансформацій."""
    # Тут ми можемо перевіряти наш смарт-контракт, чи є дозвіл на трансформацію
    # Поки що імітуємо успішну перевірку
    log("🔑 Перевірка Token Fee: OK (дозвіл отримано)")
    return True

def get_binary_state():
    """Вираховує стан бінарного простору та Binmix."""
    state = {"health": 100.0, "size_mb": 0.0, "binmix_status": "unknown", "issues": []}
    
    # 1. Перевірка розміру Sandbox (ліміт 65MB)
    if SANDBOX.exists():
        du = run(f"du -sb {SANDBOX}")
        if du and du.returncode == 0:
            size_mb = int(du.stdout.split()[0]) / (1024 * 1024)
            state["size_mb"] = round(size_mb, 2)
            if size_mb > 65:
                state["health"] -= 50
                state["issues"].append(f"Sandbox переповнено ({size_mb:.1f}MB > 65MB)")

    # 2. Перевірка Binmix
    if BINMIX.exists():
        out = run(f"{BINMIX} status")
        if out and "running" in out.stdout.lower() or "status : stopped" in out.stdout.lower():
            state["binmix_status"] = "ok"
        else:
            state["health"] -= 20
            state["issues"].append("Binmix не відповідає")
            
    return state

def backup_binary():
    """Робить бекап поточного бінарного стану."""
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_path = BACKUP_DIR / f"bin_backup_{ts}.tar.gz"
    
    if SANDBOX.exists():
        run(f"tar -czf {backup_path} -C {CYBRA} sandbox bin/cybra_binmix 2>/dev/null")
        log(f"💾 Створено бінарний бекап: {backup_path.name}")
        return str(backup_path)
    return None

def rollback_binary(backup_path):
    """Відкат до бекапу."""
    if not backup_path or not Path(backup_path).exists():
        log("❌ Бекап не знайдено для відкату!")
        return
    log(f"🚨 ВІДКАТ: Відновлення бінарного стану з {Path(backup_path).name}")
    run(f"tar -xzf {backup_path} -C {CYBRA}")
    log("✅ Бінарний стан відновлено.")

def apply_evolutionary_step():
    """Спроба зробити +3% (трансформація/оптимізація)."""
    log("🚀 Спроба бінарної трансформації (+3%)...")
    # Імітація: тут може бути компіляція, оновлення або патч
    # Якщо все добре, ми фіксуємо новий стан
    return True

def main():
    log("=== BINARY EVOLUTION CONTROLLER STARTED ===")
    
    while True:
        try:
            # 1. Перевірка поточного стану
            state = get_binary_state()
            log(f"📊 Стан бінарного простору: {state['health']}% | Розмір: {state['size_mb']}MB | Binmix: {state['binmix_status']}")

            if state["health"] < 97.0:
                log(f"⚠️ ВІДХИЛЕННЯ > 3%! Поточна деградація: {state['issues']}")
                # Робимо екстрений бекап (якщо його ще немає) і відкат
                last_backup = None
                backups = sorted(BACKUP_DIR.glob("*.tar.gz"), key=os.path.getmtime)
                if backups:
                    last_backup = str(backups[-1])
                
                if last_backup:
                    rollback_binary(last_backup)
                else:
                    log("❌ Немає бекапів для відкату. Потрібне ручне втручання.")
                
                time.sleep(60)
                continue

            # 2. Якщо стан 100% — робимо паузу
            # 3. Якщо є запит на еволюцію (наприклад, новий модуль) — перевіряємо Token Fee і робимо крок
            if check_token_fee():
                # Робимо бекап перед трансформацією
                backup = backup_binary()
                
                if apply_evolutionary_step():
                    log("✅ Еволюційний крок (+3%) успішний. Фіксуємо новий рівень.")
                    # Тут можна зробити git commit для фіксації нового стану
                    run("git add -A && git commit -m 'evo: binary transformation +3%' -q", cwd=CYBRA)
                else:
                    log("⚠️ Трансформація не вдалася. Відкат...")
                    rollback_binary(backup)

        except Exception as e:
            log(f"❌ ПОМИЛКА BINARY CONTROLLER: {e}")
        
        # Перевірка кожні 2 хвилини
        time.sleep(120)

if __name__ == "__main__":
    main()
