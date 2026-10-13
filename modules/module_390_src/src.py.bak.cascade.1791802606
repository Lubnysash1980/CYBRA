#!/usr/bin/env python3
"""Self-Recovery Controller (SRC) — тримає систему на 100% і відновлює з нуля.

Рівні:
  1. Snapshot     — кожної години знімок коду+конфігів у ~/.cybra_src/
  2. Checkpoint   — фіксація known-good state (health=100)
  3. Recovery     — якщо health<100 → відкат до checkpoint
  4. Resurrect    — якщо CYBRA зникла → відновлення з snapshot/git
  5. Watchdog     — daemon який все це крутить

Принципи:
  · Snapshot ПОЗА CYBRA (~/.cybra_src/) — переживає видалення
  · Не включає data/, logs/, backups/ — тільки код+конфіги
  · Atomic — через .tmp і os.replace
  · Verify — SHA256 кожного snapshot
"""
import hashlib, json, os, shutil, subprocess, sys, tarfile, time, signal
from pathlib import Path

H = Path.home() / "CYBRA"
M = H / "modules"
SRC_DIR = Path.home() / ".cybra_src"
SNAPS = SRC_DIR / "snapshots"
CHECKPOINT = SRC_DIR / "checkpoint.json"
LOG = SRC_DIR / "logs" / "src.log"
REMOTE = SRC_DIR / "remote.txt"

SNAPS.mkdir(parents=True, exist_ok=True)
(SRC_DIR / "logs").mkdir(parents=True, exist_ok=True)

RUN = True
def stop(*a):
    global RUN; RUN = False
    _log("stop")
signal.signal(signal.SIGTERM, stop)
signal.signal(signal.SIGINT, stop)

def _now(): return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
def _log(msg, level="info"):
    line = f"[{_now()}] [{level}] {msg}"
    print(line, flush=True)
    try:
        with open(LOG, "a") as f: f.write(line + "\n")
        if LOG.stat().st_size > 500_000:
            lines = LOG.read_text().splitlines()
            LOG.write_text("\n".join(lines[-500:]) + "\n")
    except Exception: pass

def _run(cmd, timeout=60):
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
        return r.returncode, (r.stdout + r.stderr).strip()[:300]
    except Exception as e:
        return 1, str(e)[:200]

# ═══════════════════════════════════════════════════════════════
# 1. SNAPSHOT
# ═══════════════════════════════════════════════════════════════
def make_snapshot(tag="auto"):
    """Створює tar.gz з коду+конфігів (без data/logs/backups)."""
    ts = time.strftime("%Y%m%d_%H%M%S")
    out = SNAPS / f"snap_{ts}_{tag}.tar.gz"
    tmp = out.with_suffix(".tar.gz.tmp")

    def filter_fn(tarinfo):
        """Виключення."""
        path = tarinfo.name
        # виключити великі/тимчасові
        skip_patterns = [
            "/data/", "/logs/", "/backups/", "/run/", "/__pycache__/",
            ".pyc", ".log", ".tmp", ".key", "/.git/", "/node_modules/",
            "/artifacts/", ".jsonl", ".pid", "/snapshots/",
        ]
        for p in skip_patterns:
            if p in path: return None
        # обмежити розмір одного файла до 1MB
        if tarinfo.size > 1024 * 1024: return None
        return tarinfo

    try:
        with tarfile.open(tmp, "w:gz", compresslevel=6) as tar:
            # модулі (код)
            if M.exists():
                for item in M.rglob("*"):
                    if item.is_file():
                        try:
                            rel = item.relative_to(H)
                            # фільтр
                            rs = str(rel)
                            if any(p in rs for p in ["/data/","/logs/","/backups/","/run/",
                                                     "__pycache__",".pyc",".log",".tmp",
                                                     ".key",".jsonl",".pid"]):
                                continue
                            if item.stat().st_size > 1024 * 1024: continue
                            tar.add(item, arcname=str(rel))
                        except Exception: pass
            # config
            cfg = H / "config"
            if cfg.exists():
                for item in cfg.rglob("*"):
                    if item.is_file() and item.stat().st_size < 1024 * 100:
                        try: tar.add(item, arcname=str(item.relative_to(H)))
                        except Exception: pass
            # bin
            b = H / "bin"
            if b.exists():
                for item in b.rglob("*"):
                    if item.is_file() and item.stat().st_size < 1024 * 1024:
                        try: tar.add(item, arcname=str(item.relative_to(H)))
                        except Exception: pass
            # .cybra_src (seed)
            seed = SRC_DIR / "bootstrap_seed.sh"
            if seed.exists(): tar.add(seed, arcname=".cybra_src/bootstrap_seed.sh")

        os.replace(tmp, out)
        size = out.stat().st_size
        # SHA256
        sha = hashlib.sha256(out.read_bytes()).hexdigest()[:16]
        # метадані
        out.with_suffix(".json").write_text(json.dumps({
            "file": out.name, "size": size, "sha": sha,
            "at": _now(), "tag": tag,
        }, indent=2))
        _log(f"snapshot: {out.name} ({size//1024}KB, sha={sha})")

        # ротація — останні 48 snapshot (2 доби при щогодині)
        all_snaps = sorted(SNAPS.glob("snap_*.tar.gz"), key=lambda p: p.stat().st_mtime, reverse=True)
        for old in all_snaps[48:]:
            old.unlink()
            old.with_suffix(".json").unlink(missing_ok=True)

        return str(out), size, sha
    except Exception as e:
        _log(f"snapshot error: {e}", level="error")
        return None, 0, None

