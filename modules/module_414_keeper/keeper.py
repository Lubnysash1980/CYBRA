#!/usr/bin/env python3
"""Resilient Keeper — тримає процеси живими.

Правила:
  · Кожні 2 сек — перевірка
  · Якщо впав — рестарт негайно
  · Якщо 5 разів за хвилину — backoff 30s
  · Якщо daemon — завжди піднімаємо
  · Якщо interval — scheduler окремо

Підтримка серверів (автопошук):
  · Local Termux (зараз)
  · Oracle Cloud (SSH)
  · TimeWeb (SSH)
  · Namecheap hosting (SSH)
  · CodeSpaces (github)
  · VPS (SSH)

Якщо локально впало — пробуємо remote (якщо є SSH).
"""
import json, os, subprocess, sys, time, signal, threading
from pathlib import Path
from collections import defaultdict, deque

H = Path.home() / "CYBRA"
CFG = H / "config/pm_processes.json"
SERVERS = H / "config/servers.json"
LOG = H / "logs/keeper.log"
STATE = D = Path(__file__).resolve().parent / "data" / "state.json"

RUN = True
def stop(*a):
    global RUN; RUN = False
signal.signal(signal.SIGTERM, stop)
signal.signal(signal.SIGINT, stop)

# Реєстр рестартів: name → deque(timestamps)
_restarts = defaultdict(lambda: deque(maxlen=20))

def _now(): return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
def _ts(): return int(time.time())

def _log(msg, level="info"):
    line = f"[{_now()}] [{level}] {msg}"
    try:
        with open(LOG, "a") as f: f.write(line + "\n")
        if LOG.stat().st_size > 500_000:
            lines = LOG.read_text().splitlines()
            LOG.write_text("\n".join(lines[-1000:]) + "\n")
    except Exception: pass
    print(line, flush=True)

def _run(cmd, timeout=10, cwd=None):
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True,
                          timeout=timeout, cwd=cwd)
        return r.returncode, (r.stdout + r.stderr)[:300]
    except subprocess.TimeoutExpired:
        return 124, "timeout"
    except Exception as e:
        return 1, str(e)[:200]

def is_running(pat):
    if not pat: return False
    rc, _ = _run(f"pgrep -f '{pat}'")
    return rc == 0

def should_restart(name):
    """Anti-flood: не частіше 5 разів на хвилину, інакше backoff."""
    now = _ts()
    r = _restarts[name]
    recent = [t for t in r if now - t < 60]
    if len(recent) >= 5:
        # Backoff 30 сек після 5 спроб
        if r and now - r[-1] < 30:
            return False, "backoff"
    return True, "ok"

def start_proc(name, proc):
    """Запуск процесу."""
    cmd = proc["cmd"].replace("$HOME", str(H))
    log_file = Path(proc.get("log_file",
                             str(H/f"logs/{name}.log")).replace("$HOME", str(H)))
    log_file.parent.mkdir(parents=True, exist_ok=True)
    pid_file = Path(proc.get("pid_file",
                             str(H/f"run/keeper_{name}.pid")).replace("$HOME", str(H)))
    pid_file.parent.mkdir(parents=True, exist_ok=True)
    try:
        with open(log_file, "a") as lf:
            lf.write(f"\n=== KEEPER START {_now()} ===\n")
            lf.flush()
            p = subprocess.Popen(["bash", "-c", f"exec {cmd}"],
                                stdout=lf, stderr=lf, stdin=subprocess.DEVNULL,
                                preexec_fn=os.setsid, cwd=str(H))
        pid_file.write_text(str(p.pid))
        _restarts[name].append(_ts())
        return True, p.pid
    except Exception as e:
        return False, str(e)[:100]

# ═══════════════════════════════════════════════════════════════
# СЕРВЕРИ — автопошук
# ═══════════════════════════════════════════════════════════════
def load_servers():
    if not SERVERS.exists():
        # шаблон
        SERVERS.write_text(json.dumps({
            "servers": [
                {"name": "local", "type": "local", "enabled": True},
                {"name": "oracle", "type": "ssh", "host": "", "user": "ubuntu", "enabled": False},
                {"name": "timeweb", "type": "ssh", "host": "", "user": "root", "enabled": False},
                {"name": "namecheap", "type": "ssh", "host": "", "user": "", "enabled": False},
                {"name": "codespaces", "type": "ssh", "host": "", "user": "", "enabled": False},
                {"name": "vps", "type": "ssh", "host": "", "user": "root", "enabled": False},
            ]
        }, indent=2))
    try:
        return json.loads(SERVERS.read_text())
    except Exception: return {"servers": [{"name":"local","type":"local","enabled":True}]}

