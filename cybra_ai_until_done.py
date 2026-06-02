#!/usr/bin/env python3
import json
import time
import hashlib
import subprocess
from pathlib import Path

import redis

ROOT = Path.home() / "CYBRA"
r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

AI_PREFIX = "cybra:ai:tasks:"
PARLIAMENT_QUEUE = "cybra:parliament:queue"
FAILED = "cybra:parliament:failed"
RESULTS = "cybra:parliament:results"

AUDIT = "cybra:ai_until_done:audit"
MOVED = "cybra:ai_until_done:moved_hashes"
DONE_REPORT = "feeds/ai_until_done_report.json"

GUARD = {
    "real_payment_execution": False,
    "automatic_token_mint": False,
    "automatic_liquidity_pool": False,
    "automatic_exchange_launch": False,
    "automatic_gold_purchase": False,
    "automatic_external_tx": False,
    "manual_OWNER_approval_required": True,
    "no_private_keys": True,
    "no_seed_phrase": True,
    "no_guaranteed_profit": True,
    "no_market_manipulation": True,
    "owner_directive_scope": "AI_TASK_COMPLETION_ONLY_NO_REAL_FINANCIAL_EXECUTION"
}

def sha(x):
    return hashlib.sha256(x.encode("utf-8")).hexdigest()

def dsha(x):
    return sha(sha(x))

def now_iso():
    return time.strftime("%Y-%m-%dT%H:%M:%S%z")

def redis_len(key):
    try:
        return r.llen(key)
    except Exception:
        return 0

def ai_keys():
    return sorted([k for k in r.keys(AI_PREFIX + "*") if k != PARLIAMENT_QUEUE])

def ai_total():
    return sum(redis_len(k) for k in ai_keys())

def has_mapping(task_type):
    try:
        return bool(r.hget("cybra:executor:mapping", task_type))
    except Exception:
        return False

def normalize_task(raw, source_key):
    try:
        obj = json.loads(raw)
        if not isinstance(obj, dict):
            obj = {"topic": "Raw AI task", "type": "generic_ai_safe_task", "payload": {"raw": raw}}
    except Exception:
        obj = {"topic": "Raw AI task", "type": "generic_ai_safe_task", "payload": {"raw": raw}}

    obj.setdefault("topic", "AI task until done")
    obj.setdefault("priority", "high")
    obj.setdefault("payload", {})

    if not isinstance(obj["payload"], dict):
        obj["payload"] = {"original_payload": obj["payload"]}

    original_type = obj.get("type", "generic_ai_safe_task")
    if not has_mapping(original_type):
        obj["type"] = "generic_ai_safe_task"
        obj["payload"]["original_type_without_mapping"] = original_type
    else:
        obj["type"] = original_type

    obj["payload"].update(GUARD)
    obj["payload"]["source_ai_queue"] = source_key
    obj["payload"]["owner_directive"] = "work_until_ai_tasks_completed"

    canonical = json.dumps(obj, ensure_ascii=False, sort_keys=True)
    obj["ai_until_done_hash"] = dsha(canonical)

    return obj

def collect():
    moved = 0
    skipped = 0

    for key in ai_keys():
        while redis_len(key) > 0:
            raw = r.rpop(key)
            if raw is None:
                break

            task = normalize_task(raw, key)
            h = task["ai_until_done_hash"]

            if r.sadd(MOVED, h):
                r.lpush(PARLIAMENT_QUEUE, json.dumps(task, ensure_ascii=False))
                moved += 1
            else:
                skipped += 1

    audit = {
        "status": "ai_tasks_collected_to_parliament_queue",
        "moved": moved,
        "skipped_duplicates": skipped,
        "ai_total_left": ai_total(),
        "parliament_queue": redis_len(PARLIAMENT_QUEUE),
        "time": time.time(),
        "time_iso": now_iso()
    }
    audit["double_sha"] = dsha(json.dumps(audit, ensure_ascii=False, sort_keys=True))
    r.lpush(AUDIT, json.dumps(audit, ensure_ascii=False))

    print(f"MOVED={moved}")
    print(f"SKIPPED={skipped}")
    print(f"AI_TOTAL={ai_total()}")
    print(f"PARLIAMENT_QUEUE={redis_len(PARLIAMENT_QUEUE)}")

def status(shell=False):
    data = {
        "ai_total": ai_total(),
        "ai_keys": {k: redis_len(k) for k in ai_keys()},
        "parliament_queue": redis_len(PARLIAMENT_QUEUE),
        "parliament_results": redis_len(RESULTS),
        "parliament_failed": redis_len(FAILED),
        "audit": redis_len(AUDIT),
        "moved_hashes": r.scard(MOVED)
    }

    if shell:
        print(f"AI_TOTAL={data['ai_total']}")
        print(f"PARLIAMENT_QUEUE={data['parliament_queue']}")
        print(f"PARLIAMENT_RESULTS={data['parliament_results']}")
        print(f"PARLIAMENT_FAILED={data['parliament_failed']}")
        print(f"AUDIT={data['audit']}")
        print(f"MOVED_HASHES={data['moved_hashes']}")
    else:
        print(json.dumps(data, ensure_ascii=False, indent=2))

