#!/usr/bin/env python3
"""Проста подієва система: реєстрація + виклик хуків.
Хуки підписуються на події: level_up, level_down, contract_closed,
deviation, executor_done, executor_fail."""
import json, os, time
from pathlib import Path

D = Path(__file__).resolve().parent
REG = D / "data" / "hooks" / "registry.jsonl"
REG.parent.mkdir(exist_ok=True)

EVENTS = [
    "level_up", "level_down", "contract_closed",
    "deviation", "executor_done", "executor_fail",
    "hook_error",
]

def register(event, handler, name, priority=50):
    """handler — рядок shell-команди або python-функція (якщо in-process)."""
    e = {"event": event, "handler": handler, "name": name,
         "priority": priority, "at": _now()}
    with open(REG, "a") as f: f.write(json.dumps(e, ensure_ascii=False) + "\n")
    return e

def registered(event=None):
    if not REG.exists(): return []
    out = []
    for line in REG.read_text().splitlines():
        try: e = json.loads(line)
        except Exception: continue
        if event and e.get("event") != event: continue
        out.append(e)
    out.sort(key=lambda x: -x.get("priority", 50))
    return out

def fire(event, **kwargs):
    """Виклик усіх хуків для події. Shell-handlers — subprocess, python — через import."""
    if not REG.exists(): return []
    results = []
    for h in registered(event):
        name = h.get("name","?")
        handler = h.get("handler")
        t0 = time.time()
        try:
            if callable(handler):
                r = handler(**kwargs)
                ok, msg = True, str(r)[:200]
            elif isinstance(handler, str):
                # shell-команда з env-контекстом
                import subprocess
                env = os.environ.copy()
                for k, v in kwargs.items():
                    env[f"CYBRA_{k.upper()}"] = json.dumps(v, ensure_ascii=False)
                env["CYBRA_EVENT"] = event
                r = subprocess.run(handler, shell=True, env=env,
                                   capture_output=True, text=True, timeout=60)
                ok = r.returncode == 0
                msg = (r.stdout + r.stderr)[:200]
            else:
                ok, msg = False, "невідомий тип handler"
        except Exception as ex:
            ok, msg = False, str(ex)[:200]
        results.append({
            "event": event, "name": name, "ok": ok, "msg": msg,
            "dur_ms": int((time.time()-t0)*1000),
        })
        if not ok:
            # рекурсивно захист: не стріляємо hook_error від hook_error
            if event != "hook_error":
                _safe_fire_error(event, name, msg)
    return results

def _safe_fire_error(event, name, msg):
    try:
        import stream
        stream.system("hook_error", {"event": event, "name": name, "msg": msg},
                      level="warn")
    except Exception: pass

def _now(): return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

# ── вбудовані хуки (default install) ────────────────────────
def install_defaults():
    """Реєструє базові хуки: alert при deviation, stream при level_up."""
    existing = {h["name"] for h in registered()}
    if "alert_deviation" not in existing:
        register("deviation",
                 "python3 $HOME/CYBRA/modules/module_121_parlament/alerts.py deviation "
                 "'Відхилення: $CYBRA_CID рівень $CYBRA_LEVEL' 'Перевищує поріг'",
                 "alert_deviation", priority=90)
    if "alert_close" not in existing:
        register("contract_closed",
                 "python3 $HOME/CYBRA/modules/module_121_parlament/alerts.py executed "
                 "'Контракт закрито' '$CYBRA_CID'",
                 "alert_close", priority=80)
    if "log_level_up" not in existing:
        register("level_up",
                 "python3 -c \"import sys,os;sys.path.insert(0,'$HOME/CYBRA/modules/module_121_parlament');"
                 "import stream;stream.system('level_up',dict(cid=os.environ.get('CYBRA_CID'),"
                 "level=os.environ.get('CYBRA_LEVEL')))\"",
                 "log_level_up", priority=10)

def list_hooks():
    for h in registered():
        print(f"  [{h.get('event'):16s}] {h.get('name'):24s} p={h.get('priority')}  "
              f"{(h.get('handler') or '')[:50]}")

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "list"
    if cmd == "list": list_hooks()
    elif cmd == "install": install_defaults(); print("✓ defaults installed")
    elif cmd == "fire":
        ev = sys.argv[2]
        print(json.dumps(fire(ev), indent=2, ensure_ascii=False))
