#!/usr/bin/env python3
import os, time, subprocess, json, shutil, re
from pathlib import Path
from datetime import datetime, timezone

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
LOG = CYBRA / "logs/conflict_resolver.log"
LOCK_FILE = CYBRA / ".cybra_op_lock"
TASKS_DIR = CYBRA / "parliament_core/tasks"

LOG.parent.mkdir(parents=True, exist_ok=True)
TASKS_DIR.mkdir(parents=True, exist_ok=True)

def log(msg):
    t = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    with open(LOG, "a") as f: f.write(f"[{t}] {msg}\n")
    print(f"[{t}] {msg}")

def run(cmd, cwd=None):
    try: return subprocess.run(cmd, shell=True, capture_output=True, text=True, cwd=cwd, timeout=30)
    except: return None

def create_task(issue, action):
    task_id = f"CONFLICT-{int(time.time())}"
    task_file = TASKS_DIR / f"{task_id}.json"
    task_data = {
        "id": task_id,
        "type": "CONFLICT_RESOLVED",
        "issue": issue,
        "action_taken": action,
        "created": datetime.now(timezone.utc).isoformat(),
        "status": "COMPLETED"
    }
    task_file.write_text(json.dumps(task_data, indent=2, ensure_ascii=False))

def resolve_git_conflicts():
    """Перевіряє та вирішує Git-конфлікти (наприклад, при одночасному push/pull)"""
    git_dir = CYBRA / ".git"
    if not git_dir.exists(): return False

    # 1. Перевірка на наявність незавершеного merge/rebase
    if (git_dir / "MERGE_HEAD").exists() or (git_dir / "rebase-merge").exists():
        log("⚠️ Знайдено незавершений Git Merge/Rebase. Скасовуємо...")
        run("git merge --abort", cwd=CYBRA)
        run("git rebase --abort", cwd=CYBRA)
        run("git reset --hard HEAD", cwd=CYBRA)
        create_task("Git merge/rebase conflict", "Aborted merge and hard reset to HEAD")
        return True

    # 2. Перевірка на конфліктні файли (Unmerged paths)
    status = run("git status --porcelain", cwd=CYBRA)
    if status and any(line.startswith(("UU", "AA", "DD", "AU", "UA", "DU", "UD")) for line in status.stdout.splitlines()):
        log("⚠️ Знайдено конфліктні файли (Unmerged paths). Робимо відкат...")
        run("git reset --hard HEAD", cwd=CYBRA)
        create_task("Git file conflicts", "Hard reset to last commit")
        return True

    # 3. Перевірка "застряглого" lock-файлу (якщо попередній процес впав)
    index_lock = git_dir / "index.lock"
    if index_lock.exists():
        log("⚠️ Знайдено застряглий Git Lock (index.lock). Видаляємо...")
        index_lock.unlink()
        create_task("Git index.lock stuck", "Removed index.lock")
        return True

    return False

def resolve_pm2_conflicts():
    """Перевіряє дублювання процесів у PM2 (коли один скрипт запущено двічі)"""
    out = run("pm2 jlist")
    if not out or out.returncode != 0: return False

    try:
        procs = json.loads(out.stdout)
        names = [p["name"] for p in procs]
        
        # Шукаємо дублікати імен
        duplicates = set([x for x in names if names.count(x) > 1])
        
        if duplicates:
            log(f"⚠️ Знайдено дублікати процесів у PM2: {duplicates}. Видаляємо дублікати...")
            for dup in duplicates:
                # Залишаємо найстаріший (перший), інші вбиваємо
                dup_procs = [p for p in procs if p["name"] == dup]
                for p in dup_procs[1:]:
                    run(f"pm2 delete {p['pm_id']}")
            create_task(f"PM2 duplicate processes: {duplicates}", "Deleted duplicate PM2 processes")
            return True
    except Exception as e:
        log(f"Помилка аналізу PM2: {e}")
    
    return False

def resolve_file_locks():
    """Шукає застряглі файли блокувань від наших скриптів"""
    if LOCK_FILE.exists():
        # Перевіряємо, чи файл старий (наприклад, старший за 10 хвилин)
        if time.time() - LOCK_FILE.stat().st_mtime > 600:
            log("⚠️ Знайдено застряглий Lock-файл системи. Видаляємо...")
            LOCK_FILE.unlink()
            create_task("Stuck CYBRA lock file", "Removed stale lock file")
            return True
    return False

def main():
    log("=== CONFLICT RESOLVER ЗАПУЩЕНО ===")
    while True:
        try:
            has_conflict = False
            
            if resolve_git_conflicts(): has_conflict = True
            if resolve_pm2_conflicts(): has_conflict = True
            if resolve_file_locks(): has_conflict = True

            if has_conflict:
                log("✅ Конфлікти вирішено. Перезапускаємо систему для фіксації безконфліктного стану...")
                run("pm2 restart all")
                # Даємо час системі відновитися
                time.sleep(10)
            else:
                # Якщо конфліктів немає, просто тихо чекаємо
                pass

        except Exception as e:
            log(f"❌ ПОМИЛКА RESOLVER: {e}")
        
        # Перевірка кожні 30 секунд
        time.sleep(30)

if __name__ == "__main__":
    main()