# ═══════════════════════════════════════════════════════════════
# 2. CHECKPOINT
# ═══════════════════════════════════════════════════════════════
def health_ok():
    try:
        sys.path.insert(0, str(M/"module_121_parlament"))
        import health
        h = health.health_all()
        return h.get("overall", 0) >= 100, h
    except Exception as e:
        return False, {"error": str(e)[:100]}

def set_checkpoint():
    """Фіксує поточний стан як known-good."""
    ok, h = health_ok()
    if not ok:
        return False, f"health {h.get('overall',0)}% < 100"
    snap = sorted(SNAPS.glob("snap_*.tar.gz"), key=lambda p: p.stat().st_mtime, reverse=True)
    if not snap:
        return False, "немає snapshot"
    cp = {
        "at": _now(),
        "snapshot": snap[0].name,
        "health": h.get("overall", 100),
        "modules_count": len(list(M.glob("module_*"))),
    }
    tmp = CHECKPOINT.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(cp, indent=2))
    os.replace(tmp, CHECKPOINT)
    _log(f"checkpoint: {cp['snapshot']} (health={cp['health']}%)")
    return True, cp

def load_checkpoint():
    if not CHECKPOINT.exists(): return None
    try: return json.loads(CHECKPOINT.read_text())
    except Exception: return None

# ═══════════════════════════════════════════════════════════════
# 3. RECOVERY
# ═══════════════════════════════════════════════════════════════
def recover_from_snapshot(snap_name):
    """Відновлює тільки КОД модулів зі snapshot, не чіпаючи data/."""
    snap = SNAPS / snap_name
    if not snap.exists():
        return False, f"немає {snap_name}"
    _log(f"recover: {snap_name}", level="warn")
    # бекап поточного (щоб можна було відкотити)
    bk = SRC_DIR / "recovery_backup"
    bk.mkdir(exist_ok=True)
    ts = time.strftime("%Y%m%d_%H%M%S")
    # Розпаковуємо у тимчасову папку і копіюємо тільки missing/broken файли
    tmp = SRC_DIR / "tmp_recover"
    if tmp.exists(): shutil.rmtree(tmp)
    tmp.mkdir()
    try:
        with tarfile.open(snap, "r:gz") as tar:
            tar.extractall(tmp)
    except Exception as e:
        return False, f"extract: {e}"
    # Копіюємо тільки файли які відсутні або менші за розміром (можливе пошкодження)
    fixed = 0
    for root, dirs, files in os.walk(tmp):
        for f in files:
            src_f = Path(root) / f
            rel = src_f.relative_to(tmp)
            dst_f = H / rel
            if not dst_f.exists() or dst_f.stat().st_size == 0:
                try:
                    dst_f.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(src_f, dst_f)
                    os.chmod(dst_f, 0o755) if dst_f.suffix == ".sh" else None
                    fixed += 1
                except Exception: pass
    shutil.rmtree(tmp, ignore_errors=True)
    _log(f"recover: відновлено {fixed} файлів", level="info")
    return True, fixed

# ═══════════════════════════════════════════════════════════════
# 4. RESURRECT — CYBRA відсутня
# ═══════════════════════════════════════════════════════════════
def resurrect():
    """Якщо CYBRA відсутня — відновлює з нуля."""
    if (H/"modules").exists(): return False, "CYBRA існує"
    _log("RESURRECT: CYBRA відсутня → відновлення", level="warn")
    rc, out = _run(f"bash {SRC_DIR}/bootstrap_seed.sh", timeout=300)
    if (H/"modules").exists():
        return True, "відновлено з seed"
    return False, out

