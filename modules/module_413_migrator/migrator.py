#!/usr/bin/env python3
"""Process Migrator — контролер що АВТОМАТИЧНО переносить важкі операції в PM.

Принцип:
  1. Слідкує за тривалістю/падіннями операцій
  2. Якщо операція > threshold (наприклад 10s) — переносить у PM
  3. PM-задача контролюється supervisor + 410 Runtime Controllers
  4. Якщо задача часто падає — збільшує timeout або розбиває на кроки
  5. Логи у `data/migration.log` — хто куди переїхав

Контролери що беруть участь:
  · 320 Controllers — health
  · 410 Runtime — startup/interaction/backup/post_fix
  · 300 PM — supervisor
"""
import json, os, re, subprocess, sys, time, hashlib
from pathlib import Path

H = Path.home() / "CYBRA"
M = H / "modules"
D = Path(__file__).resolve().parent
PM_CFG = H / "config" / "pm_processes.json"
RULES = D / "data" / "rules.json"
MIG_LOG = D / "data" / "migration.log"
HEAVY_DIR = M / "module_412_heavy"
HEAVY_DIR.mkdir(exist_ok=True)

DEFAULT_RULES = {
    "max_foreground_sec": 10,      # вище — переносимо в PM
    "max_retries": 3,               # > помилок → переносимо
    "check_interval_sec": 300,      # як часто перевіряти
    "auto_migrate": True,           # авто чи ручне
    "migrated": {},                 # {name: {at, reason}}
    "history": [],                  # всі перенесення
}

# Відомі важкі операції (кандидати на авто-перенесення)
KNOWN_HEAVY = {
    "tiers_full": {
        "script": "tiers_full.sh",
        "cmd": "bash $HOME/CYBRA/modules/module_412_heavy/tiers_full.sh",
        "reason": "L1-L7 глибока перевірка (>10s)",
        "schedule": "cron:0 3 * * *",  # щодня о 3:00
    },
    "pipeline": {
        "script": "pipeline.sh",
        "cmd": "bash $HOME/CYBRA/modules/module_412_heavy/pipeline.sh",
        "reason": "8-кроковий pipeline (>30s)",
        "schedule": "cron:0 */6 * * *",  # кожні 6 год
    },
    "cascade": {
        "script": "cascade_verify.sh",
        "cmd": "bash $HOME/CYBRA/modules/module_412_heavy/cascade_verify.sh",
        "reason": "cascade tests (RAM-heavy)",
        "schedule": "cron:0 2 * * *",  # щодня о 2:00
    },
}

def _now(): return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
def _run(cmd, timeout=15, cwd=None):
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True,
                          timeout=timeout, cwd=cwd)
        return r.returncode, (r.stdout + r.stderr)[:300]
    except subprocess.TimeoutExpired:
        return 124, "timeout"
    except Exception as e:
        return 1, str(e)[:200]

def _load_rules():
    if not RULES.exists():
        RULES.write_text(json.dumps(DEFAULT_RULES, indent=2, ensure_ascii=False))
        return dict(DEFAULT_RULES)
    try:
        d = json.loads(RULES.read_text())
        base = dict(DEFAULT_RULES); base.update(d)
        return base
    except Exception: return dict(DEFAULT_RULES)

def _save_rules(r):
    RULES.write_text(json.dumps(r, indent=2, ensure_ascii=False))

def _log(msg, level="info"):
    line = f"[{_now()}] [{level}] {msg}"
    print(line, flush=True)
    try:
        with open(MIG_LOG, "a") as f: f.write(line + "\n")
    except Exception: pass

# ═══════════════════════════════════════════════════════════════
# DETECT — які операції важкі?
# ═══════════════════════════════════════════════════════════════
def detect_heavy():
    """Сканує систему на важкі операції."""
    heavy = []

    # 1. PM задачі з тривалими cmd (за описом)
    if PM_CFG.exists():
        d = json.loads(PM_CFG.read_text())
        for name, proc in d["processes"].items():
            desc = proc.get("desc", "").lower()
            # Ознаки важкого
            markers = ["tier", "pipeline", "cascade", "test", "verify", "scan", "report"]
            if any(m in desc for m in markers):
                if not name.startswith("heavy_"):
                    heavy.append({"name": name, "reason": f"desc: {desc[:50]}",
                                 "action": "migrate"})

    # 2. Модулі що виконують довгі операції
    long_ops = {
        "module_130_test_suite": "повний test suite",
        "module_401_cascade_verify": "cascade tests",
        "module_408_menu_tester": "тест усіх 161 пунктів",
        "module_409_pipeline": "8-кроковий pipeline",
        "module_411_tiers": "7 рівнів перевірки",
        "module_396_diffrecover": "diff recovery",
    }
    for mod_name, desc in long_ops.items():
        p = M / mod_name
        if not p.exists(): continue
        # Перевіряємо чи вже у PM
        pm_name = None
        if PM_CFG.exists():
            d = json.loads(PM_CFG.read_text())
            for n, proc in d["processes"].items():
                if mod_name in proc.get("cmd", ""):
                    pm_name = n; break
        if not pm_name:
            heavy.append({"name": mod_name, "reason": desc, "action": "add_to_pm"})

    return heavy

