#!/usr/bin/env python3
import os, time, json, shutil
from pathlib import Path
from datetime import datetime, timezone

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
LOG = CYBRA / "logs/main-controller.log"
STATE_FILE = CYBRA / "state/main_controller_state.json"

LOG.parent.mkdir(parents=True, exist_ok=True)
STATE_FILE.parent.mkdir(parents=True, exist_ok=True)

def log(msg):
    t = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    with open(LOG, "a") as f: f.write(f"[{t}] {msg}\n")

def get_disk_space():
    try:
        total, used, free = shutil.disk_usage("/data")
        return free / (1024 * 1024) # В MB
    except: return 0

def get_ram_usage():
    try:
        with open("/proc/meminfo", "r") as f:
            meminfo = f.read()
        total = int([l for l in meminfo.splitlines() if "MemTotal" in l][0].split()[1])
        available = int([l for l in meminfo.splitlines() if "MemAvailable" in l][0].split()[1])
        return ((total - available) / total) * 100
    except: return 0

def main():
    log("=== MAIN CONTROLLER (MONOLITH INTERNAL) STARTED ===")
    
    while True:
        try:
            ram = get_ram_usage()
            disk_free = get_disk_space()
            
            # Зберігаємо стан
            state = {
                "ram_pct": round(ram, 1),
                "disk_free_mb": round(disk_free, 1),
                "updated": datetime.now(timezone.utc).isoformat()
            }
            STATE_FILE.write_text(json.dumps(state, indent=2))

            # Аварійне логування, якщо стає зовсім погано
            if ram > 92.0:
                log(f"🚨 КРИТИЧНА НЕСТАЧА RAM: {ram:.1f}%! Потрібна оптимізація.")
            elif disk_free < 500:
                log(f"🚨 КРИТИЧНО МАЛО МІСЦЯ: {disk_free:.1f} MB!")

            # Оновлюємо статус раз на хвилину
            log(f"📊 Стан: RAM={ram:.1f}% | Диск={disk_free:.1f} MB вільно | Всі системи в нормі.")

        except Exception as e:
            log(f"❌ ПОМИЛКА MAIN CONTROLLER: {e}")
        
        time.sleep(60)

if __name__ == "__main__":
    main()
