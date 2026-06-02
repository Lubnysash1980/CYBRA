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