def find_alive_server():
    """Повертає перший живий сервер."""
    for s in load_servers()["servers"]:
        if not s.get("enabled"): continue
        if s["type"] == "local":
            return s
        elif s["type"] == "ssh":
            # Перевірка SSH
            rc, _ = _run(f"ssh -o ConnectTimeout=3 -o StrictHostKeyChecking=no "
                        f"{s.get('user','root')}@{s.get('host','')} 'echo ok'",
                        timeout=8)
            if rc == 0:
                return s
    return None

def start_remote(server, name, proc):
    """Запустити процес на remote через SSH."""
    if server["type"] != "ssh": return False, "not ssh"
    cmd = proc["cmd"].replace("$HOME", "~/CYBRA")
    remote_cmd = (f"cd ~/CYBRA && nohup bash -c 'exec {cmd}' "
                  f">>logs/{name}.log 2>&1 </dev/null & echo $!")
    rc, out = _run(f"ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "
                  f"{server['user']}@{server['host']} \"{remote_cmd}\"",
                  timeout=15)
    return rc == 0, out[:200]

# ═══════════════════════════════════════════════════════════════
# MAIN LOOP
# ═══════════════════════════════════════════════════════════════
def loop(interval=2):
    _log(f"═══ KEEPER START · interval={interval}s ═══")
    last_server_check = 0
    alive_server = None

    while RUN:
        try:
            if not CFG.exists():
                time.sleep(interval); continue
            d = json.loads(CFG.read_text())
            now = _ts()

            # Автопошук сервера раз на 5 хв
            if now - last_server_check > 300:
                alive_server = find_alive_server()
                last_server_check = now
                if alive_server:
                    _log(f"alive server: {alive_server.get('name')}")

            for name, proc in d["processes"].items():
                mode = proc.get("mode", "daemon")
                if mode != "daemon": continue
                if not proc.get("enabled", True): continue
                if name == "keeper": continue  # себе не рестартуємо

                pat = proc.get("match_pattern", name)
                if is_running(pat): continue

                ok_restart, reason = should_restart(name)
                if not ok_restart:
                    continue

                # Спроба локально
                _log(f"restart {name} (reason={reason})", "warn")
                ok_start, info = start_proc(name, proc)
                if ok_start:
                    _log(f"  ✓ {name} PID {info}")
                else:
                    _log(f"  ✗ {name}: {info}", "error")
                    # Спроба на remote
                    if alive_server and alive_server["type"] == "ssh":
                        _log(f"  try remote {alive_server['name']}...")
                        r_ok, r_info = start_remote(alive_server, name, proc)
                        if r_ok:
                            _log(f"  ✓ {name} on remote {alive_server['name']}")
                        else:
                            _log(f"  ✗ remote: {r_info}", "error")

        except Exception as e:
            _log(f"loop err: {e}", "error")

        for _ in range(interval):
            if not RUN: break
            time.sleep(1)

    _log("═══ KEEPER STOP ═══")

def status():
    """Поточний стан."""
    if not CFG.exists(): return {"error": "no config"}
    d = json.loads(CFG.read_text())
    out = {"daemons": [], "alive_server": None, "restarts": {}}
    for name, proc in d["processes"].items():
        if proc.get("mode") != "daemon": continue
        pat = proc.get("match_pattern", name)
        running = is_running(pat)
        out["daemons"].append({"name": name, "running": running})
        out["restarts"][name] = len(_restarts[name])
    s = find_alive_server()
    out["alive_server"] = s.get("name") if s else None
    return out

if __name__ == "__main__":
    import sys
    G='\033[32m'; R='\033[31m'; Y='\033[33m'; B='\033[36m'; BOLD='\033[1m'; D_='\033[2m'; N='\033[0m'
    cmd = sys.argv[1] if len(sys.argv) > 1 else "loop"

    if cmd == "loop":
        interval = int(sys.argv[2]) if len(sys.argv) > 2 else 2
        loop(interval)

    elif cmd == "status":
        s = status()
        print(f"\n  {B}{BOLD}═══ Keeper Status ═══{N}\n")
        print(f"  Сервер: {G if s.get('alive_server') else R}{s.get('alive_server') or 'немає'}{N}")
        print(f"\n  Daemons:")
        for d in s.get("daemons", []):
            col = G if d["running"] else R
            mark = "●" if d["running"] else "○"
            print(f"    {col}{mark}{N} {d['name']:24s} restarts: {s['restarts'].get(d['name'],0)}")
        print()

    elif cmd == "servers":
        s = load_servers()
        print(f"\n  {B}Servers:{N}")
        for srv in s["servers"]:
            en = srv.get("enabled")
            col = G if en else Y
            print(f"    {col}{'✓' if en else '·'}{N} {srv['name']:12s} {srv['type']:6s} {srv.get('host','')}")
        print()
        alive = find_alive_server()
        print(f"  Alive: {alive['name'] if alive else 'немає'}")

    elif cmd == "test-server":
        # Тест конкретного сервера
        alive = find_alive_server()
        if alive: print(f"  ✓ {alive['name']} відповідає")
        else: print(f"  ✗ немає живого сервера")
