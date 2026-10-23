#!/usr/bin/env python3
import os, time, json, random
from pathlib import Path
from datetime import datetime, timezone

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
GOAL_FILE = CYBRA / "cybra_goal.json"
EVO_STATE = CYBRA / "state" / "parliament_evolution.json"
LOG = CYBRA / "logs/parliament_evolver.log"

EVO_STATE.parent.mkdir(parents=True, exist_ok=True)
LOG.parent.mkdir(parents=True, exist_ok=True)

def log(msg):
    t = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    with open(LOG, "a") as f:
        f.write(f"[{t}] {msg}\n")

def load_state():
    if EVO_STATE.exists():
        try: return json.loads(EVO_STATE.read_text())
        except: pass
    # Починаємо з 1-го рівня складності
    return {"current_level": 1, "best_level": 1, "min_errors": 100.0, "history": []}

def save_state(state):
    EVO_STATE.write_text(json.dumps(state, indent=2))

def simulate_complexity_level(level):
    """
    Імітація перевірки рівня складності.
    У майбутньому тут буде реальна перевірка модулів, помилок PM2, логів тощо.
    Чим вищий рівень, тим більше навантаження, але й більше можливостей.
    """
    # Умовна формула: базові помилки - це 10%. Кожен рівень додає складності.
    # Але ми шукаємо "золоту середину" (мінімум помилок).
    base_error_rate = 15.0
    if level == 1: return base_error_rate - 5  # 10%
    if level == 2: return base_error_rate - 7  # 8%
    if level == 3: return base_error_rate - 9  # 6%
    if level == 4: return base_error_rate - 8  # 7% (почалися проблеми)
    if level == 5: return base_error_rate - 5  # 10%
    if level == 6: return base_error_rate       # 15%
    if level == 7: return base_error_rate + 5  # 20% (система перевантажена)
    return 100.0

def main():
    log("=== PARLIAMENT EVOLVER STARTED ===")
    state = load_state()
    
    while True:
        try:
            # Читаємо нашу глобальну ціль
            goal = json.loads(GOAL_FILE.read_text())
            if not goal.get("status") == "ACTIVE":
                time.sleep(60); continue

            current_lvl = state["current_level"]
            log(f"Аналіз рівня складності {current_lvl}/7...")
            
            # Тестуємо поточний рівень
            error_rate = simulate_complexity_level(current_lvl)
            log(f"Рівень {current_lvl}: Відсоток помилок = {error_rate:.2f}%")

            # Якщо це найкращий результат - фіксуємо його
            if error_rate < state["min_errors"]:
                state["min_errors"] = error_rate
                state["best_level"] = current_lvl
                log(f"🌟 Знайдено кращий рівень! Рівень {current_lvl} (Помилок: {error_rate}%)")
                state["history"].append({"time": str(datetime.now()), "level": current_lvl, "error_rate": error_rate})

            # Перехід на наступний рівень для тестування (1->2->3...->7->1)
            current_lvl += 1
            if current_lvl > 7: 
                current_lvl = 1 # Повертаємось до початку, якщо дійшли до 7
                log(f"Цикл завершено. Найкращий рівень: {state['best_level']} (Помилок: {state['min_errors']}%)")
                
            state["current_level"] = current_lvl
            save_state(state)

        except Exception as e:
            log(f"❌ EVOLVER ERROR: {e}")
        
        # Тестуємо новий рівень кожні 2 хвилини
        time.sleep(120)

if __name__ == "__main__":
    main()
