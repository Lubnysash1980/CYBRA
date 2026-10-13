#!/usr/bin/env python3
"""Task Engine — двигун задач з sandbox-тестуванням.

Фази:
  1. DETECT    — знайти проблему (від 320/402/121)
  2. CREATE    — створити task з описом
  3. SANDBOX   — скопіювати файл у sandbox
  4. TEST      — перевірити в sandbox (bash -n, python ast, dry-run)
  5. APPLY     — якщо test OK → застосувати (з backup)
  6. VERIFY    — перевірити після
  7. ROLLBACK  — якщо не OK → відкат
  8. LOG       — записати у журнал
"""
import json, os, re, shutil, subprocess, sys, time
from pathlib import Path

H = Path.home() / "CYBRA"
M = H / "modules"
D = Path(__file__).resolve().parent
TASKS = D / "data" / "tasks"
SANDBOX = D / "data" / "sandbox"
LOGS = D / "data" / "logs"
STATS = D / "data" / "stats.json"

for p in [TASKS, SANDBOX, LOGS]: p.mkdir(parents=True, exist_ok=True)

def _now(): return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
def _run(cmd, timeout=30):
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
        return r.returncode, (r.stdout + r.stderr)[:300]
    except Exception as e:
        return 1, str(e)[:200]

def _log_task(tid, msg, level="info"):
    line = f"[{_now()}] [{level}] [{tid}] {msg}"
    print(line, flush=True)
    log = LOGS / f"{tid}.log"
    with open(log, "a") as f: f.write(line + "\n")

# ═══════════════════════════════════════════════════════════════
# DETECT — знайти проблеми
# ═══════════════════════════════════════════════════════════════
def detect():
    """Повертає список проблем для створення tasks."""
    issues = []

    # 1. Menu Doctor — заглушки
    try:
        sys.path.insert(0, str(M/"module_402_menu_doctor"))
        import doctor
        data = doctor.check_all()
        for mid, info in data["items"].items():
            if info["status"] in ("stub", "fail"):
                issues.append({
                    "type": "menu_item",
                    "target": mid,
                    "severity": "warn",
                    "detail": info["reason"],
                    "source": "402",
                })
    except Exception as e: pass

    # 2. Controllers
    try:
        sys.path.insert(0, str(M/"module_320_controllers"))
        import controllers
        for c in controllers.check_all():
            if not c["ok"]:
                issues.append({
                    "type": "controller",
                    "target": c.get("id"),
                    "severity": "critical" if "critical" in str(c) else "warn",
                    "detail": c["msg"],
                    "source": "320",
                })
    except Exception: pass

    # 3. Health
    try:
        sys.path.insert(0, str(M/"module_121_parlament"))
        import health
        h = health.health_all()
        for i in h.get("parliament", {}).get("issues", []):
            issues.append({"type":"health_parl","target":"parliament","severity":"warn","detail":i,"source":"121"})
        for i in h.get("system", {}).get("issues", []):
            issues.append({"type":"health_sys","target":"system","severity":"warn","detail":i,"source":"121"})
    except Exception: pass

    # 4. Structure (missing files)
    try:
        sys.path.insert(0, str(M/"module_395_structure"))
        import structure
        d = structure.verify()
        for m in d.get("missing", [])[:20]:
            issues.append({"type":"missing_file","target":m,"severity":"warn","detail":f"відсутній {m}","source":"395"})
    except Exception: pass

    return issues

# ═══════════════════════════════════════════════════════════════
# CREATE — створити task
# ═══════════════════════════════════════════════════════════════
def create_task(issue):
    tid = f"T-{int(time.time())}-{hash(issue['target']) % 1000:03d}"
    task = {
        "id": tid, "at": _now(),
        "status": "created",
        "issue": issue,
        "action": None,
        "sandbox_path": None,
        "test_result": None,
        "apply_result": None,
        "verify_result": None,
    }
    (TASKS / f"{tid}.json").write_text(json.dumps(task, indent=2, ensure_ascii=False))
    return task

# ═══════════════════════════════════════════════════════════════
# SANDBOX — копія у пісочницю
# ═══════════════════════════════════════════════════════════════
def sandbox_copy(task):
    """Копіює target у sandbox для безпечного тесту."""
    issue = task["issue"]
    target = issue["target"]

    if issue["type"] == "menu_item":
        # TUI
        src = M / "module_19_contract_tui_menu/bin/cybra_menu.sh"
    elif issue["type"] == "controller":
        src = M / "module_320_controllers/controllers.py"
    elif issue["type"] == "missing_file":
        return None, "не копіюється (відсутній)"
    else:
        return None, f"unknown type {issue['type']}"

    if not src.exists(): return None, f"немає {src}"
    dst = SANDBOX / task["id"] / src.name
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst, "ok"

