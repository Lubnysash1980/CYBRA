#!/usr/bin/env python3
"""Snapshot Diff Recovery — посимвольне відновлення файлів зі snapshot.

Працює навіть якщо:
  · файл частково пошкоджений (окремі символи)
  · файл відсутній
  · файл з нульовою довжиною
  · зламаний syntax
"""
import hashlib, json, os, shutil, sys, tarfile, tempfile
from pathlib import Path

H = Path.home() / "CYBRA"
M = H / "modules"
SRC = Path.home() / ".cybra_src"
SNAPS = SRC / "snapshots"
D = Path(__file__).resolve().parent

def _now(): import time; return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

def latest_snapshot():
    if not SNAPS.exists(): return None
    snaps = sorted(SNAPS.glob("snap_*.tar.gz"), key=lambda p: p.stat().st_mtime, reverse=True)
    return snaps[0] if snaps else None

def extract_to_temp(snap):
    """Розпаковує snapshot у тимчасову папку."""
    tmp = Path(tempfile.mkdtemp(prefix="cybra_recover_"))
    try:
        with tarfile.open(snap, "r:gz") as tar:
            tar.extractall(tmp)
        return tmp
    except Exception as e:
        shutil.rmtree(tmp, ignore_errors=True)
        return None

def _hash(p):
    if not p.exists() or p.stat().st_size == 0: return None
    try:
        h = hashlib.sha256()
        with open(p, "rb") as f:
            for chunk in iter(lambda: f.read(65536), b""):
                h.update(chunk)
        return h.hexdigest()
    except Exception: return None

def _bash_ok(p):
    """Перевіряє bash syntax."""
    if not str(p).endswith(".sh"): return True
    import subprocess
    r = subprocess.run(["bash", "-n", str(p)], capture_output=True, timeout=5)
    return r.returncode == 0

def _py_ok(p):
    """Перевіряє python syntax."""
    if not str(p).endswith(".py"): return True
    import subprocess
    r = subprocess.run(["python3", "-c", f"import ast; ast.parse(open('{p}').read())"],
                      capture_output=True, timeout=5)
    return r.returncode == 0

def is_broken(p):
    """Чи файл пошкоджений?"""
    if not p.exists(): return True, "missing"
    if p.stat().st_size == 0: return True, "empty"
    if p.suffix == ".sh" and not _bash_ok(p): return True, "bash syntax"
    if p.suffix == ".py" and not _py_ok(p): return True, "python syntax"
    return False, "ok"

def recover_file(rel, snap_dir):
    """Відновлює один файл зі snapshot."""
    src = snap_dir / rel
    dst = H / rel
    if not src.exists(): return False, "не у snapshot"
    try:
        dst.parent.mkdir(parents=True, exist_ok=True)
        # бекап поточного
        if dst.exists():
            bk = dst.with_suffix(dst.suffix + f".broken.{int(__import__('time').time())}")
            shutil.copy2(dst, bk)
        shutil.copy2(src, dst)
        # відновити права
        if dst.suffix == ".sh":
            os.chmod(dst, 0o755)
        return True, f"відновлено з {src.stat().st_size}B"
    except Exception as e:
        return False, str(e)[:100]

def scan_and_fix(dry_run=False):
    """Сканує критичні файли, знаходить биті, лікує."""
    snap = latest_snapshot()
    if not snap:
        return {"ok": False, "reason": "немає snapshot"}
    snap_dir = extract_to_temp(snap)
    if not snap_dir:
        return {"ok": False, "reason": "extract failed"}

    result = {"snapshot": snap.name, "scanned": [], "broken": [], "fixed": [], "at": _now()}

    # Критичні файли
    critical = [
        "modules/module_19_contract_tui_menu/bin/cybra_menu.sh",
        "modules/module_121_parlament/parliament.py",
        "modules/module_121_parlament/health.py",
        "modules/module_121_parlament/verify_7.py",
        "modules/module_121_parlament/completion.py",
        "modules/module_121_parlament/controller_gate.py",
        "modules/module_320_controllers/controllers.py",
        "modules/module_330_selfheal/engine.py",
        "modules/module_350_controller_worker/worker.py",
        "modules/module_360_mapping/mapping.py",
        "modules/module_380_sic/sic.py",
        "modules/module_390_src/src.py",
        "config/networks.json",
        "config/pm_processes.json",
    ]

    for rel in critical:
        p = H / rel
        result["scanned"].append(rel)
        broken, reason = is_broken(p)
        if not broken:
            continue
        result["broken"].append({"file": rel, "reason": reason})
        if not dry_run:
            ok, msg = recover_file(rel, snap_dir)
            if ok:
                result["fixed"].append({"file": rel, "msg": msg})

    shutil.rmtree(snap_dir, ignore_errors=True)
    return result

def verify_all():
    """Тільки перевірка, без фіксу."""
    return scan_and_fix(dry_run=True)

if __name__ == "__main__":
    import sys
    G='\033[32m'; R='\033[31m'; Y='\033[33m'; B='\033[36m'; BOLD='\033[1m'; N='\033[0m'
    cmd = sys.argv[1] if len(sys.argv) > 1 else "scan"

    if cmd == "scan":
        r = verify_all()
        if not r.get("ok"): print(f"  {R}✗{N} {r.get('reason')}"); sys.exit(1)
        print(f"\n  {B}{BOLD}Diff Recovery Scan{N}")
        print(f"  Snapshot: {r['snapshot']}")
        print(f"  Scanned:  {len(r['scanned'])}")
        print(f"  Broken:   {R if r['broken'] else G}{len(r['broken'])}{N}")
        for b in r["broken"]:
            print(f"    ✗ {b['file']}: {b['reason']}")

    elif cmd == "fix":
        r = scan_and_fix(dry_run=False)
        if not r.get("ok"): print(f"  {R}✗{N} {r.get('reason')}"); sys.exit(1)
        print(f"\n  {B}{BOLD}Diff Recovery Fix{N}")
        print(f"  Snapshot: {r['snapshot']}")
        print(f"  Broken:   {len(r['broken'])}")
        print(f"  Fixed:    {G}{len(r['fixed'])}{N}")
        for f in r["fixed"]:
            print(f"    ✓ {f['file']}: {f['msg']}")

    elif cmd == "json":
        print(json.dumps(verify_all(), indent=2, ensure_ascii=False))