# ═══════════════════════════════════════════════════════════════
# 5. CYCLE
# ═══════════════════════════════════════════════════════════════
def cycle(do_snapshot=True):
    """Один цикл: перевірка + snapshot + checkpoint + recovery."""
    actions = []

    # 0. Ресуррекція
    if not (H/"modules").exists():
        ok, msg = resurrect()
        actions.append(("resurrect", ok, msg))
        return actions

    # 1. Health
    ok, h = health_ok()
    if not ok:
        _log(f"health {h.get('overall',0)}% < 100 → recovery", level="warn")
        cp = load_checkpoint()
        if cp:
            r_ok, r_info = recover_from_snapshot(cp["snapshot"])
            actions.append(("recover", r_ok, r_info))
        else:
            _log("немає checkpoint — не можу відновити", level="warn")
            actions.append(("recover", False, "no checkpoint"))

    # 2. Snapshot (щогодини)
    if do_snapshot:
        last_snap = None
        all_snaps = sorted(SNAPS.glob("snap_*.tar.gz"), key=lambda p: p.stat().st_mtime, reverse=True)
        if all_snaps: last_snap = all_snaps[0]
        need_snap = (not last_snap) or (time.time() - last_snap.stat().st_mtime > 3600)
        if need_snap:
            s_path, s_size, s_sha = make_snapshot()
            if s_path: actions.append(("snapshot", True, f"{s_size//1024}KB"))

    # 3. Checkpoint (тільки при health=100)
    ok, h = health_ok()
    if ok:
        ok2, cp = set_checkpoint()
        if ok2: actions.append(("checkpoint", True, cp["snapshot"]))

    return actions

def daemon(interval=600):
    """Цикл кожні interval сек (default 10 хв)."""
    _log(f"═══ SRC daemon START · interval={interval}s ═══")
    while RUN:
        try:
            actions = cycle()
            if actions:
                for a in actions:
                    _log(f"  action: {a[0]} = {a[1]}")
        except Exception as e:
            _log(f"cycle error: {e}", level="error")
        for _ in range(interval):
            if not RUN: break
            time.sleep(1)
    _log("═══ SRC STOP ═══")

# ═══════════════════════════════════════════════════════════════
# CLI
# ═══════════════════════════════════════════════════════════════
if __name__ == "__main__":
    import sys
    G='\033[32m'; R='\033[31m'; Y='\033[33m'; B='\033[36m'; D='\033[2m'; BOLD='\033[1m'; N='\033[0m'
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"

    if cmd == "status":
        cp = load_checkpoint()
        snaps = sorted(SNAPS.glob("snap_*.tar.gz"), key=lambda p: p.stat().st_mtime, reverse=True)
        total_size = sum(p.stat().st_size for p in snaps)
        ok, h = health_ok()
        print(f"\n  {B}{BOLD}═══ SRC Status ═══{N}\n")
        print(f"  Health:      {G if ok else R}{h.get('overall',0)}%{N}")
        print(f"  Snapshots:   {len(snaps)} ({total_size//1024//1024} MB)")
        if snaps:
            print(f"  Останній:    {snaps[0].name}")
            print(f"               {time.strftime('%Y-%m-%d %H:%M', time.localtime(snaps[0].stat().st_mtime))}")
        if cp:
            print(f"  Checkpoint:  {cp['snapshot']}")
            print(f"               health={cp['health']}% at {cp['at']}")
        if REMOTE.exists():
            print(f"  Remote:      {REMOTE.read_text().strip()}")
        print(f"  SRC dir:     {SRC_DIR}\n")

    elif cmd == "snapshot":
        s, sz, sha = make_snapshot(tag="manual")
        if s: print(f"  ✓ {s} ({sz//1024}KB, sha={sha})")
        else: print(f"  ✗ failed")

    elif cmd == "checkpoint":
        ok, cp = set_checkpoint()
        print(f"  {'✓' if ok else '✗'} {cp}")

    elif cmd == "cycle":
        acts = cycle()
        for a in acts: print(f"  {a[0]}: {a[1]} — {a[2] if len(a) > 2 else ''}")

    elif cmd == "recover":
        cp = load_checkpoint()
        if not cp: print("  ✗ немає checkpoint"); sys.exit(1)
        ok, info = recover_from_snapshot(cp["snapshot"])
        print(f"  {'✓' if ok else '✗'} {info}")

    elif cmd == "resurrect":
        ok, msg = resurrect()
        print(f"  {'✓' if ok else '✗'} {msg}")

    elif cmd == "daemon":
        iv = int(sys.argv[2]) if len(sys.argv) > 2 else 600
        daemon(iv)

    elif cmd == "set-remote":
        REMOTE.write_text(sys.argv[2])
        print(f"  ✓ remote saved")

    elif cmd == "log":
        n = int(sys.argv[2]) if len(sys.argv) > 2 else 30
        if LOG.exists(): print("\n".join(LOG.read_text().splitlines()[-n:]))