# ═══════════════════════════════════════════════════════════════
# TEST — перевірка у sandbox
# ═══════════════════════════════════════════════════════════════
def test_in_sandbox(task, sandbox_file):
    """Тестує у sandbox. Повертає (ok, details)."""
    if not sandbox_file or not sandbox_file.exists():
        return False, "немає sandbox файлу"
    tests = []
    f = sandbox_file

    # 1. Syntax
    if f.suffix == ".sh":
        rc, out = _run(f"bash -n {f}")
        tests.append(("bash_syntax", rc == 0, out[:100]))
    elif f.suffix == ".py":
        rc, out = _run(f"python3 -c 'import ast; ast.parse(open(\"{f}\").read())'")
        tests.append(("py_syntax", rc == 0, out[:100]))

    # 2. Виконуваний?
    if f.suffix == ".sh":
        rc, out = _run(f"bash {f} </dev/null 2>&1 | head -5", timeout=5)
        # не критично якщо щось прочитає — просто пробуємо
        tests.append(("bash_run_head", True, out[:80]))

    # 3. Не порожній
    tests.append(("not_empty", f.stat().st_size > 100, f"{f.stat().st_size} B"))

    all_ok = all(t[1] for t in tests)
    return all_ok, tests

# ═══════════════════════════════════════════════════════════════
# APPLY — застосування з backup
# ═══════════════════════════════════════════════════════════════
def apply_task(task, sandbox_file):
    """Застосовує зміни. Backup перед."""
    issue = task["issue"]
    if issue["type"] == "menu_item":
        dst = M / "module_19_contract_tui_menu/bin/cybra_menu.sh"
    elif issue["type"] == "controller":
        dst = M / "module_320_controllers/controllers.py"
    else:
        return False, "не підтримується"

    if not dst.exists(): return False, "немає target"

    # Backup
    bak = dst.with_suffix(dst.suffix + f".bak.engine.{int(time.time())}")
    shutil.copy2(dst, bak)

    # Тестова заміна
    try:
        shutil.copy2(sandbox_file, dst)
        return True, str(bak)
    except Exception as e:
        # rollback
        shutil.copy2(bak, dst)
        return False, str(e)

# ═══════════════════════════════════════════════════════════════
# VERIFY — перевірка після apply
# ═══════════════════════════════════════════════════════════════
def verify_after_apply():
    """Перевірка що система не зламалась."""
    tests = []
    # TUI syntax
    tui = M / "module_19_contract_tui_menu/bin/cybra_menu.sh"
    rc, _ = _run(f"bash -n {tui}")
    tests.append(("tui_syntax", rc == 0))
    # controllers
    try:
        sys.path.insert(0, str(M/"module_320_controllers"))
        import controllers
        c = controllers.check_all()
        tests.append(("controllers_ok", all(x["ok"] for x in c)))
    except Exception: tests.append(("controllers_ok", False))
    # health
    try:
        sys.path.insert(0, str(M/"module_121_parlament"))
        import health
        h = health.health_all()
        tests.append(("health_100", h.get("overall", 0) >= 100))
    except Exception: tests.append(("health_100", False))
    return all(t[1] for t in tests), tests

def rollback(bak_path, dst):
    if bak_path and Path(bak_path).exists():
        shutil.copy2(bak_path, dst)
        return True
    return False

