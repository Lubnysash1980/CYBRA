#!/usr/bin/env python3
"""CYBRA PM — supervisor для всіх фонових процесів.
Стежить за кожним процесом у конфізі, перезапускає якщо впав,
веде метрики restart-ів, ротує логи.
"""
import json, os, sys, time, subprocess, signal, shutil
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

def is_running(proc):
    """Перевіряє через PID-файл + pgrep."""
    pid_file = Path(_expand(proc["pid_file"]))
    pattern = proc.get("match_pattern", "")
    # 1. PID-файл
    if pid_file.exists():
        try:
            pid = int(pid_file.read_text().strip())
            os.kill(pid, 0)
            return True, pid
        except Exception: pass
    # 2. pgrep за pattern
    if pattern:
        try:
            r = subprocess.run(["pgrep","-f", pattern], capture_output=True, timeout=5)
            if r.returncode == 0:
                pids = r.stdout.decode().strip().split()
                if pids:
                    return True, int(pids[0])
        except Exception: pass
    return False, None

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
                if not proc.get("enabled", True): continue
                if name == "supervisor": continue  # себе не чіпаємо

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
    if cmd == "loop": loop()
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
