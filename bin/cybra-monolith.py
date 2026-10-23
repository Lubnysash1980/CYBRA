#!/usr/bin/env python3
import os, time, subprocess, signal, sys
from pathlib import Path
from datetime import datetime, timezone

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
LOG = CYBRA / "logs/monolith.log"
LOG.parent.mkdir(parents=True, exist_ok=True)

def log(msg):
    t = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    with open(LOG, "a") as f: f.write(f"[{t}] {msg}\n")

# Список усіх процесів, які ми об'єднуємо
# Формат: (Назва, Шлях до скрипта, Інтерпретатор, Додаткові аргументи)
PROCESSES = [
    ("Autonode", CYBRA / "bin/cybra_autonode_main.js", "node", []),
    ("Parliament", CYBRA / "parliament_core/priority_manager.py", "python3", ["daemon"]),
    ("MainController", CYBRA / "bin/cybra-main-controller.py", "python3", []),
    ("AbsoluteState", CYBRA / "bin/cybra-absolute-state.py", "python3", []),
    ("BinaryEvolution", CYBRA / "bin/cybra-binary-evolution.py", "python3", []),
    ("ConflictResolver", CYBRA / "bin/cybra-conflict-resolver.py", "python3", []),
    ("ClusterLB", CYBRA / "bin/cybra-cluster-lb.py", "python3", []),
    ("EvoSafe", CYBRA / "bin/cybra-evo-safe.py", "python3", []),
]

children = {}

def start_process(name, path, interp, args):
    if not path.exists():
        log(f"⚠️ {name}: Файл не знайдено ({path}). Пропускаємо.")
        return None
    
    cmd = [interp, str(path)] + args
    try:
        # Запускаємо процес, перенаправляємо вивід у логи
        log_file = open(CYBRA / f"logs/{name.lower()}_sub.log", "a")
        p = subprocess.Popen(cmd, stdout=log_file, stderr=subprocess.STDOUT, cwd=str(CYBRA))
        log(f"▶️ Запущено {name} (PID: {p.pid})")
        return p
    except Exception as e:
        log(f"❌ Помилка запуску {name}: {e}")
        return None

def shutdown(sig, frame):
    log("🛑 Отримано сигнал зупинки. Вбиваємо всі підпроцеси...")
    for name, p in children.items():
        if p and p.poll() is None:
            p.terminate()
            try: p.wait(timeout=3)
            except: p.kill()
    log("✅ Всі процеси зупинено. Вихід.")
    sys.exit(0)

def main():
    log("=== МОНОЛІТНИЙ МАСТЕР ЗАПУЩЕНО ===")
    signal.signal(signal.SIGINT, shutdown)
    signal.signal(signal.SIGTERM, shutdown)

    # Початковий запуск
    for name, path, interp, args in PROCESSES:
        children[name] = start_process(name, path, interp, args)
        time.sleep(1) # Запускаємо з невеликою затримкою, щоб не було пікового навантаження

    # Цикл моніторингу (якщо якийсь скрипт впав — піднімаємо)
    while True:
        try:
            for name, path, interp, args in PROCESSES:
                p = children.get(name)
                # Якщо процес є, але він завершився (впав)
                if p and p.poll() is not None:
                    log(f"⚠️ {name} впав (Код: {p.returncode}). Перезапуск...")
                    children[name] = start_process(name, path, interp, args)
        except Exception as e:
            log(f"❌ ПОМИЛКА МАСТЕРА: {e}")
        
        time.sleep(5)

if __name__ == "__main__":
    main()
