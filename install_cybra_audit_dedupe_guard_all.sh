#!/data/data/com.termux/files/usr/bin/bash
set -e

cd "$HOME/CYBRA"

echo "=== CYBRA AUDIT DEDUPE GUARD INSTALL START ==="

mkdir -p parliament/audit posts feeds proofs logs/audit handlers

redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes
sleep 1
redis-cli ping >/dev/null

python3 - <<'PY' >/dev/null 2>&1 || python3 -m pip install redis
import redis
PY

cat > parliament/audit/audit_dedupe_policy.json <<'JSON'
{
  "name": "CYBRA Audit Dedupe Tagging Guard",
  "version": "1.0",
  "status": "active",
  "purpose": "Перевіряти задачі Кіберапарламенту перед виконанням, не допускати дублікати, додавати audit, tags, fingerprint і double SHA.",
  "redis_keys": {
    "queue": "cybra:parliament:queue",
    "results": "cybra:parliament:results",
    "dedupe_set": "cybra:dedupe:fingerprints",
    "fingerprints": "cybra:audit:fingerprints",
    "structured_audit": "cybra:audit:structured",
    "duplicates": "cybra:dedupe:duplicates",
    "tag_index": "cybra:audit:tags"
  },
  "rules": {
    "duplicate_policy": "block_duplicate_by_fingerprint",
    "force_allowed": true,
    "force_requires_cli_flag": "--force",
    "no_private_keys": true,
    "no_secret_dump": true,
    "no_runtime_env_in_git": true,
    "tag_every_task": true,
    "double_sha_every_task": true
  }
}
JSON

cat > cybra_submit_guarded.py <<'PY'
#!/usr/bin/env python3
import json
import time
import hashlib
import sys
import re
from pathlib import Path

import redis

r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

QUEUE = "cybra:parliament:queue"
DEDUPE_SET = "cybra:dedupe:fingerprints"
FINGERPRINTS = "cybra:audit:fingerprints"
STRUCTURED_AUDIT = "cybra:audit:structured"
DUPLICATES = "cybra:dedupe:duplicates"
TAG_INDEX = "cybra:audit:tags"

VOLATILE_KEYS = {
    "time", "timestamp", "created_at", "updated_at",
    "_audit", "_review", "double_sha", "hash",
    "submission_id", "fingerprint"
}

