#!/data/data/com.termux/files/usr/bin/bash
set -e

cd "$HOME/CYBRA"

mkdir -p posts feeds proofs logs/statistics

redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes
sleep 1

python3 - <<'PY'
import json
import time
import hashlib
import subprocess
from pathlib import Path
from collections import Counter

import redis

r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)
r.ping()

TASK_RESULT_KEYS = [
    "cybra:parliament:results",
    "cybra:results",
    "cybra:parliament:failed",
    "cybra:review:approved",
    "cybra:review:rejected",
    "cybra:review:hold"
]

EVENT_KEYS = [
    "cybra:revision:audit",
    "cybra:analytics:audit",
    "cybra:statistics:audit",
    "cybra:review:audit"
]

HASH_AUDIT_KEY = "cybra:audit"

def load_json(raw, source_key):
    try:
        obj = json.loads(raw)
        if isinstance(obj, dict):
            obj["_source_key"] = source_key
            return obj
        return {"status": "raw_unparsed", "raw": raw, "_source_key": source_key}
    except Exception:
        return {"status": "raw_unparsed", "raw": raw, "_source_key": source_key}

def double_sha(text: str) -> str:
    h1 = hashlib.sha256(text.encode("utf-8")).hexdigest()
    return hashlib.sha256(h1.encode("utf-8")).hexdigest()

def git_cmd(cmd):
    try:
        return subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return ""

task_results = []
for key in TASK_RESULT_KEYS:
    for raw in r.lrange(key, 0, 499):
        task_results.append(load_json(raw, key))

event_results = []
for key in EVENT_KEYS:
    for raw in r.lrange(key, 0, 499):
        event_results.append(load_json(raw, key))

statuses = Counter(str(x.get("status", "unknown")) for x in task_results)
types = Counter(str(x.get("type", "unknown")) for x in task_results)
topics = Counter(str(x.get("topic", "unknown")) for x in task_results)
scripts = Counter(str(x.get("script") or x.get("cmd") or "none") for x in task_results)
sources = Counter(str(x.get("_source_key", "unknown")) for x in task_results)

event_statuses = Counter(str(x.get("status", "unknown")) for x in event_results)

latest = []
for item in task_results[:10]:
    latest.append({
        "source": item.get("_source_key"),
        "topic": item.get("topic"),
        "type": item.get("type"),
        "status": item.get("status"),
        "script": item.get("script") or item.get("cmd"),
        "time": item.get("time"),
        "double_sha": item.get("double_sha") or item.get("hash") or item.get("raw_double_sha")
    })

queue_state = {
    "parliament_queue": r.llen("cybra:parliament:queue"),
    "parliament_results": r.llen("cybra:parliament:results"),
    "legacy_results": r.llen("cybra:results"),
    "parliament_failed": r.llen("cybra:parliament:failed"),
    "audit_hashes": r.llen(HASH_AUDIT_KEY),
    "review_incoming": r.llen("cybra:review:incoming"),
    "review_approved": r.llen("cybra:review:approved"),
    "review_hold": r.llen("cybra:review:hold"),
    "review_rejected": r.llen("cybra:review:rejected"),
    "review_audit": r.llen("cybra:review:audit"),
    "revision_audit": r.llen("cybra:revision:audit"),
    "analytics_audit": r.llen("cybra:analytics:audit"),
    "education_audit": r.llen("cybra:education:audit"),
    "statistics_audit": r.llen("cybra:statistics:audit")
}

mapping = r.hgetall("cybra:executor:mapping")

