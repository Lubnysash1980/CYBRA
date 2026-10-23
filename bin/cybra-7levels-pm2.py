#!/usr/bin/env python3
import os, time, subprocess, json
from pathlib import Path
from datetime import datetime, timezone

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
STATE_FILE = CYBRA / "state/7levels_state.json"
LOG = CYBRA / "logs/7levels_pm2.log"
TASKS_DIR = CYBRA / "parliament_core/tasks"

STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
LOG.parent.mkdir(parents=True, exist_ok=True)
TASKS_DIR.mkdir(parents=True, exist_ok=True)

def log(msg):
    t = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    with open(LOG, "a") as f: f.write(f"[{t}] {msg}\n")

def get_ram_usage():
    """Читаємо RAM напряму з /proc/meminfo (працює на Android)"""
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

def main():
    log("=== 7 LEVELS & PM2 MANAGER STARTED ===")
    last_level = 0
    
    while True:
        try:
            ram = get_ram_usage()
            level = calculate_complexity_level(ram)
            
            state = {"ram_pct": round(ram, 1), "level": level, "updated": datetime.now(timezone.utc).isoformat()}
            STATE_FILE.write_text(json.dumps(state))

            if level != last_level:
                log(f"📊 RAM: {ram:.1f}% | Встановлено Рівень Складності: {level}/7")
                
                # Якщо рівень критичний (1 або 2) - створюємо задачу для парламенту
                if level <= 2:
                    task_file = TASKS_DIR / f"LEVEL-{level}-{int(time.time())}.json"
                    task_file.write_text(json.dumps({"level": level, "action": "OPTIMIZE_RAM", "created": time.time()}))
                    log(f"📝 Створено задачу для Парламенту: Оптимізувати RAM (Рівень {level})")
                
                last_level = level

        except Exception as e:
            log(f"❌ ПОМИЛКА 7 LEVELS: {e}")
        
        # Перевірка кожні 60 секунд
        time.sleep(60)

if __name__ == "__main__":
    main()