def sha256(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()

def double_sha(text: str) -> str:
    h1 = sha256(text)
    return sha256(h1)

def clean_for_fingerprint(obj):
    if isinstance(obj, dict):
        return {
            str(k): clean_for_fingerprint(v)
            for k, v in sorted(obj.items())
            if str(k) not in VOLATILE_KEYS
        }
    if isinstance(obj, list):
        return [clean_for_fingerprint(x) for x in obj]
    return obj

def slug(text):
    text = str(text or "unknown").lower()
    text = re.sub(r"[^a-z0-9а-яіїєґ_ -]+", "", text, flags=re.IGNORECASE)
    text = re.sub(r"[\s-]+", "_", text)
    return text.strip("_")[:80] or "unknown"

def normalize(raw):
    task = json.loads(raw)
    if not isinstance(task, dict):
        raise ValueError("task must be JSON object")
    return task

def build_tags(task):
    topic = task.get("topic", "unknown")
    task_type = task.get("type", "unknown")
    priority = task.get("priority", "normal")
    tags = [
        "topic:" + slug(topic),
        "type:" + slug(task_type),
        "priority:" + slug(priority)
    ]

    payload = task.get("payload")
    if isinstance(payload, dict):
        mode = payload.get("mode")
        if mode:
            tags.append("mode:" + slug(mode))

    return tags

def write_status(event):
    Path("feeds").mkdir(exist_ok=True)
    Path("posts").mkdir(exist_ok=True)
    Path("proofs").mkdir(exist_ok=True)

    Path("feeds/audit_dedupe_status.json").write_text(
        json.dumps(event, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )

    md = f"""# CYBRA Audit Dedupe Guard

Status: {event.get("status")}  
Decision: {event.get("decision")}  
Topic: {event.get("topic")}  
Type: {event.get("type")}  
Fingerprint: `{event.get("fingerprint")}`  
Double SHA: `{event.get("double_sha")}`  
Time: {event.get("time_iso")}

## Tags

{chr(10).join("- `" + x + "`" for x in event.get("tags", []))}

## Message

{event.get("message", "")}
"""

    Path("posts/audit_dedupe_status.md").write_text(md, encoding="utf-8")

    import subprocess
    with open("proofs/audit_dedupe_status.sha256", "w") as f:
        subprocess.run(
            [
                "sha256sum",
                "feeds/audit_dedupe_status.json",
                "posts/audit_dedupe_status.md",
                "parliament/audit/audit_dedupe_policy.json"
            ],
            stdout=f,
            stderr=subprocess.DEVNULL
        )

def submit(raw, force=False):
    r.ping()

    task = normalize(raw)
    clean = clean_for_fingerprint(task)
    canonical = json.dumps(clean, ensure_ascii=False, sort_keys=True, separators=(",", ":"))

    fingerprint = double_sha(canonical)
    raw_double_sha = double_sha(raw)

    topic = task.get("topic")
    task_type = task.get("type")
    priority = task.get("priority", "normal")
    tags = build_tags(task)

    now = time.time()
    now_iso = time.strftime("%Y-%m-%dT%H:%M:%S%z")
    submission_id = "sub_" + fingerprint[:16] + "_" + str(int(now))

    is_new = r.sadd(DEDUPE_SET, fingerprint)

    event = {
        "status": "audit_checked",
        "time": now,
        "time_iso": now_iso,
        "topic": topic,
        "type": task_type,
        "priority": priority,
        "fingerprint": fingerprint,
        "double_sha": raw_double_sha,
        "submission_id": submission_id,
        "tags": tags,
        "force": force
    }

    if not is_new and not force:
        event.update({
            "decision": "duplicate_blocked",
            "message": "Duplicate task blocked by CYBRA dedupe guard."
        })
        r.lpush(DUPLICATES, json.dumps(event, ensure_ascii=False))
        r.lpush(STRUCTURED_AUDIT, json.dumps(event, ensure_ascii=False))
        write_status(event)
        print("⚠️ DUPLICATE BLOCKED")
        print("fingerprint:", fingerprint)
        print("Use --force only if you intentionally need repeat execution.")
        return 0

    task["_audit"] = {
        "submission_id": submission_id,
        "fingerprint": fingerprint,
        "double_sha": raw_double_sha,
        "created_at": now,
        "created_at_iso": now_iso,
        "tags": tags,
        "dedupe": "force_allowed" if force else "unique"
    }

    enriched_raw = json.dumps(task, ensure_ascii=False)

    queue_len = r.lpush(QUEUE, enriched_raw)

    record = {
        **event,
        "decision": "submitted",
        "message": "Task accepted, tagged and submitted to Parliament execution queue.",
        "queue": QUEUE,
        "queue_len": queue_len
    }

    r.hset(FINGERPRINTS, fingerprint, json.dumps(record, ensure_ascii=False))
    r.lpush(STRUCTURED_AUDIT, json.dumps(record, ensure_ascii=False))

    for tag in tags:
        r.sadd(f"{TAG_INDEX}:{tag}", fingerprint)

    write_status(record)

    print(f"(integer) {queue_len}")
    print("✅ Parliament task submitted via audit/dedupe guard")
    print("fingerprint:", fingerprint)
    print("submission_id:", submission_id)
    return 0

def main():
    if len(sys.argv) < 3 or sys.argv[1] != "submit":
        print("Usage:")
        print("  python3 cybra_submit_guarded.py submit '<json_task>'")
        print("  python3 cybra_submit_guarded.py submit '<json_task>' --force")
        return 1

    raw = sys.argv[2]
    force = "--force" in sys.argv[3:]

    try:
        return submit(raw, force=force)
    except Exception as e:
        event = {
            "status": "audit_error",
            "decision": "rejected",
            "message": str(e),
            "time": time.time(),
            "time_iso": time.strftime("%Y-%m-%dT%H:%M:%S%z")
        }
        try:
            r.lpush(STRUCTURED_AUDIT, json.dumps(event, ensure_ascii=False))
            write_status(event)
        except Exception:
            pass
        print("❌ AUDIT GUARD ERROR:", e)
        return 1

if __name__ == "__main__":
    raise SystemExit(main())
PY

chmod +x cybra_submit_guarded.py

cat > cybra_audit_dedupe.sh <<'BASH'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

CMD="${1:-status}"
shift || true

case "$CMD" in
  submit)
    python3 cybra_submit_guarded.py submit "$@"
    ;;
  status)
    redis-cli ping
    echo "QUEUE: $(redis-cli LLEN cybra:parliament:queue)"
    echo "RESULTS: $(redis-cli LLEN cybra:parliament:results)"
    echo "DEDUPE_FINGERPRINTS: $(redis-cli SCARD cybra:dedupe:fingerprints)"
    echo "FINGERPRINT_RECORDS: $(redis-cli HLEN cybra:audit:fingerprints)"
    echo "STRUCTURED_AUDIT: $(redis-cli LLEN cybra:audit:structured)"
    echo "DUPLICATES_BLOCKED: $(redis-cli LLEN cybra:dedupe:duplicates)"
    test -f posts/audit_dedupe_report.md && echo "REPORT: exists" || echo "REPORT: missing"
    ;;
  duplicates)
    redis-cli LRANGE cybra:dedupe:duplicates 0 20
    ;;
  audit)
    redis-cli LRANGE cybra:audit:structured 0 20
    ;;
  fingerprints)
    redis-cli HKEYS cybra:audit:fingerprints | head -50
    ;;
  report)
    python3 - <<'PY'
