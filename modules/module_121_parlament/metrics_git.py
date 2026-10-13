#!/usr/bin/env python3
"""Git-історія метрик: baseline + тренд у репо."""
import json, os, subprocess, time
from pathlib import Path

D = Path(__file__).resolve().parent
H = Path.home() / "CYBRA"
REPO = D / "data" / "metrics_git"

def _run(cmd, cwd=None, timeout=30):
    try:
        r = subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True,
                           text=True, timeout=timeout)
        return r.returncode, (r.stdout + r.stderr).strip()
    except Exception as e: return 1, str(e)

def _ensure():
    REPO.mkdir(parents=True, exist_ok=True)
    if not (REPO/".git").exists():
        _run("git init -q", cwd=REPO)
        _run("git config user.email metrics@cybra.local", cwd=REPO)
        _run("git config user.name 'CYBRA Metrics'", cwd=REPO)
    (REPO/".gitignore").write_text("*.tmp\n")

def commit_snapshot(metrics, tag=None):
    """Комітить метрики. Один файл на день + індекс."""
    _ensure()
    day = time.strftime("%Y-%m-%d")
    tf = REPO / f"metrics_{day}.jsonl"
    with open(tf, "a") as f:
        f.write(json.dumps(metrics, ensure_ascii=False) + "\n")
    # індекс з baseline
    baseline_file = D / "data" / "evolve" / "baseline.json"
    if baseline_file.exists():
        try:
            b = json.loads(baseline_file.read_text())
            (REPO/"baseline.json").write_text(json.dumps(b, indent=2))
        except Exception: pass
    _run("git add -A", cwd=REPO)
    ts = time.strftime("%Y-%m-%d %H:%M:%S")
    msg = tag or f"metrics {ts}"
    _run(f'git commit -q -m "{msg}" --allow-empty', cwd=REPO)
    # optional remote push
    rc, rem = _run("git remote -v", cwd=REPO)
    if rem.strip():
        _run("git push -q origin HEAD 2>&1", cwd=REPO, timeout=60)
    return True, day

def log(n=20):
    _ensure()
    rc, out = _run(f"git log --oneline -{n}", cwd=REPO)
    return out.splitlines()

def trend(metric, days=30):
    """Дістати всі значення метрики з усіх metrics_*.jsonl."""
    _ensure()
    vals = []
    cutoff = time.time() - days*86400
    for f in sorted(REPO.glob("metrics_*.jsonl")):
        for line in f.read_text().splitlines():
            try: e = json.loads(line)
            except Exception: continue
            if e.get("ts_unix",0) < cutoff: continue
            if metric in e and e[metric] is not None:
                vals.append({"ts": e["ts"], "v": e[metric]})
    return vals

def set_remote(url):
    _ensure()
    _run(f"git remote remove origin 2>/dev/null", cwd=REPO)
    rc, out = _run(f"git remote add origin {url}", cwd=REPO)
    if rc != 0: return False, out
    _run("git branch -M main", cwd=REPO)
    rc, out = _run("git push -u origin main", cwd=REPO, timeout=120)
    return rc == 0, out[:200]

def remote_info():
    _ensure()
    rc, out = _run("git remote -v", cwd=REPO)
    return out

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "log"
    if cmd == "log":
        for l in log(30): print(f"  {l}")
    elif cmd == "trend":
        if len(sys.argv) < 3: print("usage: metrics_git.py trend <metric>"); exit(1)
        G='\033[32m'; D_='\033[2m'; N='\033[0m'
        v = trend(sys.argv[2])
        if not v: print("  (порожньо)"); exit(0)
        print(f"\n  {sys.argv[2]} ({len(v)} точок)\n")
        mx = max(x["v"] for x in v) if v else 1
        for x in v[-20:]:
            bar = "█" * max(1, int(x["v"]/mx*40))
            print(f"  {x['ts'][:19]}  {G}{bar}{N} {x['v']}")
    elif cmd == "remote":
        if len(sys.argv) < 3: print(remote_info()); exit(0)
        ok, m = set_remote(sys.argv[2]); print(("✓ " if ok else "✗ ")+m)
    elif cmd == "snapshot":
        import metrics as M
        m = M.collect()
        ok, day = commit_snapshot(m, tag="manual")
        print(f"✓ snapshot {day}")
