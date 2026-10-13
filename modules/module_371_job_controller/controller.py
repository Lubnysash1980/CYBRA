#!/usr/bin/env python3
"""Job Controller — керує чергою задач між Runtime і Worker.

Логіка:
  1. Runtime живий → job виконується через runtime
  2. Runtime впав → job виконується через BinMixer (failover)
  3. Runtime піднявся → повертає собі свої задачі
  4. Жодна job не втрачається
  5. Кожна job має owner (runtime | binmixer | worker)
"""
import json, os, subprocess, sys, time, signal
from pathlib import Path

H = Path.home() / "CYBRA"
M = H / "modules"
D = Path(__file__).resolve().parent
LOG = D / "data" / "controller.log"
STATE = D / "data" / "controller_state.json"

RUNTIME_DIR = M / "module_370_runtime/data"
JOBS_DIR = RUNTIME_DIR / "jobs"
DONE_DIR = RUNTIME_DIR / "done"
FAILED_DIR = RUNTIME_DIR / "failed"

RUN = True
def stop(*a):
    global RUN; RUN = False
    _log("stop signal")
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

# ═══ RUNTIME HEALTH ═══
def runtime_alive():
    """Чи живий runtime daemon."""
    rc, _ = _run("pgrep -f 'module_370_runtime/runtime.py daemon'")
    return rc == 0

def binmixer_alive():
    """Чи живий binmixer."""
    rc, _ = _run("pgrep -f 'module_102_binmix_daemon'")
    return rc == 0

def worker_alive():
    rc, _ = _run("pgrep -f 'module_350_controller_worker/worker.py daemon'")
    return rc == 0

# ═══ RUNTIME START/STOP ═══
def start_runtime(workers=3):
    if runtime_alive():
        return True, "already running"
    cmd = f"cd {H} && nohup python3 {M}/module_370_runtime/runtime.py daemon {workers} </dev/null >>{LOG} 2>&1 &"
    rc, out = _run(cmd, timeout=15)
    time.sleep(2)
    if runtime_alive():
        _log("✓ runtime started")
        return True, "started"
    return False, "failed"

def stop_runtime():
    _run("pkill -f 'module_370_runtime/runtime.py daemon'")
    time.sleep(1)
    return not runtime_alive()

# ═══ BINMIXER FAILOVER ═══
def binmixer_run_job(job_file, job):
    """Виконує job через BinMixer (failover режим)."""
    jid = job["id"]
    _log(f"⚠ failover → binmixer: {jid} ({job['name']})")
    job["owner"] = "binmixer"
    job["state"] = "running"
    job["started"] = _now()
    job_file.write_text(json.dumps(job, indent=2))

    t0 = time.time()
    try:
        r = subprocess.run(job["cmd"], shell=True, capture_output=True,
                          text=True, timeout=job.get("timeout", 300))
        rc = r.returncode
        out = (r.stdout + r.stderr)[-500:]
    except Exception as e:
        rc = 1; out = str(e)[:300]
    duration = int((time.time()-t0)*1000)
    job["rc"] = rc; job["duration_ms"] = duration
    job["finished"] = _now(); job["output"] = out

    if rc == 0:
        job["state"] = "done"
        DONE_DIR.mkdir(exist_ok=True)
        (DONE_DIR / f"{jid}.json").write_text(json.dumps(job, indent=2))
        job_file.unlink()
        _log(f"  ✓ {jid} done via binmixer ({duration}ms)")
    else:
        if job.get("retries", 0) < job.get("retry", 2):
            job["retries"] = job.get("retries", 0) + 1
            job["state"] = "queued"
            job_file.write_text(json.dumps(job, indent=2))
            _log(f"  ↻ {jid} retry {job['retries']}")
        else:
            job["state"] = "failed"
            FAILED_DIR.mkdir(exist_ok=True)
            (FAILED_DIR / f"{jid}.json").write_text(json.dumps(job, indent=2))
            job_file.unlink()
            _log(f"  ✗ {jid} failed (binmixer)", level="warn")

