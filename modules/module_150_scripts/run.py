#!/usr/bin/env python3
"""Запуск кастомних скриптів з data/scripts/."""
import subprocess, os, sys, time, json
from pathlib import Path

D = Path(__file__).resolve().parent
SCRIPTS = D / "data" / "scripts"
LOGS = D / "data" / "logs"

def list_scripts():
    return sorted(SCRIPTS.glob("*.sh")) + sorted(SCRIPTS.glob("*.py"))

def run(name, args=None, timeout=300):
    p = None
    for ext in (".sh", ".py"):
        cand = SCRIPTS / (name + ext if not name.endswith(ext) else name)
        if cand.exists(): p = cand; break
    if not p: return False, f"скрипт не знайдено: {name}"
    cmd = (["bash", str(p)] if p.suffix == ".sh" else ["python3", str(p)])
    if args: cmd.extend(args)
    t0 = time.time()
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        dur = time.time() - t0
        log = {"name": name, "at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
               "dur": round(dur, 2), "rc": r.returncode,
               "stdout": r.stdout[-2000:], "stderr": r.stderr[-1000:]}
        LOGS.mkdir(exist_ok=True)
        with open(LOGS / "runs.jsonl", "a") as f:
            f.write(json.dumps(log) + "\n")
        return r.returncode == 0, r.stdout + r.stderr
    except subprocess.TimeoutExpired:
        return False, "timeout"
    except Exception as e:
        return False, str(e)

def recent(n=20):
    p = LOGS / "runs.jsonl"
    if not p.exists(): return []
    out = []
    for line in p.read_text().splitlines()[-n:]:
        try: out.append(json.loads(line))
        except Exception: pass
    return out

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "list"
    if cmd == "list":
        for s in list_scripts():
            print(f"  {s.stem:30s} {s.stat().st_size:>6}B  {s.name}")
    elif cmd == "run":
        name = sys.argv[2]
        args = sys.argv[3:] if len(sys.argv) > 3 else None
        ok, out = run(name, args)
        print(out)
        sys.exit(0 if ok else 1)
