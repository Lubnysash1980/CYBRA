#!/usr/bin/env python3
import os, time, subprocess, json, shutil
from pathlib import Path
from datetime import datetime, timezone

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
LOG = CYBRA / "logs/orchestrator.log"
METRICS_FILE = CYBRA / "state/orchestrator_metrics.json"
TASKS_DIR = CYBRA / "parliament_core/tasks"

LOG.parent.mkdir(parents=True, exist_ok=True)
METRICS_FILE.parent.mkdir(parents=True, exist_ok=True)
TASKS_DIR.mkdir(parents=True, exist_ok=True)

# СПИСОК ОЧІКУВАНИХ КОНТРОЛЕРІВ (Що має бути в системі)
EXPECTED_CONTROLLERS = {
    "Autonode": CYBRA / "bin/cybra_autonode_main.js",
    "Parliament": CYBRA / "parliament_core/priority_manager.py",
    "MainController": CYBRA / "bin/cybra-main-controller.py",
    "AbsoluteState": CYBRA / "bin/cybra-absolute-state.py",
    "BinaryEvolution": CYBRA / "bin/cybra-binary-evolution.py",
    "ConflictResolver": CYBRA / "bin/cybra-conflict-resolver.py",
    "ClusterLB": CYBRA / "bin/cybra-cluster-lb.py",
    "EvoSafe": CYBRA / "bin/cybra-evo-safe.py",
    "FIDIC_Engine": CYBRA / "bin/fidic-engine.py",
    "Monolith": CYBRA / "bin/cybra-monolith.py"
}

def log(msg):
    t = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    with open(LOG, "a") as f: f.write(f"[{t}] {msg}\n")
    print(f"[{t}] {msg}")

def run(cmd):
    try: return subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=30)
    except: return None

def check_autoconfig():
    """Перевіряє та створює базову структуру папок (Автоконфіг)"""
    required_dirs = ["logs", "state", "data/fidic", "parliament_core/tasks", "sandbox"]
    for d in required_dirs:
        path = CYBRA / d
        if not path.exists():
            path.mkdir(parents=True, exist_ok=True)
            log(f"🔧 Автоконфіг: Створено відсутню папку {d}")
    
    # Перевірка файлу цілі
    goal = CYBRA / "cybra_goal.json"
    if not goal.exists():
        goal.write_text('{"ultimate_goal": "100% State", "status": "ACTIVE"}')
        log("🔧 Автоконфіг: Відновлено файл цілі (cybra_goal.json)")

def check_controllers():
    """Перевіряє, чи всі контролери фізично існують"""
    missing = []
    for name, path in EXPECTED_CONTROLLERS.items():
        if not path.exists():
            missing.append(name)
            log(f"🚨 ВТРАТА: Контролер {name} відсутній за шляхом {path}")
    
    if missing:
        create_task("RESTORE_CONTROLLERS", f"Відсутні контролери: {', '.join(missing)}")
    return missing

def get_metrics():
    """Збирає статистику системи"""
    metrics = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "pm2_processes": 0,
        "ram_usage_mb": 0,
        "disk_free_mb": 0,
        "missing_controllers": [],
        "system_health": "OK"
    }

    # 1. PM2 Процеси
    out = run("pm2 jlist")
    if out and out.returncode == 0:
        try:
            procs = json.loads(out.stdout)
            metrics["pm2_processes"] = len(procs)
        except: pass

    # 2. RAM (через free -m)
    out = run("free -m | grep Mem")
    if out:
        parts = out.stdout.split()
        if len(parts) >= 3:
            metrics["ram_usage_mb"] = int(parts[2]) # Used memory

    # 3. Диск (через df)
    out = run("df -m /data | tail -1")
    if out:
        parts = out.stdout.split()
        if len(parts) >= 4:
            metrics["disk_free_mb"] = int(parts[3])

    return metrics

def create_task(action, details):
    """Створює задачу для ШІ-Екзекуторів"""
    task_id = f"ORCH-{int(time.time())}"
    task_file = TASKS_DIR / f"{task_id}.json"
    task_data = {
        "id": task_id,
        "action": action,
        "details": details,
        "created": datetime.now(timezone.utc).isoformat(),
        "status": "PENDING",
        "assigned_to": "AI_Executor"
    }
    task_file.write_text(json.dumps(task_data, indent=2, ensure_ascii=False))
    log(f"📝 Створено задачу для Екзекутора: {action} (Деталі: {details})")

def main():
    log("=== ГОЛОВНИЙ ОРКЕСТРАТОР ЗАПУЩЕНО ===")
    
    while True:
        try:
            # 1. Перевіряємо Автоконфіг (папки та файли)
            check_autoconfig()
            
            # 2. Перевіряємо наявність усіх контролерів
            missing = check_controllers()
            
            # 3. Збираємо статистику
            metrics = get_metrics()
            metrics["missing_controllers"] = missing
            if missing:
                metrics["system_health"] = "DEGRADED"
                
            # 4. Зберігаємо статистику для інших
            METRICS_FILE.write_text(json.dumps(metrics, indent=2))
            
            # 5. Аналіз: якщо пам'ять > 85% або є втрати — пишемо звіт
            if metrics["ram_usage_mb"] > 0 and metrics["disk_free_mb"] < 1000:
                log("⚠️ КРИТИЧНО МАЛО МІСЦЯ НА ДИСКУ! Створюємо задачу на очищення.")
                create_task("CLEANUP_DISK", f"Вільно лише {metrics['disk_free_mb']}MB")

            if not missing:
                # Якщо все добре, оновлюємо статус
                log(f"📊 Метрики: PM2={metrics['pm2_processes']} процесів, RAM={metrics['ram_usage_mb']}MB. Всі контролери на місці.")

        except Exception as e:
            log(f"❌ ПОМИЛКА ОРКЕСТРАТОРА: {e}")
        
        # Оновлення кожні 2 хвилини
        time.sleep(120)

if __name__ == "__main__":
    main()
