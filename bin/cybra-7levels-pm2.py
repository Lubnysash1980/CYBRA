#!/usr/bin/env python3
import os, time, subprocess, json
from pathlib import Path
from datetime import datetime, timezone

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
STATE_FILE = CYBRA / "state/7levels_state.json"
LOG = CYBRA / "logs/7levels_pm2.log"
STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
LOG.parent.mkdir(parents=True, exist_ok=True)

def log(msg):
    t = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    with open(LOG, "a") as f: f.write(f"[{t}] {msg}\n")
    print(f"[{t}] {msg}")

def run(cmd):
    try: return subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=30)
    except: return None

def get_ram_usage():
    """Читаємо RAM напряму з /proc/meminfo (працює на будь-якому Android)"""
    try:
        with open("/proc/meminfo", "r") as f:
            meminfo = f.read()
        total = int([line for line in meminfo.splitlines() if "MemTotal" in line][0].split()[1])
        available = int([line for line in meminfo.splitlines() if "MemAvailable" in line][0].split()[1])
        used = total - available
        return (used / total) * 100
    except Exception:
        return 85.0

def calculate_complexity_level(ram_pct):
    if ram_pct > 85: return 1
    elif ram_pct > 80: return 2
    elif ram_pct > 75: return 3
    elif ram_pct > 65: return 4
    elif ram_pct > 55: return 5
    elif ram_pct > 45: return 6
    else: return 7

def manage_pm2(level):
    if level == 1:
        log("⚠️ Рівень 1 (Критичний): Зупиняємо другорядні модулі.")
        run("pm2 stop cybra-ultimate-backend cybra-evo-3pct 2>/dev/null")
    elif level == 3:
        log("⚖️ Рівень 3: Система стабільна. Працюємо в базовому режимі.")

def auto_pm2_save():
    run("pm2 save -q")
    log("💾 PM2 State Saved (Auto-save).")

def main():
    log("=== 7 LEVELS & PM2 MANAGER STARTED ===")
    last_save = time.time()
    last_level = 0
    
    while True:
        try:
            ram = get_ram_usage()
            level = calculate_complexity_level(ram)
            
            state = {"ram_pct": round(ram, 1), "level": level, "updated": datetime.now(timezone.utc).isoformat()}
            STATE_FILE.write_text(json.dumps(state))

            if level != last_level:
                log(f"📊 RAM: {ram:.1f}% | Встановлено Рівень Складності: {level}/7")
                manage_pm2(level)
                last_level = level

            if time.time() - last_save > 600:
                auto_pm2_save()
                last_save = time.time()

        except Exception as e:
            log(f"❌ ПОМИЛКА 7 LEVELS: {e}")
        
        time.sleep(60)

if __name__ == "__main__":
    main()