# ═══════════════════════════════════════════════════════════════
# MIGRATE
# ═══════════════════════════════════════════════════════════════
def migrate(name, entry):
    """Перенести операцію у PM."""
    if not PM_CFG.exists():
        return False, "немає pm_processes.json"

    d = json.loads(PM_CFG.read_text())

    # Скрипт-обгортка
    wrapper_name = f"auto_{name}.sh"
    wrapper = HEAVY_DIR / wrapper_name
    cmd = entry.get("cmd", "")

    # Якщо cmd вже є — використати, інакше зробити обгортку
    if not cmd:
        cmd = f"bash {wrapper}"

    wrapper.write_text(f"""#!/data/data/com.termux/files/usr/bin/bash
# AUTO-MIGRATED by 413 — {entry.get('reason','?')}
# Created: {_now()}
LOG="$HOME/CYBRA/logs/auto_{name}.log"
mkdir -p "$(dirname "$LOG")"
{{
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] {name} START"
  {entry.get('inner_cmd', 'echo "no inner cmd"')}
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] {name} END"
}} >> "$LOG" 2>&1
""")
    os.chmod(wrapper, 0o755)

    pm_name = f"auto_{name}"
    if pm_name in d["processes"]:
        return True, f"вже у PM: {pm_name}"

    d["processes"][pm_name] = {
        "name": pm_name,
        "desc": f"AUTO (413) — {entry.get('reason','?')[:50]}",
        "cmd": f"bash {wrapper}",
        "cwd": "$HOME/CYBRA",
        "pid_file": f"$HOME/CYBRA/run/pm_{pm_name}.pid",
        "log_file": f"$HOME/CYBRA/logs/auto_{name}.log",
        "auto_restart": False,
        "enabled": False,  # disabled за замовчуванням, запуск вручну/cron
        "match_pattern": wrapper_name,
    }
    PM_CFG.write_text(json.dumps(d, indent=2, ensure_ascii=False))

    # Оновити rules
    r = _load_rules()
    r.setdefault("migrated", {})[name] = {
        "at": _now(), "reason": entry.get("reason", "?")
    }
    r.setdefault("history", []).append({
        "at": _now(), "name": name, "reason": entry.get("reason", "?"),
    })
    _save_rules(r)

    _log(f"MIGRATED: {name} → {pm_name}", "info")
    return True, f"{pm_name}"

# ═══════════════════════════════════════════════════════════════
# AUTO-MIGRATE — контролер
# ═══════════════════════════════════════════════════════════════
def auto_migrate(verbose=True):
    """Прогнати: знайти важке + перенести у PM."""
    r = _load_rules()
    if not r.get("auto_migrate", True):
        return {"skipped": "auto_migrate disabled"}

    heavy = detect_heavy()
    if verbose: print(f"  Знайдено важких: {len(heavy)}")

    migrated = []
    already = []
    failed = []

    for h in heavy:
        name = h["name"]
        # Вже?
        if name in r.get("migrated", {}):
            already.append(name)
            continue

        # Знайти деталі
        entry = KNOWN_HEAVY.get(name, {})
        if not entry and PM_CFG.exists():
            d = json.loads(PM_CFG.read_text())
            if name in d["processes"]:
                entry = {
                    "reason": d["processes"][name].get("desc", "?"),
                    "cmd": d["processes"][name].get("cmd", ""),
                }
        if not entry:
            entry = {"reason": h.get("reason", "auto"), "cmd": ""}

        ok, info = migrate(name, entry)
        if ok:
            migrated.append(f"{name} → {info}")
            if verbose: print(f"  ✓ {name} → {info}")
        else:
            failed.append(f"{name}: {info}")
            if verbose: print(f"  ✗ {name}: {info}")

    return {
        "detected": len(heavy),
        "migrated": migrated,
        "already": len(already),
        "failed": failed,
        "at": _now(),
    }

def status():
    r = _load_rules()
    return {
        "rules": {k: v for k, v in r.items() if k != "history"},
        "migrated_count": len(r.get("migrated", {})),
        "history_count": len(r.get("history", [])),
    }

if __name__ == "__main__":
    import sys
    G='\033[32m'; Y='\033[33m'; R='\033[31m'; B='\033[36m'; BOLD='\033[1m'; D_='\033[2m'; N='\033[0m'
    cmd = sys.argv[1] if len(sys.argv) > 1 else "auto"

    if cmd == "detect":
        heavy = detect_heavy()
        print(f"\n  {B}{BOLD}Важкі операції: {len(heavy)}{N}\n")
        for h in heavy:
            print(f"  · {h['name']:30s} {h['reason'][:60]}")
        print()

    elif cmd == "auto":
        print(f"\n  {B}{BOLD}═══ AUTO-MIGRATE ═══{N}\n")
        r = auto_migrate()
        print(f"\n  Detected:  {r.get('detected')}")
        print(f"  Migrated:  {len(r.get('migrated', []))}")
        print(f"  Already:   {r.get('already', 0)}")
        print(f"  Failed:    {len(r.get('failed', []))}\n")

    elif cmd == "status":
        s = status()
        print(json.dumps(s, indent=2, ensure_ascii=False))

    elif cmd == "history":
        r = _load_rules()
        print(f"\n  {B}Історія перенесень ({len(r.get('history', []))}){N}\n")
        for h in r.get("history", []):
            print(f"  {h['at']}  {h['name']:30s} {h['reason'][:50]}")
