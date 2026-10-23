#!/usr/bin/env python3
import os
from pathlib import Path

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"

def ensure_structure():
    dirs = [
        CYBRA / "data/fidic", CYBRA / "parliament_core/tasks", 
        CYBRA / "logs", CYBRA / "state", CYBRA / "sandbox"
    ]
    for d in dirs:
        d.mkdir(parents=True, exist_ok=True)
    
    # Створюємо файл цілі, якщо його немає
    goal = CYBRA / "cybra_goal.json"
    if not goal.exists():
        goal.write_text('{"ultimate_goal": "100% State", "status": "ACTIVE"}')
    print("✅ Автоконфіг: всі системні папки та файли на місці.")

if __name__ == "__main__":
    ensure_structure()
