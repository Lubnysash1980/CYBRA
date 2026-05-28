#!/data/data/com.termux/files/usr/bin/bash
set -e

mkdir -p supervisors logs/supervisor posts proofs

cat > supervisors/self_healing_supervisor.py <<'PY'
import json, time, subprocess, hashlib
from pathlib import Path

BASE = Path.home() / "CYBRA"
POSTS = BASE / "posts"
PROOFS = BASE / "proofs"
LOGS = BASE / "logs/supervisor"
POSTS.mkdir(exist_ok=True)
PROOFS.mkdir(exist_ok=True)
LOGS.mkdir(parents=True, exist_ok=True)

def run(cmd):
    try:
        p = subprocess.run(cmd, cwd=BASE, shell=True, text=True, capture_output=True, timeout=20)
        return {"ok": p.returncode == 0, "code": p.returncode, "out": p.stdout[-2000:], "err": p.stderr[-2000:]}
    except Exception as e:
        return {"ok": False, "code": -1, "out": "", "err": str(e)}

checks = {}

checks["redis"] = run("redis-cli ping")
checks["worker"] = run("pgrep -f parliament_executor_v6.py")
checks["queue"] = run("cybra status")
checks["failed"] = run("redis-cli llen cybra:parliament:failed")
checks["retry"] = run("redis-cli llen cybra:parliament:retry")
checks["pages_files"] = run("test -f index.html && test -f .nojekyll")
checks["git_status"] = run("git status --short | head -40")

actions = []

if not checks["redis"]["ok"]:
    actions.append("start_redis")
    run("redis-server --daemonize yes")

if not checks["worker"]["ok"]:
    actions.append("restart_worker")
    run("bash cybra_worker_start.sh")

failed_n = 0
retry_n = 0
try:
    failed_n = int(checks["failed"]["out"].strip() or "0")
    retry_n = int(checks["retry"]["out"].strip() or "0")
except Exception:
    pass

if failed_n > 0 or retry_n > 0:
    actions.append("submit_autofix_task")
    run("""cybra parliament '{"topic":"Self-Healing Supervisor Autofix","type":"cybra_autofix_task","payload":{"goal":"repair failed/retry queue and missing mappings"},"priority":"critical"}'""")

if not checks["pages_files"]["ok"]:
    actions.append("repair_pages_root")
    run("""cat > index.html <<'HTML'
<!doctype html><html><head><meta charset="utf-8"><title>CYBRA LIVE</title></head><body><h1>CYBRA LIVE</h1></body></html>
HTML
touch .nojekyll
git add index.html .nojekyll
git commit -m 'self heal pages root files' || true
git push || true
""")

report = {
    "time": time.time(),
    "status": "ok",
    "checks": checks,
    "actions": actions,
    "rules": [
        "detect failures",
        "restart workers",
        "start redis",
        "submit autofix task",
        "repair pages root",
        "write proofs"
    ]
}

raw = json.dumps(report, ensure_ascii=False, indent=2)
(LOGS / "latest_supervisor_report.json").write_text(raw, encoding="utf-8")

sha = hashlib.sha256(raw.encode()).hexdigest()
(PROOFS / "self_healing_supervisor.sha256").write_text(sha, encoding="utf-8")

md = f"""# CYBRA Self-Healing Supervisor

Status: active

Actions taken:
{chr(10).join('- ' + a for a in actions) if actions else '- none'}

Failed queue: {failed_n}
Retry queue: {retry_n}

Proof:
{sha}
"""
(POSTS / "self_healing_supervisor_status.md").write_text(md, encoding="utf-8")

print(raw)
PY

python3 supervisors/self_healing_supervisor.py

git add supervisors posts/self_healing_supervisor_status.md proofs/self_healing_supervisor.sha256 cybra_self_healing_supervisor.sh
git commit -m "add self-healing worker supervisor" || true

echo "✅ Self-healing supervisor installed"
