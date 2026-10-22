#!/usr/bin/env python3
import os, time, subprocess, json
from pathlib import Path
from datetime import datetime, timezone

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
STATE_FILE = CYBRA / "state" / "evo_3pct_state.json"
LOG = CYBRA / "logs/evo_3pct.log"
STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
LOG.parent.mkdir(parents=True, exist_ok=True)

def log(msg):
    t = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    with open(LOG, "a") as f:
        f.write(f"[{t}] {msg}\n")

def run(cmd, cwd=None):
    try:
        return subprocess.run(cmd, shell=True, capture_output=True, text=True, cwd=cwd, timeout=30)
    except Exception:
        return None

def get_current_performance():
    """Вираховує поточний відсоток працездатності системи."""
    # 1. Перевірка PM2 (скільки процесів онлайн)
    out = run("pm2 jlist")
    if not out or out.returncode != 0:
        return 0.0
    
    try:
        procs = json.loads(out.stdout)
        if not procs: return 0.0
        online = sum(1 for p in procs if p["pm2_env"]["status"] == "online")
        pm2_score = (online / len(procs)) * 100
    except Exception:
        pm2_score = 0.0

    # 2. Перевірка бінарного простору (не більше 65MB)
    sb = CYBRA / "sandbox"
    sb_score = 100.0
    if sb.exists():
        du = run(f"du -sb {sb}")
        if du and du.returncode == 0:
            size_mb = int(du.stdout.split()[0]) / (1024 * 1024)
            if size_mb > 65: sb_score = 0.0 # Переповнення - критична помилка
            elif size_mb > 60: sb_score = 50.0 # Наближення до ліміту
            
    # 3. Перевірка Git (чи не зламані файли)
    git_score = 100.0
    if (CYBRA / ".git").exists():
        check = run("git diff --check", cwd=CYBRA)
        if check and check.returncode != 0: git_score = 0.0 # Синтаксичні конфлікти

    # Загальний бал (середнє)
    total = (pm2_score + sb_score + git_score) / 3
    return round(total, 2)

def load_state():
    if STATE_FILE.exists():
        try: return json.loads(STATE_FILE.read_text())
        except: pass
    return {"baseline": 100.0, "baseline_commit": "HEAD", "history": []}

def save_state(state):
    STATE_FILE.write_text(json.dumps(state, indent=2))

def rollback_to_baseline(commit):
    """Жорсткий відкат до базового коміту"""
    log(f"🚨 ДЕГРАДАЦІЯ! Відкат до базового коміту: {commit}")
    run(f"git reset --hard {commit}", cwd=CYBRA)
    run("pm2 restart all", cwd=CYBRA)
    # Очищаємо незакомічені зміни, щоб не заважали
    run("git clean -fd -e 'logs/' -e 'state/' -e 'data/' -e 'keys/'", cwd=CYBRA)

def commit_baseline(perf):
    """Фіксує новий рубіж (+3%)"""
    log(f"🚀 ПРОГРЕС! Фіксуємо новий рубіж: {perf}%")
    run("git add -A", cwd=CYBRA)
    run(f'git commit -m "evo: new baseline at {perf}% (3% rule)" -q', cwd=CYBRA)
    out = run("git rev-parse HEAD", cwd=CYBRA)
    return out.stdout.strip() if out else "HEAD"

def main():
    log("=== КОНТРОЛЕР ЕВОЛЮЦІЇ 3% ЗАПУЩЕНО ===")
    state = load_state()
    log(f"Початкова база: {state['baseline']}% (Commit: {state['baseline_commit'][:7]})")

    while True:
        try:
            current = get_current_performance()
            baseline = state["baseline"]
            diff = current - baseline
            
            log(f"Поточний стан: {current}% | База: {baseline}% | Різниця: {diff:+.2f}%")

            # Правило -3% (Відкат)
            if diff <= -3.0:
                rollback_to_baseline(state["baseline_commit"])
                # Після відкату повертаємо базу як є, але оновлюємо статус
                state["history"].append({"time": str(datetime.now()), "event": "rollback", "from": current, "to": baseline})
                save_state(state)
                time.sleep(10) # Даємо час системі піднятися
                continue

            # Правило +3% (Фіксація нового рівня)
            elif diff >= 3.0:
                new_commit = commit_baseline(current)
                state["baseline"] = current
                state["baseline_commit"] = new_commit
                state["history"].append({"time": str(datetime.now()), "event": "progress", "from": baseline, "to": current})
                save_state(state)

            # Якщо в межах -3% ... +3% — просто працюємо (зона толерантності)

        except Exception as e:
            log(f"❌ ПОМИЛКА КОНТРОЛЕРА: {e}")
        
        time.sleep(60) # Перевірка щохвилини

if __name__ == "__main__":
    main()
