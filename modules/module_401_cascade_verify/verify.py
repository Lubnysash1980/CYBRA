#!/usr/bin/env python3
"""Cascade Verifier — автоперевірка + тести каскаду snapshot/логи."""
import hashlib, json, os, subprocess, sys, tarfile, tempfile, time
from pathlib import Path

H = Path.home() / "CYBRA"
M = H / "modules"
SRC = Path.home() / ".cybra_src"
D = Path(__file__).resolve().parent
LOG = D / "data" / "verify.log"

def _now(): return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
def _log(msg, ok=True):
    line = f"[{_now()}] [{'OK' if ok else 'FAIL'}] {msg}"
    print(line, flush=True)
    try:
        with open(LOG, "a") as f: f.write(line + "\n")
    except Exception: pass

# ═══════════════════════════════════════════════════════════════
# ПРАВИЛА (те що має бути)
# ═══════════════════════════════════════════════════════════════
RULES = {
    "recent_max": 5,
    "hist_l1_max": 5,
    "hist_l2_max": 5,
    "hist_l3_max": 5,
    "hist_l4_max": 5,
    "log_rotate_threshold_mb": 1,
}

def check_cascade():
    """Перевіряє що каскад відповідає правилам."""
    issues = []
    dirs = {
        "recent": SRC / "snapshots",
        "hist_l1": SRC / "history_l1",
        "hist_l2": SRC / "history_l2",
        "hist_l3": SRC / "history_l3",
        "hist_l4": SRC / "history_l4",
    }
    stats = {}
    for name, d in dirs.items():
        if not d.exists(): d.mkdir(parents=True, exist_ok=True)
        files = list(d.glob("*.tar.gz"))
        stats[name] = len(files)
        limit = RULES.get(f"{name}_max", 5)
        if len(files) > limit:
            issues.append(f"{name}: {len(files)} > {limit}")

    return len(issues) == 0, stats, issues

# ═══════════════════════════════════════════════════════════════
# ТЕСТИ
# ═══════════════════════════════════════════════════════════════
def test_snapshot_valid():
    """Snapshot має бути валідним tar.gz і містити код."""
    snap_dir = SRC / "snapshots"
    snaps = sorted(snap_dir.glob("*.tar.gz"), key=lambda p: p.stat().st_mtime, reverse=True)
    if not snaps: return None, "немає snapshot"
    s = snaps[0]
    try:
        with tarfile.open(s, "r:gz") as tar:
            names = tar.getnames()
        has_modules = any("modules/" in n for n in names)
        has_config = any("config/" in n for n in names)
        return (has_modules and has_config), f"{len(names)} файлів, modules={has_modules}, config={has_config}"
    except Exception as e:
        return False, f"extract fail: {e}"

def test_sha_metadata():
    """Кожен snapshot має .json з sha."""
    snap_dir = SRC / "snapshots"
    snaps = list(snap_dir.glob("*.tar.gz"))
    if not snaps: return None, "немає"
    missing = 0
    bad_sha = 0
    for s in snaps:
        meta = s.with_suffix(".json")
        if not meta.exists(): missing += 1; continue
        try:
            d = json.loads(meta.read_text())
            actual = hashlib.sha256(s.read_bytes()).hexdigest()[:16]
            if actual != d.get("sha"): bad_sha += 1
        except Exception: bad_sha += 1
    ok = missing == 0 and bad_sha == 0
    return ok, f"meta missing={missing}, sha mismatch={bad_sha}"

def test_cascade_rules():
    """Каскад відповідає правилам."""
    ok, stats, issues = check_cascade()
    return ok, f"stats={stats} issues={issues}"

def test_hist_readable():
    """Історичні snapshot читаються."""
    hist = SRC / "history_l1"
    if not hist.exists(): return True, "L1 ще немає"
    files = list(hist.glob("*.tar.gz"))
    if not files: return True, "L1 пустий"
    bad = 0
    for f in files[:3]:
        try:
            with tarfile.open(f, "r:gz") as tar:
                tar.getnames()
        except Exception: bad += 1
    return bad == 0, f"check {min(3, len(files))} файлів, битих={bad}"