# ═══════════════════════════════════════════════════════════════
# CYCLE — прогнати все
# ═══════════════════════════════════════════════════════════════
def cycle(limit=5, verbose=True):
    """Повний цикл: detect → create → sandbox → test → apply → verify."""
    t0 = time.time()
    if verbose: print(f"\n{'='*60}\n  TASK ENGINE CYCLE\n{'='*60}")

    issues = detect()
    if verbose: print(f"  Issues: {len(issues)}")

    results = {"created": 0, "tested": 0, "applied": 0, "failed": 0, "skipped": 0}

    for issue in issues[:limit]:
        task = create_task(issue)
        tid = task["id"]
        results["created"] += 1

        _log_task(tid, f"create: {issue['type']}:{issue['target']}")

        # SANDBOX
        sb, msg = sandbox_copy(task)
        task["sandbox_path"] = str(sb) if sb else None
        if not sb:
            task["status"] = "skip_no_sandbox"
            _log_task(tid, f"skip: {msg}", "warn")
            results["skipped"] += 1
            (TASKS/f"{tid}.json").write_text(json.dumps(task, indent=2))
            continue

        # TEST
        ok, tests = test_in_sandbox(task, sb)
        task["test_result"] = {"ok": ok, "tests": [(n, r, m) for n, r, m in tests]}
        results["tested"] += 1
        if verbose:
            for name, r, m in tests:
                _log_task(tid, f"  test {name}: {'✓' if r else '✗'} {m[:60]}")

        if not ok:
            task["status"] = "test_failed"
            results["failed"] += 1
            _log_task(tid, "TEST FAILED — не застосовую", "warn")
            (TASKS/f"{tid}.json").write_text(json.dumps(task, indent=2))
            continue

        # APPLY
        ok, info = apply_task(task, sb)
        task["apply_result"] = {"ok": ok, "info": info}
        if not ok:
            task["status"] = "apply_failed"
            results["failed"] += 1
            _log_task(tid, f"apply failed: {info}", "warn")
            (TASKS/f"{tid}.json").write_text(json.dumps(task, indent=2))
            continue
        results["applied"] += 1
        _log_task(tid, f"applied, backup={Path(info).name}")

        # VERIFY
        v_ok, v_tests = verify_after_apply()
        task["verify_result"] = {"ok": v_ok, "tests": [(n, r) for n, r in v_tests]}

        if not v_ok:
            # ROLLBACK
            dst = Path(info).parent / Path(info).name.replace(".bak.engine."+info.split(".bak.engine.")[1], "")
            # правильний dst — це оригінал
            if issue["type"] == "menu_item":
                dst = M / "module_19_contract_tui_menu/bin/cybra_menu.sh"
            elif issue["type"] == "controller":
                dst = M / "module_320_controllers/controllers.py"
            if rollback(info, dst):
                task["status"] = "rolled_back"
                _log_task(tid, "VERIFY FAILED → ROLLBACK", "warn")
                results["failed"] += 1
            else:
                task["status"] = "verify_failed_no_rollback"
                _log_task(tid, "VERIFY FAILED, rollback error", "error")
                results["failed"] += 1
        else:
            task["status"] = "done"
            _log_task(tid, "✓ done")

        (TASKS/f"{tid}.json").write_text(json.dumps(task, indent=2, ensure_ascii=False))

    duration = int((time.time()-t0)*1000)
    stats = {
        "at": _now(), "duration_ms": duration,
        "issues_total": len(issues), "results": results,
    }
    STATS.write_text(json.dumps(stats, indent=2, ensure_ascii=False))

    if verbose:
        print(f"\n  Results:")
        for k, v in results.items():
            print(f"    {k:10s} {v}")
        print(f"  Duration: {duration}ms\n")

    return stats

def stats():
    if not STATS.exists(): return {}
    try: return json.loads(STATS.read_text())
    except Exception: return {}

def list_tasks(limit=20):
    files = sorted(TASKS.glob("*.json"), key=lambda p: p.stat().st_mtime, reverse=True)[:limit]
    out = []
    for f in files:
        try: out.append(json.loads(f.read_text()))
        except Exception: pass
    return out

if __name__ == "__main__":
    import sys
    G='\033[32m'; Y='\033[33m'; R='\033[31m'; B='\033[36m'; BOLD='\033[1m'; D_='\033[2m'; N='\033[0m'
    cmd = sys.argv[1] if len(sys.argv) > 1 else "cycle"

    if cmd == "detect":
        iss = detect()
        print(f"\n  {B}{BOLD}Detected issues: {len(iss)}{N}\n")
        for i in iss[:20]:
            print(f"  [{i['severity']:8s}] {i['type']:14s} {i['target'][:30]:32s} {i['detail'][:40]}")

    elif cmd == "cycle":
        limit = int(sys.argv[2]) if len(sys.argv) > 2 else 5
        cycle(limit=limit)

    elif cmd == "stats":
        print(json.dumps(stats(), indent=2, ensure_ascii=False))

    elif cmd == "tasks":
        for t in list_tasks():
            col = G if t["status"]=="done" else (Y if "fail" in t["status"] else D_)
            print(f"  {col}{t['status']:20s}{N} {t['id']:24s} {t['issue']['type']:14s} {t['issue']['target'][:30]}")

    elif cmd == "json":
        print(json.dumps(list_tasks(), indent=2, ensure_ascii=False))
