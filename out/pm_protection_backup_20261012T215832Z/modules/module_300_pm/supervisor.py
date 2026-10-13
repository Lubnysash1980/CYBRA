#!/usr/bin/env python3
"""CYBRA PM — supervisor для всіх фонових процесів.
Стежить за кожним процесом у конфізі, перезапускає якщо впав,
веде метрики restart-ів, ротує логи.
"""
import json, os, sys, time, subprocess, signal, shutil, fcntl, atexit
from pathlib import Path

H = Path.home() / "CYBRA"
CFG = H / "config" / "pm_processes.json"
STATE = H / "config" / "pm_state.json"
METRICS = H / "config" / "pm_metrics.jsonl"
PM_LOG = H / "logs" / "pm.log"

RUN = True
def stop(*a):
    global RUN
    RUN = False
    log("supervisor stopping")
signal.signal(signal.SIGTERM, stop)
signal.signal(signal.SIGINT, stop)

# ─── helpers ────────────────────────────────────────────────
def _expand(s):
    return os.path.expandvars(os.path.expanduser(s))

def log(msg, level="info"):
    ts = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    line = f"[{ts}] [{level}] {msg}"
    print(line, flush=True)
    try:
        with open(PM_LOG, "a") as f: f.write(line + "\n")
        if PM_LOG.stat().st_size > 2_000_000:
            lines = PM_LOG.read_text().splitlines()
            PM_LOG.write_text("\n".join(lines[-2000:]) + "\n")
    except Exception: pass

def load_cfg():
    return json.loads(CFG.read_text())

def load_state():
    if not STATE.exists(): return {"procs": {}}
    try: return json.loads(STATE.read_text())
    except Exception: return {"procs": {}}

def save_state(s):
    tmp = str(STATE) + ".tmp"
    Path(tmp).write_text(json.dumps(s, indent=2, ensure_ascii=False))
    os.replace(tmp, STATE)

def log_metric(m):
    m["ts"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    with open(METRICS, "a") as f: f.write(json.dumps(m) + "\n")


def _process_cmdline(pid):
    """Повертає фактичний cmdline процесу з /proc."""
    try:
        return Path(f"/proc/{pid}/cmdline").read_bytes().replace(
            b"\0", b" "
        ).decode(errors="replace").strip()
    except (OSError, ValueError):
        return ""

def _expected_pattern(proc):
    """Визначає ознаку процесу для перевірки його ідентичності."""
    pattern = proc.get("match_pattern", "")
    if pattern:
        return _expand(pattern)

    # Без match_pattern не приймаємо довільний живий PID.
    command = _expand(proc.get("cmd", ""))
    for token in command.split():
        if token.endswith((".py", ".sh")):
            return token
    return ""

def _pid_matches(pid, proc):
    """PID вважається правильним лише за відповідності cmdline."""
    try:
        if pid <= 1:
            return False
        os.kill(pid, 0)
        cmdline = _process_cmdline(pid)
        pattern = _expected_pattern(proc)
        return bool(cmdline and pattern and pattern in cmdline)
    except (OSError, ValueError, ProcessLookupError, PermissionError):
        return False

def is_running(proc):
    """Перевіряє PID-файл і підтверджує ідентичність процесу."""
    pid_file = Path(_expand(proc["pid_file"]))
    pattern = _expected_pattern(proc)

    # 1. PID-файл — лише кандидат, не доказ ідентичності.
    if pid_file.exists():
        try:
            pid = int(pid_file.read_text().strip())
            if _pid_matches(pid, proc):
                return True, pid
        except (OSError, ValueError):
            pass

    # 2. Пошук інших кандидатів з обов'язковою перевіркою cmdline.
    if pattern:
        try:
            result = subprocess.run(
                ["pgrep", "-f", pattern],
                capture_output=True,
                text=True,
                timeout=5
            )
            if result.returncode == 0:
                for item in result.stdout.split():
                    try:
                        pid = int(item)
                    except ValueError:
                        continue
                    if pid != os.getpid() and _pid_matches(pid, proc):
                        return True, pid
        except (OSError, subprocess.SubprocessError):
            pass

    return False, None


# ─── Supervisor singleton / власний PID ─────────────────────
_SUPERVISOR_LOCK_FH = None
_SUPERVISOR_PID_FILE = H / "run" / "pm_supervisor.pid"
_SUPERVISOR_LOCK_FILE = H / "run" / "pm_supervisor.lock"

def _atomic_write_pid(path, pid):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + f".{os.getpid()}.tmp")
    try:
        tmp.write_text(f"{pid}\n")
        os.replace(tmp, path)
    finally:
        try:
            if tmp.exists():
                tmp.unlink()
        except OSError:
            pass

def _is_supervisor_process(pid):
    if pid <= 1 or pid == os.getpid():
        return False
    cmdline = _process_cmdline(pid)
    return "supervisor.py" in cmdline and "loop" in cmdline

