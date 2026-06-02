#!/data/data/com.termux/files/usr/bin/bash
set -e

cd "$HOME/CYBRA"

MODE="${1:-report}"

mkdir -p posts feeds proofs logs/diagnostics

redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes
sleep 1

python3 - <<'PY' >/dev/null 2>&1 || python3 -m pip install redis
import redis
PY

run_report() {
python3 - <<'PY'
import json
import time
import hashlib
import subprocess
from pathlib import Path
from collections import Counter, defaultdict

import redis

r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)
r.ping()

RESULT_KEYS = [
    "cybra:parliament:results",
    "cybra:parliament:failed",
    "cybra:review:approved",
    "cybra:review:hold",
    "cybra:review:rejected",
    "cybra:evolution:approved",
    "cybra:evolution:hold",
    "cybra:evolution:rejected"
]

QUEUE_KEYS = {
    "parliament_queue": "cybra:parliament:queue",
    "parliament_results": "cybra:parliament:results",
    "parliament_failed": "cybra:parliament:failed",
    "review_incoming": "cybra:review:incoming",
    "review_approved": "cybra:review:approved",
    "review_hold": "cybra:review:hold",
    "review_rejected": "cybra:review:rejected",
    "evolution_approved": "cybra:evolution:approved",
    "evolution_hold": "cybra:evolution:hold",
    "evolution_rejected": "cybra:evolution:rejected",
    "audit_hashes": "cybra:audit",
    "structured_audit": "cybra:audit:structured",
    "statistics_audit": "cybra:statistics:audit",
    "revision_audit": "cybra:revision:audit",
    "analytics_audit": "cybra:analytics:audit"
}

def load_json(raw, source):
    try:
        obj = json.loads(raw)
        if isinstance(obj, dict):
            obj["_source_key"] = source
            return obj
    except Exception:
        pass
    return {
        "status": "raw_unparsed",
        "raw": raw,
        "_source_key": source
    }

def double_sha(text):
    h1 = hashlib.sha256(text.encode("utf-8")).hexdigest()
    return hashlib.sha256(h1.encode("utf-8")).hexdigest()

def git_cmd(cmd):
    try:
        return subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return ""

items = []
for key in RESULT_KEYS:
    for raw in r.lrange(key, 0, 499):
        items.append(load_json(raw, key))

mapping = r.hgetall("cybra:executor:mapping")

statuses = Counter(str(x.get("status", "unknown")) for x in items)
types = Counter(str(x.get("type", "unknown")) for x in items)
scripts = Counter(str(x.get("script") or x.get("cmd") or "none") for x in items)
sources = Counter(str(x.get("_source_key", "unknown")) for x in items)
topics = Counter(str(x.get("topic", "unknown")) for x in items)

executed = []
not_executed = []
old_no_mapping_fixed = []
still_missing_mapping = []
handler_missing_files = []
failed_or_error = []
review_rejected = []
review_hold = []
evolution_hold = []
evolution_rejected = []

for item in items:
    status = str(item.get("status", "unknown"))
    task_type = str(item.get("type", "unknown"))
    source = str(item.get("_source_key", ""))

    if status == "executed":
        executed.append(item)

        script = item.get("script")
        if script and isinstance(script, str):
            if not Path(script).exists():
                handler_missing_files.append({
                    "type": task_type,
                    "script": script,
                    "topic": item.get("topic"),
                    "problem": "mapped/executed script file is missing now"
                })

        execution = item.get("execution") or {}
        rc = execution.get("returncode", 0)
        if rc not in (0, "0", None):
            failed_or_error.append(item)

    elif status == "no_executor_mapping":
        not_executed.append(item)

        if task_type in mapping:
            old_no_mapping_fixed.append({
                "type": task_type,
                "topic": item.get("topic"),
                "current_handler": mapping.get(task_type),
                "status": "historical_error_but_mapping_exists_now"
            })
        else:
            still_missing_mapping.append({
                "type": task_type,
                "topic": item.get("topic"),
                "status": "still_missing_mapping",
                "suggested_action": f"bash cybra_redis_executor_mapping.sh set {task_type} <handler.sh>"
            })

    elif status in ("failed", "error"):
        failed_or_error.append(item)
        not_executed.append(item)

    if source == "cybra:review:rejected":
        review_rejected.append(item)
    if source == "cybra:review:hold":
        review_hold.append(item)
    if source == "cybra:evolution:hold":
        evolution_hold.append(item)
    if source == "cybra:evolution:rejected":
        evolution_rejected.append(item)

queue_state = {
    name: r.llen(key)
    for name, key in QUEUE_KEYS.items()
}

recommendations = []

if queue_state["parliament_queue"] > 0:
    recommendations.append({
        "level": "important",
        "what": "У черзі виконання є задачі.",
        "do": "Запусти: cybra worker-start && sleep 5 && cybra status"
    })

if still_missing_mapping:
    recommendations.append({
        "level": "critical",
        "what": "Є типи задач без executor mapping.",
        "do": "Створити handler-и або додати mapping через Redis.",
        "types": sorted(set(x["type"] for x in still_missing_mapping))
    })

