#!/usr/bin/env python3
import os, time, subprocess, json, shutil
from pathlib import Path
from datetime import datetime, timezone

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
STATE_FILE = CYBRA / "state" / "evo_safe_state.json"
LOG = CYBRA / "logs/evo_safe.log"
FIDIC_DIR = CYBRA / "data" / "fidic"

STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
LOG.parent.mkdir(parents=True, exist_ok=True)

def log(msg):
    t = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    with open(LOG, "a") as f:
        f.write(f"[{t}] {msg}\n")
    print(f"[{t}] {msg}")

def run(cmd, cwd=None):
    try:
    # SAFE: return subprocess.run(cmd, shell=True, capture_output=True, text=True, cwd=cwd, timeout=30)
    except Exception:
        return None

def get_system_score():
    """Вираховує 100% стан системи на основі PM2, FIDIC та Sandbox."""
    score = 100.0
    details = []

    # 1. Перевірка PM2 (Ядро)
    core_procs = ["cybra-parliament", "cybra-autonode", "cybra-main-controller"]
    out = run("pm2 jlist")
    if out and out.returncode == 0:
        try:
            procs = json.loads(out.stdout)
            online = sum(1 for p in procs if p["name"] in core_procs and p["pm2_env"]["status"] == "online")
            if online < len(core_procs):
                penalty = (len(core_procs) - online) * 15 # Штраф 15% за кожен впавший процес
                score -= penalty
                details.append(f"PM2: {online}/{len(core_procs)} online (-{penalty}%)")
        except: pass
    else:
        score -= 50 # Якщо PM2 взагалі не відповідає
        details.append("PM2 не відповідає (-50%)")

    # 2. Перевірка FIDIC даних (чи не зламалися JSON-файли контрактів)
    if FIDIC_DIR.exists():
        bad_fidic = 0
        for f in FIDIC_DIR.glob("*.json"):
            chk = run(f"python3 -m json.tool {f}", cwd=CYBRA)
            if chk and chk.returncode != 0:
                bad_fidic += 1
        
        if bad_fidic > 0:
            penalty = bad_fidic * 20
            score -= penalty
            details.append(f"FIDIC: {bad_fidic} битих файлів (-{penalty}%)")

    # 3. Перевірка бінарного простору 65MB
    sb = CYBRA / "sandbox"
    if sb.exists():
        du = run(f"du -sb {sb}")
        if du and du.returncode == 0:
            size_mb = int(du.stdout.split()[0]) / (1024 * 1024)
            if size_mb > 65:
                score -= 30
                details.append(f"Sandbox переповнено: {size_mb:.1f}MB (-30%)")

    return max(0.0, round(score, 2)), details

def load_state():
    if STATE_FILE.exists():
        try: return json.loads(STATE_FILE.read_text())
        except: pass
    return {"baseline": 100.0, "baseline_commit": "HEAD", "history": []}

def save_state(state):
    STATE_FILE.write_text(json.dumps(state, indent=2))

def rollback(commit):
    log(f"🚨 КРИТИЧНА ДЕГРАДАЦІЯ (< -3%). Відкат до базового коміту {commit[:7]}...")
    run(f"git reset --hard {commit}", cwd=CYBRA)
    run("git clean -fd -e 'logs/' -e 'state/' -e 'data/' -e 'keys/' -e 'evidence/'", cwd=CYBRA)
    run("pm2 restart all", cwd=CYBRA)
    log("✅ Відкат завершено. Система відновлена.")

def auto_save(score):
    log(f"🚀 ПРОГРЕС (> +3%). Фіксація нового рубіжу: {score}%")
    run("git add -A", cwd=CYBRA)
    run(f'git commit -m "evo: auto-save baseline at {score}% (+3% rule)" -q', cwd=CYBRA)
    out = run("git rev-parse HEAD", cwd=CYBRA)
    new_commit = out.stdout.strip() if out else "HEAD"
    log("🔄 Перезапуск PM2 для фіксації стану...")
    run("pm2 restart all", cwd=CYBRA)
    return new_commit

def main():
    log("=== EVOLUTION SAFE CONTROLLER ЗАПУЩЕНО ===")
    state = load_state()
    
    while True:
        try:
            current, details = get_system_score()
            baseline = state["baseline"]
            diff = current - baseline

            status_str = " | ".join(details) if details else "Всі системи в нормі"
            log(f"Стан: {current}% (База: {baseline}%) | Різниця: {diff:+.2f}% | {status_str}")

            # Правило -3% (Деградація та Відкат)
            if diff <= -3.0:
                rollback(state["baseline_commit"])
                state["history"].append({"time": str(datetime.now()), "event": "rollback", "from": current, "to": baseline, "reason": status_str})
                save_state(state)
                time.sleep(15) # Даємо час системі піднятися після відкату
                continue

            # Правило +3% (Автосейв та Новий Рівень)
            elif diff >= 3.0:
                new_commit = auto_save(current)
                state["baseline"] = current
                state["baseline_commit"] = new_commit
                state["history"].append({"time": str(datetime.now()), "event": "progress", "from": baseline, "to": current})
                save_state(state)

        except Exception as e:
            log(f"❌ ПОМИЛКА КОНТРОЛЕРА: {e}")
        
        time.sleep(60) # Перевірка щохвилини

if __name__ == "__main__":
    main()
