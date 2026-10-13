from pathlib import Path
from datetime import datetime
import shutil
import re
import sys
import py_compile

ROOT = Path.home() / "CYBRA"

health = ROOT / "modules/module_121_parlament/health.py"
controllers = ROOT / "modules/module_320_controllers/controllers.py"
engine = ROOT / "modules/module_330_selfheal/engine.py"

files = [health, controllers, engine]
original = {}

for p in files:
    if not p.is_file():
        print(f"FALSE: файл не знайдено: {p}")
        sys.exit(1)
    original[p] = p.read_text(encoding="utf-8")

# Підготовка всіх змін у пам'яті. На цьому етапі файли не змінюються.
h = original[health]
c = original[controllers]
e = original[engine]

# 1. Parliament health: не дублювати Self-Heal.
old_h = '''            elif c["id"] == "node_state":
                _run("cybra-pm restart autonode", timeout=30)
                actions.append(("node_state", "restart autonode"))
'''
new_h = '''            elif c["id"] == "node_state":
                # AutoNode recovery is centralized in module_330_selfheal.
                actions.append(("node_state", "recovery delegated to selfheal"))
'''
if old_h not in h:
    print("FALSE: health.py branch не збігається; жодних файлів не змінено.")
    sys.exit(2)
h = h.replace(old_h, new_h, 1)

# 2. Controller auto-heal: не запускати другий restart.
old_c = '''        elif cid == "node_state":
            rc, _ = _run("cybra-pm restart autonode", timeout=30)
            fixes.append(("node_state", rc == 0, "restart autonode"))
'''
new_c = '''        elif cid == "node_state":
            fixes.append((
                "node_state", False,
                "recovery delegated to module_330_selfheal"
            ))
'''
if old_c not in c:
    print("FALSE: controllers.py branch не збігається; жодних файлів не змінено.")
    sys.exit(3)
c = c.replace(old_c, new_c, 1)

# 3. Self-Heal: єдина точка відновлення, lock і перевірка всіх мереж.
marker = 'def heal(issue):'
if marker not in e:
    print("FALSE: engine.py def heal не знайдено; жодних файлів не змінено.")
    sys.exit(4)

if "_cybra_recover_autonode_once" in e:
    print("INFO: centralized recovery helper вже існує. Змін немає.")
    sys.exit(0)

helper = r'''
def _cybra_autonode_fully_healthy():
    """TRUE лише якщо JSON підтверджує state=ok та всі мережі online."""
    try:
        an = json.loads((H / "run/autonode.json").read_text(encoding="utf-8"))
        nets = an.get("networks", {})
        if isinstance(nets, dict):
            entries = list(nets.values())
        elif isinstance(nets, list):
            entries = nets
        else:
            entries = []

        return (
            an.get("state") == "ok"
            and bool(entries)
            and all(
                isinstance(v, dict) and v.get("state") == "ok"
                for v in entries
            )
        )
    except Exception:
        return False


def _cybra_recover_autonode_once():
    """
    Єдина точка відновлення AutoNode:
    - не перезапускає здоровий вузол;
    - не допускає паралельного відновлення;
    - обмежує повторні спроби;
    - перевіряє кінцевий стан.
    """
    import fcntl

    run_dir = H / "run"
    run_dir.mkdir(parents=True, exist_ok=True)
    lock_path = run_dir / "autonode_recovery.lock"
    cooldown_path = run_dir / "autonode_recovery.last"

    with open(lock_path, "a+", encoding="utf-8") as lock:
        try:
            fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return False, "recovery already running"

        # Перед будь-якою дією перевіряємо реальний стан мереж.
        if _cybra_autonode_fully_healthy():
            return True, "already healthy; restart skipped"

        # Не повторювати невдале відновлення кожні кілька секунд.
        try:
            last = float(cooldown_path.read_text(encoding="utf-8").strip())
            elapsed = time.time() - last
            if 0 <= elapsed < 120:
                return False, f"retry cooldown ({int(120-elapsed)}s remaining)"
        except Exception:
            pass

        # Фіксуємо спробу до виклику supervisor, щоб уникнути шторму.
        cooldown_path.write_text(str(time.time()), encoding="utf-8")

        rc, out = _run("cybra-pm restart autonode", timeout=45)

        # rc=0 не є доказом здоров'я. Чекаємо підтвердження всіх мереж.
        deadline = time.time() + 45
        while time.time() < deadline:
            if _cybra_autonode_fully_healthy():
                return True, "all networks verified healthy"
            time.sleep(2)

        return False, (
            f"verification timeout; command_rc={rc}; "
            f"output={str(out)[:160]}"
        )

'''

e = e.replace(marker, helper + "\n" + marker, 1)

old_controller = '''        if cid == "node_state":
            rc, out = _run("cybra-pm restart autonode", timeout=30)
            ok, msg = _wait_for_autonode(timeout=40)
            return ok, f"restart autonode: {msg}", out[:100]
'''
new_controller = '''        if cid == "node_state":
            ok, msg = _cybra_recover_autonode_once()
            return ok, f"autonode recovery: {msg}", msg[:100]
'''
if old_controller not in e:
    print("FALSE: engine.py controller branch не збігається; жодних файлів не змінено.")
    sys.exit(5)
e = e.replace(old_controller, new_controller, 1)

old_autonode = '''    if src == "autonode":
        rc, out = _run("cybra-pm restart autonode", timeout=30)
        ok, msg = _wait_for_autonode(timeout=40)
        if ok:
            return True, f"autonode: {msg}", "ok"
        return rc == 0, "autonode restarted", f"but {msg}"
'''
new_autonode = '''    if src == "autonode":
        ok, msg = _cybra_recover_autonode_once()
        return ok, f"autonode recovery: {msg}", msg[:100]
'''
if old_autonode not in e:
    print("FALSE: engine.py autonode branch не збігається; жодних файлів не змінено.")
    sys.exit(6)
e = e.replace(old_autonode, new_autonode, 1)

patched = {
    health: h,
    controllers: c,
    engine: e,
}

# Перевірити синтаксис кандидатів до запису у файли.
import tempfile
for p, content in patched.items():
    tmp = p.with_suffix(p.suffix + ".candidate")
    tmp.write_text(content, encoding="utf-8")
    try:
        py_compile.compile(str(tmp), doraise=True)
    except Exception as exc:
        tmp.unlink(missing_ok=True)
        print(f"FALSE: syntax candidate failed for {p.name}: {exc}")
        sys.exit(7)
    tmp.unlink(missing_ok=True)

# Резервні копії всіх трьох файлів.
stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
backups = {}
for p in files:
    b = p.with_name(p.name + ".bak.autonodefix." + stamp)
    shutil.copy2(p, b)
    backups[p] = b

# Запис із відкатом усіх файлів, якщо запис або перевірка не вдасться.
try:
    for p, content in patched.items():
        p.write_text(content, encoding="utf-8")

    for p in files:
        py_compile.compile(str(p), doraise=True)

except Exception as exc:
    for p in files:
        shutil.copy2(backups[p], p)
    print(f"FALSE: зміни скасовано, резервні копії відновлено: {exc}")
    sys.exit(8)

print("PATCH=APPLIED")
for p in files:
    print(f"BACKUP={backups[p]}")
print("PYTHON_SYNTAX=PASS")
print("AUTO_RESTART_DURING_PATCH=NO")
print("TRUE_100=NOT_YET_VERIFIED")