import json, time, hashlib, subprocess
from pathlib import Path
from collections import Counter
import redis

r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)
r.ping()

def load(x):
    try:
        return json.loads(x)
    except Exception:
        return {"status": "raw", "raw": x}

def dsha(text):
    h1 = hashlib.sha256(text.encode("utf-8")).hexdigest()
    return hashlib.sha256(h1.encode("utf-8")).hexdigest()

audit = [load(x) for x in r.lrange("cybra:audit:structured", 0, 499)]
dups = [load(x) for x in r.lrange("cybra:dedupe:duplicates", 0, 199)]

decisions = Counter(str(x.get("decision", "unknown")) for x in audit)
types = Counter(str(x.get("type", "unknown")) for x in audit)
topics = Counter(str(x.get("topic", "unknown")) for x in audit)

report = {
    "name": "CYBRA Audit Dedupe Report",
    "status": "generated",
    "time": time.time(),
    "summary": {
        "structured_audit": len(audit),
        "duplicates_blocked": len(dups),
        "dedupe_fingerprints": r.scard("cybra:dedupe:fingerprints"),
        "fingerprint_records": r.hlen("cybra:audit:fingerprints"),
        "queue": r.llen("cybra:parliament:queue"),
        "results": r.llen("cybra:parliament:results")
    },
    "decisions": dict(decisions),
    "types": dict(types),
    "topics_top": dict(topics.most_common(20)),
    "latest_audit": audit[:20],
    "latest_duplicates": dups[:20]
}

report["double_sha"] = dsha(json.dumps(report, ensure_ascii=False, sort_keys=True))

Path("feeds").mkdir(exist_ok=True)
Path("posts").mkdir(exist_ok=True)
Path("proofs").mkdir(exist_ok=True)

Path("feeds/audit_dedupe_report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2))

def lines(d):
    if not d:
        return "- none"
    return "\n".join(f"- `{k}`: {v}" for k, v in sorted(d.items(), key=lambda x: x[1], reverse=True))

md = f"""# CYBRA Audit Dedupe Report

Status: generated  
Double SHA: `{report["double_sha"]}`

## Summary

- Structured audit: {report["summary"]["structured_audit"]}
- Duplicates blocked: {report["summary"]["duplicates_blocked"]}
- Dedupe fingerprints: {report["summary"]["dedupe_fingerprints"]}
- Fingerprint records: {report["summary"]["fingerprint_records"]}
- Queue: {report["summary"]["queue"]}
- Results: {report["summary"]["results"]}

## Decisions

{lines(report["decisions"])}

## Types

{lines(report["types"])}

## Top topics

{lines(report["topics_top"])}
"""

Path("posts/audit_dedupe_report.md").write_text(md)

with open("proofs/audit_dedupe_report.sha256", "w") as f:
    subprocess.run(
        ["sha256sum", "feeds/audit_dedupe_report.json", "posts/audit_dedupe_report.md"],
        stdout=f,
        stderr=subprocess.DEVNULL
    )

print("✅ audit/dedupe report generated")
print("Report: posts/audit_dedupe_report.md")
PY
    cat posts/audit_dedupe_report.md
    ;;
  *)
    echo "Usage:"
    echo "  bash cybra_audit_dedupe.sh submit '<json_task>' [--force]"
    echo "  bash cybra_audit_dedupe.sh status|report|audit|duplicates|fingerprints"
    ;;