if old_no_mapping_fixed:
    recommendations.append({
        "level": "ok",
        "what": "Частина no_executor_mapping — це стара історія. Зараз mapping уже є.",
        "do": "Не страшно. Старі записи лишити як audit або очистити окремо."
    })

if handler_missing_files:
    recommendations.append({
        "level": "warning",
        "what": "Є mapping/script, але файл handler-а зараз не знайдено.",
        "do": "Відновити handler-файл або змінити Redis mapping.",
        "items": handler_missing_files[:10]
    })

if review_rejected:
    recommendations.append({
        "level": "review",
        "what": "Є задачі, відхилені review-органом.",
        "do": "Подивись: bash cybra_review.sh rejected"
    })

if evolution_hold:
    recommendations.append({
        "level": "evolution",
        "what": "Є задачі на evolution hold.",
        "do": "Перевірити, чому Evolution Guard не пропустив їх далі."
    })

if not recommendations:
    recommendations.append({
        "level": "ok",
        "what": "Критичних проблем по тасках не знайдено.",
        "do": "Продовжувати тестування."
    })

latest = []
for item in items[:15]:
    execution = item.get("execution") or {}
    stdout = str(execution.get("stdout", ""))[:220].replace("\n", " ")
    stderr = str(execution.get("stderr", ""))[:220].replace("\n", " ")

    latest.append({
        "source": item.get("_source_key"),
        "topic": item.get("topic"),
        "type": item.get("type"),
        "status": item.get("status"),
        "script": item.get("script") or item.get("cmd"),
        "returncode": execution.get("returncode"),
        "stdout_preview": stdout,
        "stderr_preview": stderr,
        "time": item.get("time"),
        "double_sha": item.get("double_sha") or item.get("hash") or item.get("raw_double_sha")
    })

report = {
    "name": "CYBRA Task Test Diagnostics",
    "status": "generated",
    "time": time.time(),
    "git": {
        "branch": git_cmd(["git", "branch", "--show-current"]),
        "commit": git_cmd(["git", "rev-parse", "--short", "HEAD"]),
        "dirty_files": len(git_cmd(["git", "status", "--short"]).splitlines())
    },
    "summary": {
        "checked_records": len(items),
        "executed": len(executed),
        "not_executed": len(not_executed),
        "still_missing_mapping": len(still_missing_mapping),
        "old_no_mapping_fixed_now": len(old_no_mapping_fixed),
        "failed_or_error": len(failed_or_error),
        "review_rejected": len(review_rejected),
        "review_hold": len(review_hold),
        "evolution_hold": len(evolution_hold),
        "evolution_rejected": len(evolution_rejected),
        "executor_mapping_count": len(mapping)
    },
    "queue_state": queue_state,
    "statuses": dict(statuses),
    "types": dict(types),
    "scripts": dict(scripts),
    "sources": dict(sources),
    "topics_top": dict(topics.most_common(20)),
    "still_missing_mapping": still_missing_mapping,
    "old_no_mapping_fixed_now": old_no_mapping_fixed,
    "handler_missing_files": handler_missing_files,
    "failed_or_error_items": failed_or_error[:20],
    "review_rejected_items": review_rejected[:20],
    "evolution_hold_items": evolution_hold[:20],
    "latest": latest,
    "recommendations": recommendations,
    "executor_mapping": mapping
}

report["double_sha"] = double_sha(json.dumps(report, ensure_ascii=False, sort_keys=True))

Path("feeds/task_diagnostics_report.json").write_text(
    json.dumps(report, ensure_ascii=False, indent=2),
    encoding="utf-8"
)

def lines(data):
    if not data:
        return "- none"
    return "\n".join(
        f"- `{k}`: {v}"
        for k, v in sorted(data.items(), key=lambda x: x[1], reverse=True)
    )

missing_md = ""
for x in still_missing_mapping:
    missing_md += f"- `{x['type']}` — {x.get('topic')} → {x['suggested_action']}\n"
if not missing_md:
    missing_md = "- none\n"

fixed_md = ""
for x in old_no_mapping_fixed:
    fixed_md += f"- `{x['type']}` — {x.get('topic')} → now mapped to `{x.get('current_handler')}`\n"
if not fixed_md:
    fixed_md = "- none\n"

latest_md = ""
for x in latest:
    latest_md += (
        f"- `{x.get('status')}` / `{x.get('type')}` — {x.get('topic')} "
        f"/ script: `{x.get('script')}` / source: `{x.get('source')}`\n"
    )

rec_md = ""
for x in recommendations:
    rec_md += f"- **{x.get('level')}**: {x.get('what')} Action: `{x.get('do')}`\n"

