#!/usr/bin/env python3
"""Load Controller — балансує навантаження. Не дає перевантажити.

Правила:
  · CPU > 80% → призупинити некритичні (priority 3-5)
  · CPU > 95% → тільки priority 1
  · RAM > 80% → призупинити worker/evolve
  · Disk > 90% → cleanup
  · CPU < 30% → запустити відкладене (evolve, autopilot, snapshot)
"""
import json, os, subprocess, sys, time
from pathlib import Path

H = Path.home() / "CYBRA"
D = Path(__file__).resolve().parent
STATE = D / "data" / "load_state.json"
LOGS = D / "data" / "load.log"

def _now(): return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
def _log(msg):
    line = f"[{_now()}] {msg}"
    print(line, flush=True)
    try:
        with open(LOGS, "a") as f: f.write(line + "\n")
        if LOGS.stat().st_size > 200_000:
            lines = LOGS.read_text().splitlines()
            LOGS.write_text("\n".join(lines[-200:]) + "\n")
    except Exception: pass

def get_load():
    """CPU load + memory + disk."""
    out = {}
    try:
        with open("/proc/loadavg") as f:
            parts = f.read().split()
            out["load_1m"] = float(parts[0])
            out["load_5m"] = float(parts[1])
            out["load_15m"] = float(parts[2])
    except Exception: pass
    # CPU count
    try:
        out["cpu_count"] = os.cpu_count() or 1
    except Exception: out["cpu_count"] = 1
    # CPU % приблизно = load_1m / cpu_count * 100
    if "load_1m" in out:
        out["cpu_pct"] = round(out["load_1m"] / out["cpu_count"] * 100, 1)
    # RAM через /proc/meminfo
    try:
        mem = {}
        with open("/proc/meminfo") as f:
            for line in f:
                k, v = line.split(":", 1)
                mem[k.strip()] = int(v.split()[0])
        total = mem.get("MemTotal", 1)
        avail = mem.get("MemAvailable", mem.get("MemFree", 0))
        out["ram_total_mb"] = total // 1024
        out["ram_avail_mb"] = avail // 1024
        out["ram_pct"] = round((total - avail) / total * 100, 1)
    except Exception: pass
    # Disk
    import shutil
    try:
        _, _, free = shutil.disk_usage(str(H))
        out["disk_free_mb"] = free // (1024*1024)
    except Exception: pass
    return out

def decide(load):
    """Повертає режим роботи."""
    cpu = load.get("cpu_pct", 0)
    ram = load.get("ram_pct", 0)
    if cpu > 95:
        return "critical", "Тільки priority 1"
    if cpu > 80 or ram > 80:
        return "high", "Призупинити priority 3-5"
    if cpu > 50:
        return "normal", "Все працює"
    if cpu < 30:
        return "idle", "Час для важких задач (evolve, autopilot, snapshot)"
    return "normal", "Все працює"

def apply(mode):
    """Застосовує режим до процесів."""
    actions = []
    if mode == "critical":
        # вимкнути некритичне
        for proc in ["dashboard", "runtime", "controller_worker"]:
            r = subprocess.run(["cybra-pm", "stop", proc], capture_output=True, timeout=10)
            if r.returncode == 0: actions.append(f"stopped {proc}")
    elif mode == "high":
        for proc in ["dashboard", "runtime"]:
            r = subprocess.run(["cybra-pm", "stop", proc], capture_output=True, timeout=10)
            if r.returncode == 0: actions.append(f"stopped {proc}")
    elif mode == "idle":
        # запустити важкі задачі
        for proc in ["dashboard", "runtime", "controller_worker"]:
            # перевірити чи вже працює
            r = subprocess.run(f"pgrep -f '{proc}'", shell=True, capture_output=True, timeout=5)
            if r.returncode != 0:
                subprocess.run(["cybra-pm", "start", proc], capture_output=True, timeout=10)
                actions.append(f"started {proc}")
        # evolve / snapshot
        subprocess.Popen(["python3", str(H/"modules/module_390_src/src.py"), "snapshot"],
                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        actions.append("snapshot")
    return actions

def cycle():
    load = get_load()
    mode, reason = decide(load)
    actions = apply(mode)
    state = {
        "at": _now(), "load": load, "mode": mode, "reason": reason,
        "actions": actions,
    }
    STATE.write_text(json.dumps(state, indent=2, ensure_ascii=False))
    _log(f"mode={mode} cpu={load.get('cpu_pct')}% ram={load.get('ram_pct')}% → {len(actions)} actions")
    return state

def daemon(interval=60):
    _log(f"═══ Load Controller START · interval={interval}s ═══")
    while True:
        try: cycle()
        except Exception as e: _log(f"error: {e}")
        time.sleep(interval)

if __name__ == "__main__":
    import sys
    G='\033[32m'; Y='\033[33m'; R='\033[31m'; B='\033[36m'; BOLD='\033[1m'; N='\033[0m'
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "status":
        load = get_load()
        mode, reason = decide(load)
        col = {"critical":R, "high":Y, "normal":G, "idle":G}[mode]
        print(f"\n  {B}{BOLD}Load Controller{N}\n")
        print(f"  CPU:    {load.get('cpu_pct','?')}% (load {load.get('load_1m','?')})")
        print(f"  RAM:    {load.get('ram_pct','?')}% ({load.get('ram_avail_mb','?')} MB free)")
        print(f"  Disk:   {load.get('disk_free_mb','?')} MB free")
        print(f"\n  Mode:   {col}{mode}{N} — {reason}")
    elif cmd == "cycle":
        s = cycle()
        print(json.dumps(s, indent=2, ensure_ascii=False))
    elif cmd == "daemon":
        iv = int(sys.argv[2]) if len(sys.argv) > 2 else 60
        daemon(iv)