esac
BASH

chmod +x cybra_audit_dedupe.sh

cat > audit_dedupe_test_handler.sh <<'HANDLER'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

mkdir -p posts feeds proofs logs/audit

TS="$(date -Iseconds)"

cat > feeds/audit_dedupe_test.json <<JSON
{
  "status": "executed",
  "handler": "audit_dedupe_test_handler.sh",
  "time": "$TS"
}
JSON

cat > posts/audit_dedupe_test.md <<MD
# CYBRA Audit Dedupe Test

Status: executed  
Time: $TS
MD

sha256sum feeds/audit_dedupe_test.json posts/audit_dedupe_test.md > proofs/audit_dedupe_test.sha256

echo "✅ AUDIT DEDUPE TEST EXECUTED"
HANDLER

chmod +x audit_dedupe_test_handler.sh

redis-cli HSET cybra:executor:mapping audit_dedupe_test_task audit_dedupe_test_handler.sh >/dev/null

echo "=== PATCH CYBRA CLI ==="

python3 - <<'PY'
import os
from pathlib import Path

paths = []
prefix = os.environ.get("PREFIX")
if prefix:
    paths.append(Path(prefix) / "bin" / "cybra")
paths.append(Path("cybra"))

for p in paths:
    if not p.exists():
        continue

    s = p.read_text()

    s = s.replace("redis-cli LRANGE cybra:results 0 -1", "redis-cli LRANGE cybra:parliament:results 0 -1")
    s = s.replace("redis-cli LLEN cybra:results", "redis-cli LLEN cybra:parliament:results")

    if "cybra_submit_guarded.py" not in s:
        s = s.replace(
            'redis-cli LPUSH cybra:parliament:queue "$1"\n    echo "✅ Parliament task submitted"',
            'python3 "$HOME/CYBRA/cybra_submit_guarded.py" submit "$1"'
        )
        s = s.replace(
            'redis-cli LPUSH cybra:queue "$1"\n    echo "✅ Parliament task submitted"',
            'python3 "$HOME/CYBRA/cybra_submit_guarded.py" submit "$1"'
        )

    p.write_text(s)
    p.chmod(0o755)
    print("✅ patched", p)
PY

python3 - <<'PY'
from pathlib import Path

p = Path("parliament_executor_v6.py")
s = p.read_text()

if 'r.hget("cybra:executor:mapping", task_type)' not in s:
    old = "script_name = SCRIPT_MAP.get(task_type)"
    new = 'script_name = r.hget("cybra:executor:mapping", task_type) or SCRIPT_MAP.get(task_type)'
    if old in s:
        s = s.replace(old, new, 1)
        print("✅ executor patched for Redis mapping")

if '"audit_dedupe_test_task"' not in s:
    i = s.find("SCRIPT_MAP")
    j = s.find("{", i)
    if i >= 0 and j >= 0:
        s = s[:j+1] + '\n    "audit_dedupe_test_task": "audit_dedupe_test_handler.sh",' + s[j+1:]
        print("✅ static mapping inserted: audit_dedupe_test_task")

p.write_text(s)
PY

rm -rf __pycache__
python3 -m py_compile parliament_executor_v6.py
rm -rf __pycache__

bash cybra_audit_dedupe.sh report

echo
echo "=== DEDUPE TEST ==="
cybra parliament '{"topic":"Audit Dedupe Test","type":"audit_dedupe_test_task","priority":"normal","payload":{"mode":"dedupe_test"}}'
cybra parliament '{"topic":"Audit Dedupe Test","type":"audit_dedupe_test_task","priority":"normal","payload":{"mode":"dedupe_test"}}' || true

echo
echo "=== STATUS ==="
bash cybra_audit_dedupe.sh status

echo
echo "=== INSTALL DONE ==="
echo "Commit:"
echo "git add install_cybra_audit_dedupe_guard_all.sh cybra_submit_guarded.py cybra_audit_dedupe.sh audit_dedupe_test_handler.sh parliament/audit/audit_dedupe_policy.json parliament_executor_v6.py posts/audit_dedupe_status.md feeds/audit_dedupe_status.json proofs/audit_dedupe_status.sha256 posts/audit_dedupe_report.md feeds/audit_dedupe_report.json proofs/audit_dedupe_report.sha256"
echo "git commit -m 'add CYBRA audit dedupe tagging guard'"
echo "git push origin main"