def _release_supervisor_guard():
    global _SUPERVISOR_LOCK_FH
    try:
        if _SUPERVISOR_PID_FILE.exists():
            try:
                current = int(_SUPERVISOR_PID_FILE.read_text().strip())
            except (OSError, ValueError):
                current = -1
            # Не видаляємо PID, якщо його вже змінив інший процес.
            if current == os.getpid():
                _SUPERVISOR_PID_FILE.unlink(missing_ok=True)
    except OSError:
        pass

    if _SUPERVISOR_LOCK_FH is not None:
        try:
            _SUPERVISOR_LOCK_FH.close()
        except OSError:
            pass
        _SUPERVISOR_LOCK_FH = None

def acquire_singleton():
    """Не дозволяє двом Supervisor loop працювати одночасно."""
    global _SUPERVISOR_LOCK_FH

    _SUPERVISOR_LOCK_FILE.parent.mkdir(parents=True, exist_ok=True)
    fh = open(_SUPERVISOR_LOCK_FILE, "a+")

    try:
        fcntl.flock(fh.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        # Читаємо PID власника блокування; PID-файл відновлюємо
        # лише якщо власник підтверджений через /proc.
        try:
            fh.seek(0)
            owner = int(fh.read().strip())
        except (OSError, ValueError):
            owner = -1

        if _is_supervisor_process(owner):
            try:
                _atomic_write_pid(_SUPERVISOR_PID_FILE, owner)
            except OSError:
                pass

        print(
            f"FALSE / DUPLICATE_BLOCKED: Supervisor lock held "
            f"(owner PID {owner if owner > 1 else 'unverified'})",
            flush=True
        )
        fh.close()
        return False
    except OSError as exc:
        fh.close()
        print(f"FALSE / LOCK_ERROR: {exc}", flush=True)
        return False

    # Блокування отримано — тепер можна зареєструвати власний PID.
    fh.seek(0)
    fh.truncate()
    fh.write(f"{os.getpid()}\n")
    fh.flush()
    os.fsync(fh.fileno())

    _SUPERVISOR_LOCK_FH = fh
    try:
        _atomic_write_pid(_SUPERVISOR_PID_FILE, os.getpid())
    except OSError as exc:
        _release_supervisor_guard()
        print(f"FALSE / PID_WRITE_ERROR: {exc}", flush=True)
        return False

    atexit.register(_release_supervisor_guard)
    print(
        f"SUPERVISOR_LOCK_ACQUIRED PID={os.getpid()}",
        flush=True
    )
    return True

def start_proc(name, proc):
    cmd = _expand(proc["cmd"])
    cwd = _expand(proc.get("cwd", str(H)))
    log_file = Path(_expand(proc["log_file"]))
    pid_file = Path(_expand(proc["pid_file"]))
    log_file.parent.mkdir(parents=True, exist_ok=True)
    pid_file.parent.mkdir(parents=True, exist_ok=True)

    log(f"start {name}: {cmd}")
    try:
        with open(log_file, "a") as lf:
            lf.write(f"\n=== START {time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())} ===\n")
            lf.flush()
            # запуск через bash -c щоб розкрити $HOME
            p = subprocess.Popen(
                ["bash","-c", f"exec {cmd}"],
                cwd=cwd, stdout=lf, stderr=lf, stdin=subprocess.DEVNULL,
                preexec_fn=os.setsid  # нова session, відв'язано від батька
            )
        pid_file.write_text(str(p.pid))
        time.sleep(1)
        if p.poll() is None:
            log(f"{name} started (PID {p.pid})")
            return True, p.pid
        else:
            log(f"{name} died immediately (rc={p.returncode})", "warn")
            return False, p.returncode
    except Exception as e:
        log(f"{name} start error: {e}", "error")
        return False, str(e)

def stop_proc(name, proc):
    running, pid = is_running(proc)
    if not running:
        return True, "not running"
    log(f"stop {name} (PID {pid})")
    try:
        os.kill(pid, signal.SIGTERM)
        for _ in range(10):
            time.sleep(0.5)
            try: os.kill(pid, 0)
            except ProcessLookupError: break
        else:
            os.kill(pid, signal.SIGKILL)
    except Exception as e:
        log(f"{name} stop error: {e}", "warn")
    # cleanup pid
    pid_file = Path(_expand(proc["pid_file"]))
    if pid_file.exists(): pid_file.unlink()
    return True, "stopped"

# ─── supervisor loop ────────────────────────────────────────
def loop():
    log("═══ CYBRA PM supervisor start ═══")
    cfg = load_cfg()
    interval = cfg["supervisor"].get("check_interval_sec", 30)
    max_restarts = cfg["supervisor"].get("max_restart_per_hour", 20)
    restart_delay = cfg["supervisor"].get("restart_delay_sec", 10)

    state = load_state()
    for name in cfg["processes"]:
        state["procs"].setdefault(name, {"restarts": [], "last_check": None})
    save_state(state)

    while RUN:
        try:
            cfg = load_cfg()  # reload
            for name, proc in cfg["processes"].items():
                # Режими:
                #   daemon   — auto-restart (цей контролер)
                #   interval — scheduler підніме
                #   ondemand — вручну
                mode = proc.get("mode", "daemon")
                if mode != "daemon":
                    continue
                if name == "supervisor": continue  # себе не чіпаємо

                if proc.get("mode", "daemon") != "daemon":
                    continue
                running, pid = is_running(proc)
                st = state["procs"].setdefault(name, {"restarts": []})
                st["last_check"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

                if not running:
                    # rate limit restart-ів
                    cutoff = time.time() - 3600
                    recent = [t for t in st["restarts"] if t > cutoff]
                    st["restarts"] = recent

                    if proc.get("auto_restart", True) and len(recent) < max_restarts:
                        log(f"{name} не працює — перезапускаю")
                        time.sleep(restart_delay)
                        ok, info = start_proc(name, proc)
                        if ok:
                            st["restarts"].append(time.time())
                            log_metric({"name": name, "action": "restart", "ok": True})
                        else:
                            log_metric({"name": name, "action": "restart", "ok": False, "err": str(info)})
                    elif len(recent) >= max_restarts:
                        log(f"{name}: забагато перезапусків за годину ({len(recent)}) — skip", "warn")
                else:
                    log_metric({"name": name, "action": "check", "ok": True, "pid": pid})

            save_state(state)
        except Exception as e:
            log(f"loop error: {e}", "error")

        # інтервал
        for _ in range(interval):
            if not RUN: break
            time.sleep(1)

    log("═══ CYBRA PM supervisor stop ═══")

# ─── CLI (для pm.sh) ────────────────────────────────────────
def cmd_list():
    cfg = load_cfg(); state = load_state()
    G='\033[32m'; R='\033[31m'; Y='\033[33m'; B='\033[36m'; D='\033[2m'; N='\033[0m'
    print(f"\n{B}name         status   pid      restarts  desc{N}")
    print(f"{D}{'─'*88}{N}")
    for name, proc in cfg["processes"].items():
        running, pid = is_running(proc)
        col = G if running else R
        mark = "● online " if running else "○ offline"
        st = state["procs"].get(name, {})
        restarts = len(st.get("restarts", []))
        desc = proc.get("desc", "")[:44]
        pid_s = str(pid) if pid else "—"
        print(f"{col}{name:12s}{N} {mark}  {pid_s:>8s}  {restarts:>8d}  {D}{desc}{N}")
    print()

def cmd_status(name):
    cfg = load_cfg()
    proc = cfg["processes"].get(name)
    if not proc: print(f"✗ не знайдено: {name}"); return
    running, pid = is_running(proc)
    print(json.dumps({
        "name": name, "running": running, "pid": pid,
        "cmd": proc["cmd"], "log": proc["log_file"],
        "auto_restart": proc.get("auto_restart", True),
    }, indent=2, ensure_ascii=False))

def cmd_start(name):
    cfg = load_cfg()
    proc = cfg["processes"].get(name)
    if not proc: print(f"✗ не знайдено: {name}"); return 1
    running, pid = is_running(proc)
    if running: print(f"● {name} вже працює (PID {pid})"); return 0
    ok, info = start_proc(name, proc)
    print(("✓ " if ok else "✗ ") + f"{name} " + (f"PID {info}" if ok else str(info)))
    return 0 if ok else 1

def cmd_stop(name):
    cfg = load_cfg()
    proc = cfg["processes"].get(name)
    if not proc: print(f"✗ не знайдено: {name}"); return 1
    ok, msg = stop_proc(name, proc)
    print(("✓ " if ok else "✗ ") + f"{name} {msg}")
    return 0

def cmd_restart(name):
    cmd_stop(name); time.sleep(1); cmd_start(name)

def cmd_start_all():
    cfg = load_cfg()
    for name, proc in cfg["processes"].items():
        if name == "supervisor": continue
        running, _ = is_running(proc)
        if not running and proc.get("enabled", True):
            start_proc(name, proc)

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "list"
    if cmd == "loop":
        if not acquire_singleton(): sys.exit(73)
        loop()
    elif cmd == "list": cmd_list()
    elif cmd == "status":
        cmd_status(sys.argv[2]) if len(sys.argv) > 2 else cmd_list()
    elif cmd == "start": cmd_start(sys.argv[2]); sys.exit(0)
    elif cmd == "stop": cmd_stop(sys.argv[2]); sys.exit(0)
    elif cmd == "restart": cmd_restart(sys.argv[2])
    elif cmd == "start-all": cmd_start_all()
    else:
        print("usage: supervisor.py {loop|list|status|start|stop|restart|start-all} [name]")
        sys.exit(1)
