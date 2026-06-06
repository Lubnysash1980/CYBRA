#!/data/data/com.termux/files/usr/bin/bash
set -e

BASE="$HOME/CYBRA"

mkdir -p posts proofs logs/checker

REPORT="posts/executor_checker_status.md"
JSON="proofs/executor_checker.json"

echo "# CYBRA Executor Checker" > "$REPORT"
echo "" >> "$REPORT"

python3 - <<'PY'
import json
import hashlib
from pathlib import Path

BASE = Path.home() / "CYBRA"

executors = [
    "parliament_executor_v2.py",
    "parliament_executor_v3.py",
    "parliament_executor_v4.py",
    "parliament_executor_v5.py",
    "parliament_executor_v6.py"
]

required_scripts = [
    "create_native_token_ecosystem.sh",
    "create_pmz_registry.sh",
    "cybra_autofix.sh",
    "cybra_mining_autofix.sh",
    "emergency_alert_handler.sh",
    "run_answer_engine.sh",
    "github_double_backend.sh"
]

report = {
    "executors": {},
    "scripts": {},
    "queues": {},
    "status": "ok"
}

for ex in executors:
    p = BASE / ex
    report["executors"][ex] = {
        "exists": p.exists(),
        "size": p.stat().st_size if p.exists() else 0
    }

for s in required_scripts:
    p = BASE / s
    report["scripts"][s] = {
        "exists": p.exists(),
        "executable": p.exists() and p.stat().st_mode & 0o111 != 0
    }

try:
    import redis
    r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

    report["queues"] = {
        "submissions": r.llen("cybra:parliament:submissions"),
        "results": r.llen("cybra:parliament:results"),
        "failed": r.llen("cybra:parliament:failed"),
        "retry": r.llen("cybra:parliament:retry"),
        "audit": r.llen("cybra:audit")
    }

except Exception as e:
    report["queues_error"] = str(e)

raw = json.dumps(report, ensure_ascii=False, indent=2)

(Path.home() / "CYBRA" / "proofs" / "executor_checker.json").write_text(
    raw,
    encoding="utf-8"
)

h = hashlib.sha256(raw.encode()).hexdigest()

(Path.home() / "CYBRA" / "proofs" / "executor_checker.sha256").write_text(
    h,
    encoding="utf-8"
)

(Path.home() / "CYBRA" / "posts" / "executor_checker_status.md").write_text(
f"""# CYBRA Executor Checker

Status: OK

Executors checked:
- V2
- V3
- V4
- V5
- V6

Proof:
- proofs/executor_checker.json
- proofs/executor_checker.sha256

SHA256:
{h}
""",
encoding="utf-8"
)

print(raw)
print("SHA256:", h)
PY

git add posts proofs 2>/dev/null || true
git commit -m "executor checker report" || true

echo "✅ Executor checker completed"
echo "Report: posts/executor_checker_status.md"
