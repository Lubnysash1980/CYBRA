#!/usr/bin/env python3
import json
import time
import hashlib
import subprocess
from pathlib import Path

import redis

INCOMING = "cybra:review:incoming"
APPROVED = "cybra:review:approved"
HOLD = "cybra:review:hold"
REJECTED = "cybra:review:rejected"
AUDIT = "cybra:review:audit"
EXECUTION = "cybra:parliament:queue"
MAPPING = "cybra:executor:mapping"

BLOCK_WORDS = [
    "вкрасти", "украсть", "steal",
    "зламати", "взломать", "hack account",
    "перевести кошти", "переведи деньги", "send money",
    "арештувати", "арестовать",
    "заморозити рахунки", "заморозить счета",
    "заблокувати рахунки", "заблокировать счета",
    "kill", "убить", "ліквідувати",
    "підробити", "подделать",
    "private key", "seed phrase"
]

def dsha(text: str) -> str:
    one = hashlib.sha256(text.encode("utf-8")).hexdigest()
    return hashlib.sha256(one.encode("utf-8")).hexdigest()

def load_static_map():
    try:
        import ast
        s = Path("parliament_executor_v6.py").read_text()
        tree = ast.parse(s)
        for node in tree.body:
            if isinstance(node, ast.Assign):
                for target in node.targets:
                    if getattr(target, "id", None) == "SCRIPT_MAP":
                        return ast.literal_eval(node.value)
    except Exception:
        return {}
    return {}

def write_status(event):
    Path("feeds").mkdir(exist_ok=True)
    Path("posts").mkdir(exist_ok=True)
    Path("proofs").mkdir(exist_ok=True)

    Path("feeds/review_status.json").write_text(
        json.dumps(event, ensure_ascii=False, indent=2)
    )

    Path("posts/review_committee_status.md").write_text(
        "# CYBRA Parliament Review Organ\n\n"
        f"Status: {event.get('status')}\n\n"
        f"Topic: {event.get('topic')}\n\n"
        f"Type: {event.get('type')}\n\n"
        f"Decision: {event.get('decision')}\n\n"
        f"Reason: {event.get('reason')}\n\n"
        f"Time: {event.get('time')}\n"
    )

    subprocess.run(
        ["sha256sum", "feeds/review_status.json", "posts/review_committee_status.md"],
        stdout=open("proofs/review_committee.sha256", "w"),
        stderr=subprocess.DEVNULL
    )

def review_task(r, raw):
    now = time.time()
    event = {
        "status": "reviewed",
        "time": now,
        "raw_double_sha": dsha(raw)
    }

    try:
        task = json.loads(raw)
        if not isinstance(task, dict):
            raise ValueError("task is not JSON object")
    except Exception as e:
        event.update({
            "decision": "rejected",
            "reason": f"invalid_json: {e}",
            "topic": None,
            "type": None
        })
        r.lpush(REJECTED, json.dumps(event, ensure_ascii=False))
        r.lpush(AUDIT, json.dumps(event, ensure_ascii=False))
        write_status(event)
        return

    topic = str(task.get("topic", ""))
    task_type = str(task.get("type", ""))
    raw_lower = raw.lower()

    event.update({
        "topic": topic,
        "type": task_type
    })

    for word in BLOCK_WORDS:
        if word.lower() in raw_lower:
            event.update({
                "decision": "rejected",
                "reason": f"blocked_policy_word: {word}"
            })
            r.lpush(REJECTED, json.dumps(event, ensure_ascii=False))
            r.lpush(AUDIT, json.dumps(event, ensure_ascii=False))
            write_status(event)
            return

    if not topic or not task_type:
        event.update({
            "decision": "hold",
            "reason": "missing topic or type"
        })
        r.lpush(HOLD, raw)
        r.lpush(AUDIT, json.dumps(event, ensure_ascii=False))
        write_status(event)
        return

    redis_script = r.hget(MAPPING, task_type)
    static_map = load_static_map()
    static_script = static_map.get(task_type)
    script = redis_script or static_script

    if not script:
        event.update({
            "decision": "hold",
            "reason": "no_executor_mapping"
        })
        r.lpush(HOLD, raw)
        r.lpush(AUDIT, json.dumps(event, ensure_ascii=False))
        write_status(event)
        return

    task["_review"] = {
        "approved": True,
        "approved_by": "CYBRA Parliament Review Organ",
        "time": now,
        "script": script,
        "double_sha": event["raw_double_sha"]
    }

    approved_raw = json.dumps(task, ensure_ascii=False)

    r.lpush(APPROVED, approved_raw)
    r.lpush(EXECUTION, approved_raw)

    event.update({
        "decision": "approved",
        "reason": "safe_and_mapped",
        "script": script
    })

    r.lpush(AUDIT, json.dumps(event, ensure_ascii=False))
    write_status(event)

def main():
    print("=== CYBRA REVIEW WORKER STARTED ===", flush=True)
    r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

    while True:
        item = r.brpop(INCOMING, timeout=5)
        if not item:
            continue
        _, raw = item
        try:
            review_task(r, raw)
        except Exception as e:
            err = {
                "status": "review_worker_error",
                "error": str(e),
                "time": time.time()
            }
            r.lpush(AUDIT, json.dumps(err, ensure_ascii=False))
            write_status(err)

if __name__ == "__main__":
    main()
