#!/usr/bin/env python3
import os, time, subprocess, json, socket
from pathlib import Path
from datetime import datetime, timezone

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
NODES_DIR = CYBRA / "nodes"
HEARTBEAT_DIR = NODES_DIR / "heartbeats"
DEVICE_ID = socket.gethostname().replace(" ", "_")
LOG = CYBRA / "logs/cluster_lb.log"

HEARTBEAT_DIR.mkdir(parents=True, exist_ok=True)
LOG.parent.mkdir(parents=True, exist_ok=True)

# Список процесів, якими ми можемо керувати
MANAGED_PROCS = [
    "cybra-autonode", "cybra-parliament", "cybra-evo-safe", 
    "cybra-binary-evolution", "cybra-conflict-resolver"
]

def log(msg):
    t = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    with open(LOG, "a") as f: f.write(f"[{t}] {msg}\n")
    print(f"[{t}] {msg}")

def run(cmd):
    try: return subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=30)
    except: return None

def update_heartbeat():
    """Пишемо наш пульс у файл і відправляємо в Git"""
    hb_file = HEARTBEAT_DIR / f"{DEVICE_ID}.json"
    data = {"device": DEVICE_ID, "last_seen": time.time()}
    hb_file.write_text(json.dumps(data))
    
    # Відправляємо в Git (щоб інші бачили)
    run("git add nodes/heartbeats/ && git commit -m 'hb: cluster heartbeat' -q && git push origin main -q", cwd=CYBRA)

def get_active_devices():
    """Аналізуємо пульси інших пристроїв (хто живий)"""
    run("git pull origin main --rebase -q", cwd=CYBRA) # Стягуємо свіжі пульси
    active = []
    now = time.time()
    
    for f in HEARTBEAT_DIR.glob("*.json"):
        try:
            data = json.loads(f.read_text())
            # Якщо пульс був менше 3 хвилин тому - пристрій живий
            if now - data["last_seen"] < 180:
                active.append(data["device"])
        except: pass
    return active

def get_my_processes():
    """Дивимось, які процеси зараз запущені на цьому пристрої"""
    out = run("pm2 jlist")
    if not out or out.returncode != 0: return []
    try:
        procs = json.loads(out.stdout)
        return [p["name"] for p in procs if p["name"] in MANAGED_PROCS and p["pm2_env"]["status"] == "online"]
    except: return []

def rebalance():
    update_heartbeat()
    active_devices = get_active_devices()
    
    # Сортуємо, щоб порядок пристроїв був однаковий на всіх
    active_devices.sort()
    total_devices = len(active_devices)
    if total_devices == 0: return # Ми єдині
    
    my_index = active_devices.index(DEVICE_ID) if DEVICE_ID in active_devices else 0
    my_procs = get_my_processes()
    
    log(f"🌍 Пристроїв онлайн: {total_devices} ({', '.join(active_devices)})")
    log(f"📦 Наші процеси ({DEVICE_ID}): {my_procs}")

    # ЛОГІКА ПЕРЕРОЗПОДІЛУ:
    # Ми ділимо процеси між пристроями. Якщо пристроїв 2, то 50/50.
    # Але якщо пристрій падає, той, що лишився, бере 100%.
    procs_per_device = len(MANAGED_PROCS) / total_devices
    
    # Визначаємо, які процеси МАЮТЬ бути на цьому пристрої
    target_procs = []
    for i, proc in enumerate(MANAGED_PROCS):
        # Розподіляємо по колу: якщо 5 процесів і 2 пристрої, 
        # пристрій 0 бере 0, 2, 4; пристрій 1 бере 1, 3.
        if i % total_devices == my_index:
            target_procs.append(proc)

    # ПЛАВНИЙ ПЕРЕРОЗПОДІЛ (по одному процесу за раз)
    procs_to_start = [p for p in target_procs if p not in my_procs]
    procs_to_stop = [p for p in my_procs if p not in target_procs]

    if procs_to_stop:
        proc = procs_to_stop[0]
        log(f"⏸ Плавно зупиняємо {proc} (передаємо іншому вузлу)...")
        run(f"pm2 stop {proc}")
        time.sleep(5) # Пауза для плавності
        return True # Робимо тільки одну дію за цикл

    if procs_to_start:
        proc = procs_to_start[0]
        log(f"▶️ Плавно запускаємо {proc} (підхоплюємо навантаження)...")
        script_path = find_script(proc)
        if script_path:
            interp = "node" if script_path.endswith(".js") else "python3"
            run(f"pm2 start {script_path} --name {proc} --interpreter {interp}")
            time.sleep(5)
            return True

    return False

def find_script(name):
    """Шукає шлях до скрипта за назвою процесу"""
    paths = {
        "cybra-autonode": CYBRA / "bin/cybra_autonode_main.js",
        "cybra-parliament": CYBRA / "parliament_core/priority_manager.py",
        "cybra-evo-safe": CYBRA / "bin/cybra-evo-safe.py",
        "cybra-binary-evolution": CYBRA / "bin/cybra-binary-evolution.py",
        "cybra-conflict-resolver": CYBRA / "bin/cybra-conflict-resolver.py"
    }
    return str(paths.get(name, ""))

def main():
    log(f"=== CLUSTER LOAD BALANCER STARTED ({DEVICE_ID}) ===")
    run(f"git config user.name '{DEVICE_ID}'", cwd=CYBRA)
    run(f"git config user.email '{DEVICE_ID}@cybra.local'", cwd=CYBRA)

    while True:
        try:
            # Робимо перерозподіл тільки якщо є необхідність
            if rebalance():
                log("✅ Крок перерозподілу завершено. Чекаємо...")
        except Exception as e:
            log(f"❌ ПОМИЛКА LB: {e}")
        
        # Перевірка кожні 60 секунд (щоб не спамити Git)
        time.sleep(60)

if __name__ == "__main__":
    main()
