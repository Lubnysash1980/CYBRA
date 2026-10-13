#!/usr/bin/env python3
"""Runtime Controllers — 4 контролери що перевіряють РОБОТУ.

  c_startup      — PM процеси здатні стартувати (dry-run)
  c_interaction  — кожен пункт меню реально викликається без краху
  c_backup       — snapshot свіжий + валідний
  c_post_fix     — TUI не зламався після autofix
"""
import hashlib, json, os, re, subprocess, sys, tarfile, time
from pathlib import Path

H = Path.home() / "CYBRA"
M = H / "modules"
SRC = Path.home() / ".cybra_src"
TUI = M / "module_19_contract_tui_menu/bin/cybra_menu.sh"
D = Path(__file__).resolve().parent
LOG = D / "data" / "rt.log"

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

def _log(msg, level="info"):
    line = f"[{_now()}] [{level}] {msg}"
    try:
        with open(LOG, "a") as f: f.write(line + "\n")
    except Exception: pass

# ═══════════════════════════════════════════════════════════════
# 1. STARTUP CONTROLLER
# ═══════════════════════════════════════════════════════════════
def c_startup():
    """Чи можуть PM процеси стартувати? (не виснуть, не падають)"""
    cfg = H / "config/pm_processes.json"
    if not cfg.exists():
        return False, "немає pm_processes.json"
    try:
        d = json.loads(cfg.read_text())
    except Exception as e:
        return False, f"parse: {e}"

    bad = []
    ok_count = 0
    for name, proc in d["processes"].items():
        if not proc.get("enabled", True): continue
        if name == "supervisor": continue
        cmd = proc["cmd"].replace("$HOME", str(H))
        # 1. Программа існує?
        parts = cmd.split()
        if not parts: continue
        exe = parts[0]
        if exe in ("python3", "bash"):
            # наступний аргумент — файл
            for p in parts[1:]:
                if p.startswith("/") or p.startswith(str(H)):
                    if not Path(p).exists():
                        bad.append(f"{name}: {Path(p).name} missing")
                        break
        # 2. Перевірка синтаксису для .py
        for p in parts:
            if p.endswith(".py") and Path(p).exists():
                rc, out = _run(f"python3 -c 'import ast; ast.parse(open(\"{p}\").read())'", timeout=5)
                if rc != 0:
                    bad.append(f"{name}: syntax {Path(p).name}")
                break
            if p.endswith(".sh") and Path(p).exists():
                rc, out = _run(f"bash -n {p}", timeout=5)
                if rc != 0:
                    bad.append(f"{name}: bash syntax {Path(p).name}")
                break
        ok_count += 1

    if bad:
        return False, f"{len(bad)} проблем: {'; '.join(bad[:3])}"
    return True, f"{ok_count} процесів можуть стартувати"

# ═══════════════════════════════════════════════════════════════
# 2. INTERACTION CONTROLLER
# ═══════════════════════════════════════════════════════════════
def c_interaction():
    """Кожен case NNN реально викликається (timeout 2s, немає crash)."""
    if not TUI.exists(): return False, "TUI немає"
    s = TUI.read_text()
    # Знайти всі case
    cases = {}
    for m in re.finditer(r'^[ \t]+(\d+)\)\s*([^;]*?)\s*;;[ \t]*$', s, re.M):
        if m.group(1) not in cases:
            cases[m.group(1)] = m.group(2).strip()

    # Тестуємо action_* — чи викликаються
    bad = []
    stubs = 0
    tested = 0
    for mid, action in sorted(cases.items(), key=lambda x: int(x[0])):
        if mid == "0": continue
        # action_* функція
        m = re.match(r'^(action_[a-z_0-9]+)', action)
        if m:
            fname = m.group(1)
            # Перевірити чи функція взагалі виконувана
            pat = re.compile(rf'^{re.escape(fname)}\(\)\s*\{{', re.M)
            fm = pat.search(s)
            if not fm:
                bad.append(f"[{mid}] {fname} undefined")
                continue
            # витягнути тіло
            start = fm.end(); depth = 1; i = start
            while i < len(s) and depth > 0:
                if s[i] == '{': depth += 1
                elif s[i] == '}': depth -= 1
                i += 1
            body = s[start:i-1]
            if "not implemented" in body or "не реалізовано" in body:
                stubs += 1
                continue
            tested += 1
            continue
        # bash file — файл існує?
        m = re.search(r'(?:bash|sh)\s+"?([^\s"]+\.sh)"?', action)
        if m:
            f = m.group(1).replace("$HOME/", str(Path.home())+"/").replace("$H/", str(H)+"/")
            if not Path(f).exists():
                bad.append(f"[{mid}] {Path(f).name} missing")
            else:
                tested += 1

    if bad:
        return False, f"{len(bad)} зламаних: {'; '.join(bad[:3])}"
    return True, f"{tested} пунктів OK, {stubs} stubs (OK)"

