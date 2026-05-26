#!/data/data/com.termux/files/usr/bin/bash
set -e

redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes
sleep 1

mkdir -p posts proofs logs/quality

python3 - <<'PY'
import redis, json, hashlib, time
from pathlib import Path

r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

RESULTS = "cybra:parliament:results"
FAILED = "cybra:parliament:failed"
RETRY = "cybra:parliament:retry"
SUBMISSIONS = "cybra:parliament:submissions"

issues = []
repair_tasks = []

def dsha(x):
    first = hashlib.sha256(x.encode()).digest()
    return hashlib.sha256(first).hexdigest()

def add_repair(topic, issue_type, original=None):
    task = {
        "topic": f"AutoFix: {topic}",
        "type": "cybra_autofix_task",
        "payload": {
            "issue_type": issue_type,
            "original": original,
            "goal": "автоматично виправити помилку executor/mapping/script/retry"
        },
        "priority": "critical"
    }
    raw = json.dumps(task, ensure_ascii=False)
    r.lpush(SUBMISSIONS, raw)
    repair_tasks.append(task)

for raw in r.lrange(RESULTS, 0, 50):
    try:
        obj = json.loads(raw)
        status = obj.get("status")
        topic = obj.get("topic", "unknown")

        if status in ["execution_failed", "no_executor_mapping", "processed_no_executor_mapping"]:
            issues.append(obj)
            add_repair(topic, status, obj)

    except Exception:
        issues.append({"raw": raw, "error": "bad_result_json"})
        add_repair("bad_result_json", "bad_json", raw)

for raw in r.lrange(FAILED, 0, 50):
    issues.append({"queue": "failed", "raw": raw})
    add_repair("failed_queue_item", "failed_queue", raw)

report = {
    "time": time.time(),
    "checked_results": min(50, r.llen(RESULTS)),
    "failed_count": r.llen(FAILED),
    "retry_count": r.llen(RETRY),
    "issues_found": len(issues),
    "repair_tasks_created": len(repair_tasks),
    "issues": issues[:20]
}

Path("proofs/executor_quality_report.json").write_text(
    json.dumps(report, ensure_ascii=False, indent=2),
    encoding="utf-8"
)

Path("proofs/executor_quality_report.sha256").write_text(
    dsha(json.dumps(report, ensure_ascii=False)),
    encoding="utf-8"
)

Path("posts/executor_quality_status.md").write_text(
f"""# CYBRA Executor Quality Check

Issues found: {len(issues)}
Repair tasks created: {len(repair_tasks)}

Queues:
- failed: {r.llen(FAILED)}
- retry: {r.llen(RETRY)}

Proof:
- proofs/executor_quality_report.json
- proofs/executor_quality_report.sha256
""",
encoding="utf-8"
)

print(json.dumps(report, ensure_ascii=False, indent=2))
PY

git add posts proofs executor_quality_autofix.sh 2>/dev/null || true
git commit -m "executor quality autofix routing" || true

echo "✅ Executor quality check completed"
echo "Report: posts/executor_quality_status.md"
