#!/usr/bin/env python3
import os, subprocess, time, json, shutil
from pathlib import Path
from datetime import datetime, timezone

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
LOG = CYBRA / "logs/strict_validator.log"
TASKS_DIR = CYBRA / "parliament_core/tasks"
BACKUP_DIR = CYBRA / "state/strict_backups"

LOG.parent.mkdir(parents=True, exist_ok=True)
TASKS_DIR.mkdir(parents=True, exist_ok=True)
BACKUP_DIR.mkdir(parents=True, exist_ok=True)

def log(msg):
    t = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    with open(LOG, "a") as f: f.write(f"[{t}] {msg}\n")
    print(f"[{t}] {msg}")

def create_task(issue, file_path):
    task_id = f"SYNTAX-FIX-{int(time.time())}"
    task_file = TASKS_DIR / f"{task_id}.json"
    task_data = {
        "id": task_id,
        "action": "FIX_SYNTAX_ERROR",
        "file": str(file_path),
        "issue": issue,
        "created": datetime.now(timezone.utc).isoformat(),
        "status": "PENDING"
    }
    task_file.write_text(json.dumps(task_data, indent=2))

def check_file(filepath):
    """Перевіряє синтаксис файлу залежно від розширення"""
    ext = filepath.suffix
    res = None
    
    if ext == ".py":
        res = subprocess.run(["python3", "-m", "py_compile", str(filepath)], capture_output=True, text=True)
    elif ext == ".sh":
    # SAFE: res = subprocess.run(["bash", "-n", str(filepath)], capture_output=True, text=True)
    elif ext == ".js":
    # SAFE: res = subprocess.run(["node", "-c", str(filepath)], capture_output=True, text=True)
    else:
        return True # Ігноруємо інші файли
        
    return res.returncode == 0

def auto_heal(filepath, error_msg):
    log(f"🚨 ЗНАЙДЕНО ПОМИЛКУ у {filepath.name}: {error_msg}")
    
    # 1. Робимо бекап зламаного файлу (для історії)
    ts = int(time.time())
    broken_backup = BACKUP_DIR / f"{filepath.name}.broken.{ts}"
    shutil.copy2(filepath, broken_backup)
    
    # 2. Відкат до останньої робочої версії з Git
    log(f"🔄 Відкат {filepath.name} до останньої стабільної версії...")
    subprocess.run(["git", "checkout", "HEAD", "--", str(filepath)], cwd=CYBRA)
    
    # 3. Створюємо задачу для Парламенту/ШІ
    create_task(error_msg, filepath)
    
    log(f"✅ Файл {filepath.name} відновлено. Створено задачу на виправлення.")

def main():
    log("=== STRICT VALIDATOR STARTED (Zero-Error Policy) ===")
    while True:
        try:
            # Перевіряємо всі .py, .sh та .js файли в системі
            extensions = ["*.py", "*.sh", "*.js"]
            for ext in extensions:
                for filepath in CYBRA.rglob(ext):
                    # Пропускаємо системні папки
                    if any(x in str(filepath) for x in [".git", "logs", "state", "node_modules", "backups"]):
                        continue
                        
                    if not check_file(filepath):
                        # Якщо файл зламаний - лікуємо
                        res = ""
                        if filepath.suffix == ".py":
                            res = subprocess.run(["python3", "-m", "py_compile", str(filepath)], capture_output=True, text=True).stderr
                        elif filepath.suffix == ".sh":
    # SAFE: res = subprocess.run(["bash", "-n", str(filepath)], capture_output=True, text=True).stderr
                        elif filepath.suffix == ".js":
    # SAFE: res = subprocess.run(["node", "-c", str(filepath)], capture_output=True, text=True).stderr
                            
                        auto_heal(filepath, res[:200]) # Беремо перші 200 символів помилки
                        
        except Exception as e:
            log(f"❌ ПОМИЛКА ВАЛІДАТОРА: {e}")
        
        # Перевірка кожні 5 хвилин
        time.sleep(300)

if __name__ == "__main__":
    main()