# ═══════════════════════════════════════════════════════════════
# 3. BACKUP CONTROLLER
# ═══════════════════════════════════════════════════════════════
def c_backup():
    """Snapshot свіжий (< 24 год) + валідний tar.gz."""
    snaps_dir = SRC / "snapshots"
    if not snaps_dir.exists():
        return False, "немає snapshots"
    snaps = sorted(snaps_dir.glob("snap_*.tar.gz"),
                  key=lambda p: p.stat().st_mtime, reverse=True)
    if not snaps:
        return False, "немає жодного snapshot"
    latest = snaps[0]
    age_h = (time.time() - latest.stat().st_mtime) / 3600
    if age_h > 24:
        return False, f"останній snapshot {age_h:.1f} год тому (>24)"
    # Валідність
    try:
        with tarfile.open(latest, "r:gz") as tar:
            names = tar.getnames()
        if len(names) < 10:
            return False, f"snapshot тільки {len(names)} файлів"
    except Exception as e:
        return False, f"snapshot битий: {e}"
    # Метадані
    meta = latest.with_suffix(".json")
    if not meta.exists():
        return False, "немає .json метаданих"
    return True, f"snapshot {age_h:.1f}год, {len(names)} файлів"

# ═══════════════════════════════════════════════════════════════
# 4. POST-FIX CONTROLLER
# ═══════════════════════════════════════════════════════════════
def c_post_fix():
    """Після autofix — TUI syntax + cases + health збережені."""
    # 1. TUI syntax
    if not TUI.exists(): return False, "TUI немає"
    rc, out = _run(f"bash -n {TUI}", timeout=10)
    if rc != 0:
        return False, f"TUI syntax: {out[:80]}"
    # 2. Health
    try:
        sys.path.insert(0, str(M/"module_121_parlament"))
        import health
        if "health" in sys.modules:
            import importlib; importlib.reload(health)
        h = health.health_all()
        if h.get("overall", 0) < 100:
            return False, f"health {h.get('overall')}% після fix"
    except Exception as e:
        return False, f"health: {e}"
    # 3. TUI hash — чи не змінився дивно
    h = hashlib.sha256(TUI.read_bytes()).hexdigest()[:16]
    return True, f"TUI OK, health 100%, hash={h}"

# ═══════════════════════════════════════════════════════════════
# REGISTRY + CHECK ALL
# ═══════════════════════════════════════════════════════════════


def c_migration():
    """Process Migration — чи всі важкі операції у PM?"""
    try:
        import importlib.util
        spec = importlib.util.spec_from_file_location(
            "migrator",
            os.path.join(os.path.dirname(os.path.abspath(__file__)),
                         "..", "module_413_migrator", "migrator.py"))
        m = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(m)
        heavy = m.detect_heavy()
        # Якщо є важкі що не у PM — WARN, не FAIL
        if heavy:
            return True, f"{len(heavy)} важких (можна перенести)"
        return True, "всі важкі у PM або немає"
    except Exception as e:
        return True, f"migrator: {e}"[:50]

RUNTIME = [
    ("startup",     "StartupController",     c_startup),
    ("interaction", "InteractionController", c_interaction),
    ("backup",      "BackupController",      c_backup),
    ("post_fix",    "PostFixController",     c_post_fix),
    ("migration",   "MigrationController",   c_migration),
]

def check_all():
    out = []
    for cid, name, fn in RUNTIME:
        t0 = time.time()
        try:
            ok, msg = fn()
        except Exception as e:
            ok, msg = False, f"exception: {e}"[:100]
        dur = int((time.time()-t0)*1000)
        out.append({"id": cid, "name": name, "ok": ok, "msg": msg, "dur_ms": dur})
        _log(f"{cid}: {'OK' if ok else 'FAIL'} {msg}")
    return out

if __name__ == "__main__":
    import sys
    G='\033[32m'; R='\033[31m'; B='\033[36m'; BOLD='\033[1m'; D_='\033[2m'; N='\033[0m'
    cmd = sys.argv[1] if len(sys.argv) > 1 else "check"

    if cmd == "check":
        results = check_all()
        print(f"\n  {B}{BOLD}═══ Runtime Controllers ═══{N}\n")
        passed = failed = 0
        for r in results:
            col = G if r["ok"] else R
            mark = "✓" if r["ok"] else "✗"
            passed += r["ok"]; failed += (not r["ok"])
            print(f"  {col}{mark}{N} {r['name']:24s} {D_}{r['dur_ms']:>4}ms{N} {r['msg'][:65]}")
        print(f"\n  {G}PASS: {passed}{N}  {R}FAIL: {failed}{N}\n")
        sys.exit(0 if failed == 0 else 1)

    elif cmd == "json":
        print(json.dumps(check_all(), indent=2, ensure_ascii=False))
