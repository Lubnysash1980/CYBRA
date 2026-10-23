#!/usr/bin/env python3
import os, time, subprocess, json, uuid
from pathlib import Path
from datetime import datetime, timezone

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
LOG = CYBRA / "logs/absolute_state.log"
TASKS_DIR = CYBRA / "parliament_core/tasks"
STATE_HISTORY = CYBRA / "state/state_history.json"

def log(msg):
    t = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    with open(LOG, "a") as f: f.write(f"[{t}] {msg}\n")
    print(f"[{t}] {msg}")

def run(cmd):
    try: return subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=30)
    except: return None

def get_100_percent_state():
    """Визначає, чи система в ідеальному стані."""
    issues = []
    score = 100.0

    # 1. Перевірка PM2 процесів (Ядро)
    out = run("pm2 jlist")
    if out and out.returncode == 0:
        try:
            procs = json.loads(out.stdout)
            # Шукаємо завислі процеси (errored або stopped)
            for p in procs:
                if p["pm2_env"]["status"] in ["errored", "stopped"]:
                    issues.append(f"Процес {p['name']} впав ({p['pm2_env']['status']})")
                    score -= 20
        except: pass
    else:
        issues.append("PM2 daemon не відповідає")
        score -= 50

    # 2. Перевірка FIDIC (чи не зламалися контракти)
    fidic_dir = CYBRA / "data/fidic"
    if fidic_dir.exists():
        for f in fidic_dir.glob("*.json"):
            if run(f"python3 -m json.tool {f}").returncode != 0:
                issues.append(f"FIDIC контракт {f.name} пошкоджено")
                score -= 10

    return score, issues

def create_task(action, issue):
    """Створює задачу для екзекутора."""
    task_id = f"TASK-{uuid.uuid4().hex[:6]}"
    task_file = TASKS_DIR / f"{task_id}.json"
    task_data = {
        "id": task_id,
        "action": action,
        "issue": issue,
        "created": datetime.now(timezone.utc).isoformat(),
        "status": "PENDING"
    }
    task_file.write_text(json.dumps(task_data, indent=2))
    log(f"📝 Створено задачу {task_id}: {action} (Причина: {issue})")

def auto_heal(issue):
    """Автоматичне виправлення простих проблем."""
    if "впав" in issue:
        log(f"🔧 Auto-Heal: Перезапуск процесу...")
        log("⚠️ Перезапуск (ігноровано, ми всередині Моноліту)")
    elif "не відповідає" in issue:
        log("🔧 Auto-Heal: Підняття PM2...")
        log("⚠️ Resurrect (ігноровано)")

def main():
    log("=== АБСОЛЮТНИЙ ТРЕКЕР СТАНУ ЗАПУЩЕНО ===")
    if not STATE_HISTORY.exists():
        STATE_HISTORY.write_text('{"history": [], "baseline": 100.0}')

    while True:
        try:
            score, issues = get_100_percent_state()
            
            # Записуємо історію
            state = json.loads(STATE_HISTORY.read_text())
            state["history"].append({"time": datetime.now(timezone.utc).isoformat(), "score": score})
            if len(state["history"]) > 100: state["history"] = state["history"][-100:] # Тримаємо останні 100 записів
            STATE_HISTORY.write_text(json.dumps(state, indent=2))

            if score < 100.0:
                log(f"⚠️ ВІДХИЛЕННЯ ВІД 100%! Поточний стан: {score}%")
                for issue in issues:
                    log(f"   - {issue}")
                    auto_heal(issue)
                    # Даємо задачу екзекутору, якщо автовідновлення не допоможе
                    create_task("fix_system", issue)
                
                # Якщо падіння критичне (менше 90%), робимо відкат
                if score < 90:
                    log("🚨 КРИТИЧНИЙ РЕГРЕС (<90%). Відкат до Git Baseline!")
                    run("git reset --hard HEAD")
                    log("⚠️ Перезапуск (ігноровано, ми всередині Моноліту)")
            else:
                log("✅ СИСТЕМА В 100% СТАНІ. Середовище сприятливе для розвитку.")

        except Exception as e:
            log(f"❌ ПОМИЛКА ТРЕКЕРА: {e}")
        
        time.sleep(30) # Перевірка кожні 30 секунд

if __name__ == "__main__":
    main()