md = f"""# CYBRA Task Test Diagnostics

Status: generated  
Double SHA: `{report["double_sha"]}`

## Summary

- Checked records: {report["summary"]["checked_records"]}
- Executed: {report["summary"]["executed"]}
- Not executed: {report["summary"]["not_executed"]}
- Still missing mapping: {report["summary"]["still_missing_mapping"]}
- Old no-mapping already fixed now: {report["summary"]["old_no_mapping_fixed_now"]}
- Failed/Error: {report["summary"]["failed_or_error"]}
- Review rejected: {report["summary"]["review_rejected"]}
- Review hold: {report["summary"]["review_hold"]}
- Evolution hold: {report["summary"]["evolution_hold"]}
- Evolution rejected: {report["summary"]["evolution_rejected"]}
- Executor mapping count: {report["summary"]["executor_mapping_count"]}

## Queue state

- parliament_queue: {queue_state["parliament_queue"]}
- parliament_results: {queue_state["parliament_results"]}
- parliament_failed: {queue_state["parliament_failed"]}
- review_incoming: {queue_state["review_incoming"]}
- review_approved: {queue_state["review_approved"]}
- review_hold: {queue_state["review_hold"]}
- review_rejected: {queue_state["review_rejected"]}
- evolution_approved: {queue_state["evolution_approved"]}
- evolution_hold: {queue_state["evolution_hold"]}
- evolution_rejected: {queue_state["evolution_rejected"]}

## Statuses

{lines(report["statuses"])}

## Task types

{lines(report["types"])}

## Scripts / handlers

{lines(report["scripts"])}

## Sources

{lines(report["sources"])}

## Still missing mapping

{missing_md}

## Old no-mapping but fixed now

{fixed_md}

## Recommendations

{rec_md}

## Latest records

{latest_md}
"""

Path("posts/task_diagnostics_report.md").write_text(md, encoding="utf-8")

with open("proofs/task_diagnostics_report.sha256", "w") as f:
    subprocess.run(
        [
            "sha256sum",
            "feeds/task_diagnostics_report.json",
            "posts/task_diagnostics_report.md"
        ],
        stdout=f,
        stderr=subprocess.DEVNULL
    )

print("✅ CYBRA task diagnostics generated")
print("Report: posts/task_diagnostics_report.md")
print("Feed: feeds/task_diagnostics_report.json")
print("Proof: proofs/task_diagnostics_report.sha256")
print()
print(md)
PY
}

run_tests() {
python3 - <<'PY'
import json
import time
import subprocess
from pathlib import Path

import redis

r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)
r.ping()

mapping = r.hgetall("cybra:executor:mapping")

tests = [
    ("air_alert_task", "CYBRA Test: Air Alert Handler"),
    ("revision_organ_task", "CYBRA Test: Revision Organ"),
    ("analytics_committee_task", "CYBRA Test: Analytics Committee"),
    ("audit_dedupe_test_task", "CYBRA Test: Audit Dedupe"),
    ("evolution_guard_task", "CYBRA Test: Evolution Guard"),
    ("closed_evolution_selfseal_task", "CYBRA Test: Closed Self-Seal"),
    ("biometric_succession_task", "CYBRA Test: Succession Guard")
]

submitted = []

for task_type, topic in tests:
    handler = mapping.get(task_type)

    if not handler:
        continue

    if isinstance(handler, str) and handler.endswith(".sh") and not Path(handler).exists():
        continue

    task = {
        "topic": topic,
        "type": task_type,
        "priority": "normal",
        "payload": {
            "mode": "diagnostic_test",
            "goal": "audit proof revision analytics development safety stability",
            "diagnostic_run": int(time.time())
        }
    }

    raw = json.dumps(task, ensure_ascii=False)

    if Path("cybra_submit_guarded.py").exists():
        subprocess.run(
            ["python3", "cybra_submit_guarded.py", "submit", raw, "--force"],
            text=True
        )
    else:
        r.lpush("cybra:parliament:queue", raw)

    submitted.append({
        "type": task_type,
        "topic": topic,
        "handler": handler
    })

print("✅ submitted diagnostic tests:", len(submitted))
for x in submitted:
    print("-", x["type"], "->", x["handler"])
PY

cybra worker-start || true
sleep 8
}

case "$MODE" in
  report)
    run_report
    ;;
  test)
    run_tests
    run_report
    ;;
  status)
    echo "QUEUE: $(redis-cli LLEN cybra:parliament:queue)"
    echo "RESULTS: $(redis-cli LLEN cybra:parliament:results)"
    echo "FAILED: $(redis-cli LLEN cybra:parliament:failed)"
    echo "REVIEW_HOLD: $(redis-cli LLEN cybra:review:hold)"
    echo "REVIEW_REJECTED: $(redis-cli LLEN cybra:review:rejected)"
    echo "EVOLUTION_HOLD: $(redis-cli LLEN cybra:evolution:hold)"
    echo "EVOLUTION_REJECTED: $(redis-cli LLEN cybra:evolution:rejected)"
    echo "MAPPING: $(redis-cli HLEN cybra:executor:mapping)"
    ;;
  *)
    echo "Usage:"
    echo "  bash cybra_task_test_diagnostics.sh report"
    echo "  bash cybra_task_test_diagnostics.sh test"
    echo "  bash cybra_task_test_diagnostics.sh status"
    ;;
esac