report = {
    "name": "CYBRA Task Statistics",
    "status": "generated",
    "time": time.time(),
    "git": {
        "branch": git_cmd(["git", "branch", "--show-current"]),
        "commit": git_cmd(["git", "rev-parse", "--short", "HEAD"]),
        "dirty_files": len(git_cmd(["git", "status", "--short"]).splitlines())
    },
    "queue_state": queue_state,
    "summary": {
        "checked_task_results": len(task_results),
        "checked_events": len(event_results),
        "audit_hashes": queue_state["audit_hashes"],
        "executed": statuses.get("executed", 0),
        "no_executor_mapping": statuses.get("no_executor_mapping", 0),
        "failed_or_error": statuses.get("failed", 0) + statuses.get("error", 0),
        "reviewed": statuses.get("reviewed", 0),
        "executor_mapping_count": len(mapping)
    },
    "task_statuses": dict(statuses),
    "task_types": dict(types),
    "task_sources": dict(sources),
    "event_statuses": dict(event_statuses),
    "topics_top": dict(topics.most_common(20)),
    "scripts": dict(scripts),
    "latest_task_results": latest,
    "executor_mapping": mapping
}

report["double_sha"] = double_sha(json.dumps(report, ensure_ascii=False, sort_keys=True))

Path("feeds/task_statistics.json").write_text(json.dumps(report, ensure_ascii=False, indent=2))

def lines(data):
    if not data:
        return "- none"
    return "\n".join(f"- `{k}`: {v}" for k, v in sorted(data.items(), key=lambda x: x[1], reverse=True))

latest_md = ""
for item in latest:
    latest_md += (
        f"- `{item.get('status')}` / `{item.get('type')}` — "
        f"{item.get('topic')} / script: `{item.get('script')}` / source: `{item.get('source')}`\n"
    )

md = f"""# CYBRA Task Statistics

Status: generated  
Double SHA: `{report["double_sha"]}`

## Summary

- Checked task results: {report["summary"]["checked_task_results"]}
- Checked event/audit records: {report["summary"]["checked_events"]}
- Audit hashes: {report["summary"]["audit_hashes"]}
- Executed: {report["summary"]["executed"]}
- No executor mapping: {report["summary"]["no_executor_mapping"]}
- Failed/Error: {report["summary"]["failed_or_error"]}
- Reviewed: {report["summary"]["reviewed"]}
- Executor mapping count: {report["summary"]["executor_mapping_count"]}

## Queue state

- parliament_queue: {queue_state["parliament_queue"]}
- parliament_results: {queue_state["parliament_results"]}
- legacy_results: {queue_state["legacy_results"]}
- parliament_failed: {queue_state["parliament_failed"]}
- audit_hashes: {queue_state["audit_hashes"]}
- review_incoming: {queue_state["review_incoming"]}
- review_approved: {queue_state["review_approved"]}
- review_hold: {queue_state["review_hold"]}
- review_rejected: {queue_state["review_rejected"]}
- review_audit: {queue_state["review_audit"]}
- revision_audit: {queue_state["revision_audit"]}
- analytics_audit: {queue_state["analytics_audit"]}
- education_audit: {queue_state["education_audit"]}
- statistics_audit: {queue_state["statistics_audit"]}

## Task statuses

{lines(report["task_statuses"])}

## Task types

{lines(report["task_types"])}

## Result sources

{lines(report["task_sources"])}

## Event statuses

{lines(report["event_statuses"])}

## Scripts / handlers

{lines(report["scripts"])}

## Top topics

{lines(report["topics_top"])}

## Latest 10 task results

{latest_md}
"""

Path("posts/task_statistics.md").write_text(md)

with open("proofs/task_statistics.sha256", "w") as proof:
    subprocess.run(
        ["sha256sum", "feeds/task_statistics.json", "posts/task_statistics.md"],
        stdout=proof,
        stderr=subprocess.DEVNULL
    )

r.lpush("cybra:statistics:audit", json.dumps({
    "status": "statistics_generated",
    "time": report["time"],
    "double_sha": report["double_sha"],
    "checked_task_results": report["summary"]["checked_task_results"],
    "executed": report["summary"]["executed"],
    "no_executor_mapping": report["summary"]["no_executor_mapping"]
}, ensure_ascii=False))

print("✅ CYBRA task statistics generated")
print("Report: posts/task_statistics.md")
print("Feed: feeds/task_statistics.json")
print("Proof: proofs/task_statistics.sha256")
PY

echo
echo "=== CYBRA TASK STATISTICS ==="
cat posts/task_statistics.md