def directive():
    obj = {
        "status": "OWNER_DIRECTIVE_ACCEPTED",
        "directive": "AI Parliament must work until AI tasks are completed.",
        "scope": "AI task completion only",
        "real_payment_execution": False,
        "automatic_token_mint": False,
        "automatic_liquidity_pool": False,
        "automatic_exchange_launch": False,
        "automatic_external_tx": False,
        "manual_OWNER_approval_required_for_real_launch": True,
        "time": time.time(),
        "time_iso": now_iso()
    }
    obj["double_sha"] = dsha(json.dumps(obj, ensure_ascii=False, sort_keys=True))

    (ROOT / "feeds/owner_directive_ai_until_done.json").write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")
    (ROOT / "posts/owner_directive_ai_until_done.md").write_text(
        "# OWNER Directive: AI Parliament Until Done\n\n"
        "Directive: **work until AI tasks are completed**\n\n"
        "Scope: **AI/local/proof/report tasks only**\n\n"
        "Real payment execution: **false**\n\n"
        "Automatic token mint: **false**\n\n"
        "Automatic liquidity pool: **false**\n\n"
        "Automatic exchange launch: **false**\n\n"
        "Manual OWNER approval required for real launch: **true**\n\n"
        f"Double SHA: `{obj['double_sha']}`\n",
        encoding="utf-8"
    )

    with (ROOT / "proofs/owner_directive_ai_until_done.sha256").open("w") as f:
        subprocess.run(
            ["sha256sum", "feeds/owner_directive_ai_until_done.json", "posts/owner_directive_ai_until_done.md"],
            cwd=ROOT,
            stdout=f,
            stderr=subprocess.DEVNULL
        )

    r.lpush("cybra:owner:directives", json.dumps(obj, ensure_ascii=False))
    print("✅ OWNER directive recorded")

def finalize():
    complete = ai_total() == 0 and redis_len(PARLIAMENT_QUEUE) == 0 and redis_len(FAILED) == 0

    obj = {
        "status": "completed" if complete else "needs_attention",
        "complete": complete,
        "ai_total": ai_total(),
        "parliament_queue": redis_len(PARLIAMENT_QUEUE),
        "parliament_results": redis_len(RESULTS),
        "parliament_failed": redis_len(FAILED),
        "audit": redis_len(AUDIT),
        "moved_hashes": r.scard(MOVED),
        "real_payment_execution": False,
        "automatic_token_mint": False,
        "automatic_liquidity_pool": False,
        "automatic_exchange_launch": False,
        "automatic_external_tx": False,
        "time": time.time(),
        "time_iso": now_iso()
    }
    obj["double_sha"] = dsha(json.dumps(obj, ensure_ascii=False, sort_keys=True))

    (ROOT / "feeds/ai_until_done_report.json").write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")

    md = f"""# AI Parliament Until Done Report

Status: **{obj['status']}**

## Result

- Complete: **{obj['complete']}**
- AI total left: **{obj['ai_total']}**
- Parliament queue: **{obj['parliament_queue']}**
- Parliament failed: **{obj['parliament_failed']}**
- Parliament results: **{obj['parliament_results']}**
- Moved AI tasks: **{obj['moved_hashes']}**

## Safety

- Real payment execution: **false**
- Automatic token mint: **false**
- Automatic liquidity pool: **false**
- Automatic exchange launch: **false**
- External blockchain transaction: **false**

## Proof

Double SHA:

`{obj['double_sha']}`
"""
    (ROOT / "posts/ai_until_done_report.md").write_text(md, encoding="utf-8")

    with (ROOT / "proofs/ai_until_done_report.sha256").open("w") as f:
        subprocess.run(
            [
                "sha256sum",
                "feeds/ai_until_done_report.json",
                "posts/ai_until_done_report.md",
                "feeds/owner_directive_ai_until_done.json",
                "posts/owner_directive_ai_until_done.md"
            ],
            cwd=ROOT,
            stdout=f,
            stderr=subprocess.DEVNULL
        )

    r.lpush(AUDIT, json.dumps({
        "status": obj["status"],
        "complete": complete,
        "double_sha": obj["double_sha"],
        "time": obj["time"]
    }, ensure_ascii=False))

    print(json.dumps(obj, ensure_ascii=False, indent=2))

def main():
    import sys
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"

    if cmd == "collect":
        collect()
    elif cmd == "status":
        status(False)
    elif cmd == "status-shell":
        status(True)
    elif cmd == "directive":
        directive()
    elif cmd == "finalize":
        finalize()
    elif cmd == "ai-total":
        print(ai_total())
    else:
        raise SystemExit("Usage: directive|collect|status|status-shell|finalize|ai-total")

if __name__ == "__main__":
    main()