# ═══ CYCLE ═══
def cycle():
    """Один цикл контролера."""
    actions = []
    r_alive = runtime_alive()
    b_alive = binmixer_alive()
    w_alive = worker_alive()

    # 1. Runtime впав — підняти
    if not r_alive:
        _log("runtime не працює → start", level="warn")
        ok, msg = start_runtime()
        actions.append(("start_runtime", ok))
        r_alive = runtime_alive()

    # 2. Якщо runtime ще не піднявся — failover на binmixer
    if not r_alive:
        jobs = sorted(JOBS_DIR.glob("*.json"),
                     key=lambda f: json.loads(f.read_text()).get("priority", 5))
        if jobs and b_alive:
            _log(f"⚠ runtime down · {len(jobs)} jobs → binmixer")
            for jf in jobs[:3]:  # по 3 за цикл
                try:
                    j = json.loads(jf.read_text())
                    if j.get("state") == "queued":
                        binmixer_run_job(jf, j)
                        actions.append(("binmixer_job", True))
                except Exception: pass
        elif jobs and not b_alive:
            _log("⚠ binmixer down → start", level="warn")
            _run("cybra-pm start binmixer")
            actions.append(("start_binmixer", True))

    # 3. Runtime піднявся — повернути власні jobs
    if r_alive:
        jobs = list(JOBS_DIR.glob("*.json"))
        for jf in jobs:
            try:
                j = json.loads(jf.read_text())
                if j.get("owner") == "binmixer" and j.get("state") == "queued":
                    j["owner"] = "runtime"
                    jf.write_text(json.dumps(j, indent=2))
                    actions.append(("return_to_runtime", True))
                    _log(f"↩ {j['id']} → runtime")
            except Exception: pass

    # 4. Worker — self-heal
    if not w_alive:
        _log("worker down → start", level="warn")
        _run("cybra-pm start controller_worker")
        actions.append(("start_worker", True))

    state = {
        "at": _now(),
        "runtime": r_alive,
        "binmixer": b_alive,
        "worker": w_alive,
        "queued": len(list(JOBS_DIR.glob("*.json"))),
        "actions": actions,
    }
    STATE.write_text(json.dumps(state, indent=2))

    return state

def daemon(interval=30):
    _log(f"═══ Job Controller START · interval={interval}s ═══")
    while RUN:
        try: cycle()
        except Exception as e: _log(f"error: {e}", level="error")
        for _ in range(interval):
            if not RUN: break
            time.sleep(1)
    _log("═══ STOP ═══")

if __name__ == "__main__":
    import sys
    cmd = sys.argv[1] if len(sys.argv) > 1 else "cycle"
    G='\033[32m'; R='\033[31m'; Y='\033[33m'; B='\033[36m'; N='\033[0m'
    if cmd == "cycle":
        s = cycle()
        print(f"\n  {B}Runtime:{N}   {'✓' if s['runtime'] else '✗'}")
        print(f"  {B}BinMixer:{N}  {'✓' if s['binmixer'] else '✗'}")
        print(f"  {B}Worker:{N}    {'✓' if s['worker'] else '✗'}")
        print(f"  {B}Queued:{N}    {s['queued']}")
        if s["actions"]:
            print(f"  {B}Actions:{N}")
            for a, ok in s["actions"]:
                print(f"    {'✓' if ok else '✗'} {a}")
    elif cmd == "daemon":
        iv = int(sys.argv[2]) if len(sys.argv) > 2 else 30
        daemon(iv)
    elif cmd == "status":
        if STATE.exists(): print(STATE.read_text())
        else: print("(не запускався)")
    elif cmd == "log":
        n = int(sys.argv[2]) if len(sys.argv) > 2 else 30
        if LOG.exists(): print("\n".join(LOG.read_text().splitlines()[-n:]))