def test_log_archive():
    """Логи правильно архівуються."""
    arc = SRC / "logs_archive"
    if not arc.exists(): return True, "ще не активовано"
    l1 = list((arc/"L1").glob("*.tar.gz")) if (arc/"L1").exists() else []
    # лог обрізається
    logs = list((H/"logs").glob("*.log"))
    big = [f for f in logs if f.stat().st_size > 5_000_000]
    ok = len(big) == 0
    return ok, f"archives_L1={len(l1)}, big_logs={len(big)}"

def test_checkpoint():
    """Checkpoint валідний."""
    cp = SRC / "checkpoint.json"
    if not cp.exists(): return None, "немає checkpoint"
    try:
        d = json.loads(cp.read_text())
        snap = SRC / "snapshots" / d.get("snapshot", "")
        if not snap.exists():
            # шукаємо в історії
            for lvl in ["snapshots","history_l1","history_l2","history_l3","history_l4"]:
                p = SRC / lvl / d.get("snapshot","")
                if p.exists(): snap = p; break
        ok = snap.exists()
        return ok, f"snapshot={d.get('snapshot')} exists={snap.exists()} health={d.get('health')}%"
    except Exception as e:
        return False, str(e)[:80]

def run_all_tests():
    tests = [
        ("snapshot_valid",   test_snapshot_valid),
        ("sha_metadata",     test_sha_metadata),
        ("cascade_rules",    test_cascade_rules),
        ("hist_readable",    test_hist_readable),
        ("log_archive",      test_log_archive),
        ("checkpoint",       test_checkpoint),
    ]
    results = []
    for name, fn in tests:
        try:
            ok, msg = fn()
        except Exception as e:
            ok, msg = False, str(e)[:100]
        results.append({"test": name, "ok": ok, "msg": msg})
        _log(f"{name}: {msg}", ok if ok is not None else True)
    return results

# ═══════════════════════════════════════════════════════════════
# HASH — вписуємо cascade у hash ecosystem
# ═══════════════════════════════════════════════════════════════
def cascade_hash():
    """Хеш стану каскаду — для hash ecosystem."""
    dirs = {
        "recent": SRC / "snapshots",
        "l1": SRC / "history_l1",
        "l2": SRC / "history_l2",
        "l3": SRC / "history_l3",
        "l4": SRC / "history_l4",
    }
    data = {"at": _now()}
    for name, d in dirs.items():
        files = sorted(d.glob("*.tar.gz")) if d.exists() else []
        data[name] = [{"name": f.name, "sha": hashlib.sha256(f.read_bytes()).hexdigest()[:16]}
                     for f in files]
    # checkpoint
    cp = SRC / "checkpoint.json"
    if cp.exists():
        try:
            cd = json.loads(cp.read_text())
            data["checkpoint"] = {"snapshot": cd.get("snapshot"), "health": cd.get("health")}
        except Exception: pass
    h = hashlib.sha256(json.dumps(data, sort_keys=True).encode()).hexdigest()
    return h, data

# ═══════════════════════════════════════════════════════════════
# CLI
# ═══════════════════════════════════════════════════════════════
if __name__ == "__main__":
    import sys
    G='\033[32m'; R='\033[31m'; Y='\033[33m'; B='\033[36m'; BOLD='\033[1m'; N='\033[0m'
    cmd = sys.argv[1] if len(sys.argv) > 1 else "test"

    if cmd == "test":
        results = run_all_tests()
        print(f"\n  {B}{BOLD}Cascade Tests{N}\n")
        passed = 0; failed = 0; skipped = 0
        for r in results:
            if r["ok"] is None: mark = f"{Y}○{N}"; skipped += 1
            elif r["ok"]: mark = f"{G}✓{N}"; passed += 1
            else: mark = f"{R}✗{N}"; failed += 1
            print(f"  {mark} {r['test']:20s} {r['msg'][:60]}")
        print(f"\n  {G}PASS: {passed}{N}  {R}FAIL: {failed}{N}  {Y}SKIP: {skipped}{N}\n")
        sys.exit(0 if failed == 0 else 1)

    elif cmd == "check":
        ok, stats, issues = check_cascade()
        print(json.dumps({"ok": ok, "stats": stats, "issues": issues}, indent=2))

    elif cmd == "hash":
        h, data = cascade_hash()
        print(f"\n  Cascade hash: {h}\n")
        for k in ["recent","l1","l2","l3","l4"]:
            if k in data:
                print(f"  {k:8s} {len(data[k])} файлів")

    elif cmd == "json":
        results = run_all_tests()
        print(json.dumps(results, indent=2, ensure_ascii=False))
