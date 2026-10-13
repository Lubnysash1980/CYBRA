#!/usr/bin/env python3
"""Runtime Worker — виконує паралельні задачі (jobs).
Працює у черзі з N паралельних слотів.
Якщо падає — JobController + BinMixer підхоплюють.
"""
import json, os, subprocess, sys, time, signal, threading, queue
from pathlib import Path

H = Path.home() / "CYBRA"
M = H / "modules"
D = Path(__file__).resolve().parent
JOBS_DIR = D / "data" / "jobs"
DONE_DIR = D / "data" / "done"
FAILED_DIR = D / "data" / "failed"
LOG = D / "data" / "runtime.log"

RUN = True
def stop(*a):
    global RUN; RUN = False
    _log("stop signal")
signal.signal(signal.SIGTERM, stop)
signal.signal(signal.SIGINT, stop)

def _now(): return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

def _log(msg):
    line = f"[{_now()}] {msg}"
    print(line, flush=True)
    try:
        with open(LOG, "a") as f: f.write(line + "\n")
        if LOG.stat().st_size > 500_000:
            lines = LOG.read_text().splitlines()
            LOG.write_text("\n".join(lines[-500:]) + "\n")
    except Exception: pass

# ═══ JOB ═══
def submit_job(name, cmd, priority=3, timeout=300, retry=2):
    """Створює нову задачу."""
    jid = f"{int(time.time())}-{os.getpid()}-{hash(name) % 10000:04d}"
    job = {
        "id": jid, "name": name, "cmd": cmd, "priority": priority,
        "timeout": timeout, "retry": retry, "retries": 0,
        "submitted": _now(),
        "state": "queued", "owner": "runtime",
    }
    (JOBS_DIR / f"{jid}.json").write_text(json.dumps(job, indent=2))
    return jid

def load_jobs():
    """Повертає всі jobs по пріоритету."""
    jobs = []
    for f in JOBS_DIR.glob("*.json"):
        try:
            j = json.loads(f.read_text())
            jobs.append((f, j))
        except Exception: pass
    jobs.sort(key=lambda x: (x[1].get("priority", 5), x[1].get("submitted", "")))
    return jobs

def run_job(job_file, job):
    """Виконує одну задачу."""
    jid = job["id"]
    job["state"] = "running"
    job["started"] = _now()
    job["owner"] = "runtime"
    job_file.write_text(json.dumps(job, indent=2))

    _log(f"run {jid}: {job['name']}")
    t0 = time.time()
    try:
        r = subprocess.run(job["cmd"], shell=True, capture_output=True,
                          text=True, timeout=job.get("timeout", 300))
        rc = r.returncode
        out = (r.stdout + r.stderr)[-500:]
    except subprocess.TimeoutExpired:
        rc = 124
        out = "timeout"
    except Exception as e:
        rc = 1
        out = str(e)[:300]
    duration = int((time.time()-t0)*1000)

    job["rc"] = rc
    job["duration_ms"] = duration
    job["finished"] = _now()
    job["output"] = out

    if rc == 0:
        job["state"] = "done"
        DONE_DIR.mkdir(exist_ok=True)
        (DONE_DIR / f"{jid}.json").write_text(json.dumps(job, indent=2))
        job_file.unlink()
        _log(f"  ✓ {jid} done ({duration}ms)")
    else:
        # retry
        if job.get("retries", 0) < job.get("retry", 2):
            job["retries"] = job.get("retries", 0) + 1
            job["state"] = "queued"
            job["last_error"] = out
            job_file.write_text(json.dumps(job, indent=2))
            _log(f"  ↻ {jid} retry {job['retries']}/{job['retry']} (rc={rc})")
        else:
            job["state"] = "failed"
            FAILED_DIR.mkdir(exist_ok=True)
            (FAILED_DIR / f"{jid}.json").write_text(json.dumps(job, indent=2))
            job_file.unlink()
            _log(f"  ✗ {jid} failed after {job['retries']} retries (rc={rc})")

def cycle_single():
    """Один цикл — бере одну задачу і виконує."""
    jobs = load_jobs()
    for f, j in jobs:
        if j.get("state") == "queued":
            run_job(f, j)
            return True
    return False

def daemon(workers=3, poll=5):
    """N паралельних воркерів."""
    _log(f"═══ Runtime START · workers={workers} poll={poll}s ═══")
    # використовуємо прості потоки
    def worker_thread(wid):
        while RUN:
            done = cycle_single()
            if not done:
                for _ in range(poll):
                    if not RUN: break
                    time.sleep(1)

    threads = []
    for i in range(workers):
        t = threading.Thread(target=worker_thread, args=(i,), daemon=True)
        t.start()
        threads.append(t)
    # головний чекає
    while RUN:
        time.sleep(1)
    _log(f"═══ Runtime STOP ═══")

def stats():
    return {
        "queued": len(list(JOBS_DIR.glob("*.json"))),
        "done": len(list(DONE_DIR.glob("*.json"))),
        "failed": len(list(FAILED_DIR.glob("*.json"))),
    }

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "stats"
    if cmd == "submit":
        name = sys.argv[2]
        cmnd = sys.argv[3]
        prio = int(sys.argv[4]) if len(sys.argv) > 4 else 3
        jid = submit_job(name, cmnd, prio)
        print(f"  ✓ submitted: {jid}")
    elif cmd == "stats":
        s = stats()
        G='\033[32m'; Y='\033[33m'; R='\033[31m'; B='\033[36m'; N='\033[0m'
        print(f"\n  {B}Runtime{N}")
        print(f"    queued: {Y}{s['queued']}{N}")
        print(f"    done:   {G}{s['done']}{N}")
        print(f"    failed: {R}{s['failed']}{N}\n")
    elif cmd == "run-one":
        r = cycle_single()
        print(f"  ran: {r}")
    elif cmd == "daemon":
        w = int(sys.argv[2]) if len(sys.argv) > 2 else 3
        daemon(workers=w)
    elif cmd == "list":
        for f, j in load_jobs():
            print(f"  {j['id']}  [{j['state']:8s}]  P{j['priority']}  {j['name']}")
