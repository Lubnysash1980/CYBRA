#!/usr/bin/env python3
"""LevelController — 7 рівнів EVO. Кожен рівень підвищує автономію."""
import json, os, time
from pathlib import Path
H = Path.home() / "CYBRA"
D = Path(__file__).resolve().parent
STATE = D / "data" / "state.json"

LEVELS = {
    1: "Спостереження",
    2: "Аналіз",
    3: "Пропозиції",
    4: "Авто-фікси",
    5: "Авто-інсталяція",
    6: "Авто-деплой",
    7: "Повна автономія",
}

def load():
    if not STATE.exists(): return {"level": 1, "history": [], "unlocked": [1]}
    try: return json.loads(STATE.read_text())
    except Exception: return {"level": 1, "history": [], "unlocked": [1]}

def save(d): STATE.write_text(json.dumps(d, indent=2, ensure_ascii=False))

def current_level():
    return load().get("level", 1)

def try_advance():
    """Підвищити рівень якщо всі умови виконані."""
    d = load()
    lvl = d["level"]
    if lvl >= 7: return False, "max level"
    # умови для підвищення
    conditions = {
        2: lambda: True,   # завжди можна з 1→2
        3: lambda: True,
        4: lambda: _completion_100(),
        5: lambda: _controllers_ok(),
        6: lambda: _deployed_ok(),
        7: lambda: _parliament_ok(),
    }
    if lvl + 1 in conditions:
        try:
            if conditions[lvl+1]():
                d["level"] = lvl + 1
                d.setdefault("unlocked", []).append(lvl+1)
                d.setdefault("history", []).append({
                    "at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                    "from": lvl, "to": lvl+1
                })
                save(d)
                return True, f"advanced → L{lvl+1} ({LEVELS[lvl+1]})"
            return False, "conditions not met"
        except Exception as e:
            return False, str(e)[:80]
    return False, "no conditions"

def _completion_100():
    import subprocess
    r = subprocess.run(["python3", str(H/"modules/module_121_parlament/completion.py"), "score"],
                      capture_output=True, text=True, timeout=30)
    try:
        d = json.loads(r.stdout)
        return d.get("overall", 0) >= 100
    except Exception: return False

def _controllers_ok():
    try:
        import sys
        sys.path.insert(0, str(H/"modules/module_320_controllers"))
        import controllers
        return all(c["ok"] for c in controllers.check_all())
    except Exception: return False

def _deployed_ok():
    return (H/"config/deployed.json").exists()

def _parliament_ok():
    try:
        import sys
        sys.path.insert(0, str(H/"modules/module_121_parlament"))
        import parliament as P
        return sum(x["broken"] for x in P.verify_chain().values()) == 0
    except Exception: return False

if __name__ == "__main__":
    import sys
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "status":
        d = load()
        G='\033[32m'; Y='\033[33m'; D='\033[2m'; N='\033[0m'
        print(f"\n  LevelController — Level {d['level']}: {LEVELS[d['level']]}")
        print(f"  Unlocked: {d.get('unlocked', [1])}")
        print(f"\n  {'Рівень':<8} {'Назва':<25} {'Стан'}")
        for k, v in LEVELS.items():
            mark = f"{G}✓{N}" if k in d.get("unlocked", []) else f"{D}·{N}"
            print(f"  {mark} {k:<6} {v}")
        print()
    elif cmd == "advance":
        ok, msg = try_advance()
        print(("✓ " if ok else "· ") + msg)
    elif cmd == "level":
        print(current_level())
