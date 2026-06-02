#!/usr/bin/env python3
import json, time, hashlib, subprocess
from pathlib import Path
import redis

ROOT = Path.home() / "CYBRA"
r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

PARLIAMENT_QUEUE = "cybra:parliament:queue"
MEMPOOL = "cybra:kibra:task_blocks:mempool"
CONVERTED = "cybra:ai_block_enforcer:converted_hashes"
AUDIT = "cybra:ai_block_enforcer:audit"
AI_INBOX = "cybra:ai:tasks:block_inbox"

SAFE = {
    "converted_by_ai_block_enforcer": True,
    "not_sent_directly": True,
    "must_be_mined_by_pool": True,
    "real_payment": False,
    "real_sell": False,
    "external_tx": False,
    "manual_OWNER_approval_required": True
}

def sha(x):
    return hashlib.sha256(x.encode("utf-8")).hexdigest()

def dsha(x):
    return sha(sha(x))

def now_iso():
    return time.strftime("%Y-%m-%dT%H:%M:%S%z")

def redis_len(k):
    try:
        return r.llen(k)
    except Exception:
        return 0

def parse_task(raw):
    try:
        obj = json.loads(raw)
        if not isinstance(obj, dict):
            obj = {"topic": "raw_ai_task", "type": "generic_ai_safe_task", "payload": {"raw": raw}}
    except Exception:
        obj = {"topic": "raw_ai_task", "type": "generic_ai_safe_task", "payload": {"raw": raw}}

    obj.setdefault("topic", "AI task")
    obj.setdefault("type", "generic_ai_safe_task")
    obj.setdefault("priority", "high")
    obj.setdefault("payload", {})

    if not isinstance(obj["payload"], dict):
        obj["payload"] = {"original_payload": obj["payload"]}

    return obj

def is_after_mining(task):
    p = task.get("payload", {})
    return bool(
        p.get("block_was_mined_before_sending") or
        p.get("mined_task_block") or
        p.get("enforcer_verified_after_mining")
    )

def ai_keys():
    keys = sorted(r.keys("cybra:ai:tasks:*"))
    return [k for k in keys if k not in [PARLIAMENT_QUEUE]]

def convert_raw_task(raw, source):
    task = parse_task(raw)

    if is_after_mining(task):
        return None, "already_mined_support"

    task["payload"].update(SAFE)
    task["payload"]["source_queue"] = source
    task["payload"]["owner_rule"] = "all_new_ai_tasks_must_be_mined_into_blocks"

    h = dsha(json.dumps(task, ensure_ascii=False, sort_keys=True))
    task["payload"]["ai_block_enforcer_hash"] = h

    return task, h

def process_queue(key, limit=200):
    converted = 0
    skipped = 0

    items = r.lrange(key, 0, limit - 1)

    for raw in items:
        task, h = convert_raw_task(raw, key)

        if task is None:
            skipped += 1
            continue

        removed = r.lrem(key, 1, raw)

        if not removed:
            continue

        if r.sadd(CONVERTED, h):
            r.lpush(MEMPOOL, json.dumps(task, ensure_ascii=False))

            out = ROOT / "data/ai_block_enforcer/converted" / f"{h[:16]}.json"
            out.parent.mkdir(parents=True, exist_ok=True)
            out.write_text(json.dumps(task, ensure_ascii=False, indent=2), encoding="utf-8")

            converted += 1
        else:
            skipped += 1

    return converted, skipped

def mine_if_needed(rounds=5):
    mined_rounds = 0

    if not (ROOT / "cybra_ai_tasks_to_blocks.py").exists():
        return 0

    for _ in range(rounds):
        if redis_len(MEMPOOL) <= 0:
            break

        subprocess.run(
            ["python3", "cybra_ai_tasks_to_blocks.py", "mine"],
            cwd=ROOT,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
        mined_rounds += 1

    return mined_rounds

def enforce(rounds=3):
    total_converted = 0
    total_skipped = 0

    for _ in range(rounds):
        sources = [PARLIAMENT_QUEUE] + ai_keys()

        for key in sources:
            c, s = process_queue(key)
            total_converted += c
            total_skipped += s

        mine_if_needed(rounds=3)

    make_report(total_converted, total_skipped)
    print("✅ AI Block Enforcer cycle complete")
    print("CONVERTED:", total_converted)
    print("SKIPPED:", total_skipped)
    print("MEMPOOL:", redis_len(MEMPOOL))
    print("MINED_TASK_BLOCKS:", redis_len("cybra:kibra:task_blocks:mined"))
    print("POOL_QUEUE:", redis_len("cybra:kibra:pool:mining_blocks"))

def submit(raw_json):
    task = parse_task(raw_json)
    task["payload"].update(SAFE)
    r.lpush(AI_INBOX, json.dumps(task, ensure_ascii=False))
    print("✅ task submitted to block inbox")
    print("Queue:", AI_INBOX)
    print("Run: bash cybra_ai_block_enforcer.sh enforce")

def make_report(converted=0, skipped=0):
    for d in ["posts", "feeds", "proofs"]:
        (ROOT / d).mkdir(parents=True, exist_ok=True)

    obj = {
        "status": "ai_block_enforcer_report_generated",
        "time": time.time(),
        "time_iso": now_iso(),
        "converted_now": converted,
        "skipped_now": skipped,
        "rule": "All new AI tasks must be converted to KIBRA mining task-blocks before AI Parliament execution.",
        "redis": {
            "parliament_queue": redis_len(PARLIAMENT_QUEUE),
            "parliament_failed": redis_len("cybra:parliament:failed"),
            "mempool": redis_len(MEMPOOL),
            "mined_task_blocks": redis_len("cybra:kibra:task_blocks:mined"),
            "pool_mining_blocks": redis_len("cybra:kibra:pool:mining_blocks"),
            "block_support_ai": redis_len("cybra:ai:tasks:kibra_block_ai_support"),
            "converted_hashes": r.scard(CONVERTED)
        },
        "safety": {
            "direct_ai_task_execution": False,
            "real_payment": False,
            "real_sell": False,
            "external_tx": False,
            "manual_OWNER_approval_required": True
        }
    }

    obj["double_sha"] = dsha(json.dumps(obj, ensure_ascii=False, sort_keys=True))

    (ROOT / "feeds/ai_block_enforcer_report.json").write_text(
        json.dumps(obj, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )

    md = f"""# AI Block Enforcer Report

Status: **active**

## Rule

Всі нові AI-завдання переводяться у KIBRA mining blocks.

## Current

- Converted now: **{converted}**
- Mempool: **{obj['redis']['mempool']}**
- Mined task blocks: **{obj['redis']['mined_task_blocks']}**
- Pool mining blocks: **{obj['redis']['pool_mining_blocks']}**
- Parliament queue: **{obj['redis']['parliament_queue']}**
- Parliament failed: **{obj['redis']['parliament_failed']}**
- Converted hashes: **{obj['redis']['converted_hashes']}**

## Flow

AI task → task-block mempool → pool mining → mined block → AI support task → Parliament.

## Safety

- Direct AI execution: **false**
- Real payment: **false**
- Real sell: **false**
- External tx: **false**
- Manual OWNER approval required: **true**

## Double SHA

`{obj['double_sha']}`
"""

    (ROOT / "posts/ai_block_enforcer_report.md").write_text(md, encoding="utf-8")

    with (ROOT / "proofs/ai_block_enforcer.sha256").open("w") as f:
        subprocess.run([
            "sha256sum",
            "parliament/ai_block_enforcer/policy.json",
            "parliament/departments/ai_block_enforcer_department/department.json",
            "feeds/ai_block_enforcer_report.json",
            "posts/ai_block_enforcer_report.md"
        ], cwd=ROOT, stdout=f, stderr=subprocess.DEVNULL)

    r.lpush(AUDIT, json.dumps({
        "status": "ai_block_enforcer_report_generated",
        "converted": converted,
        "skipped": skipped,
        "double_sha": obj["double_sha"],
        "time": obj["time"]
    }, ensure_ascii=False))

def status():
    print("PONG" if r.ping() else "NO REDIS")
    print("PARLIAMENT_QUEUE:", redis_len(PARLIAMENT_QUEUE))
    print("PARLIAMENT_FAILED:", redis_len("cybra:parliament:failed"))
    print("MEMPOOL:", redis_len(MEMPOOL))
    print("MINED_TASK_BLOCKS:", redis_len("cybra:kibra:task_blocks:mined"))
    print("POOL_MINING_BLOCKS:", redis_len("cybra:kibra:pool:mining_blocks"))
    print("BLOCK_SUPPORT_AI:", redis_len("cybra:ai:tasks:kibra_block_ai_support"))
    print("CONVERTED_HASHES:", r.scard(CONVERTED))
    print("AUDIT:", redis_len(AUDIT))

def main():
    import sys
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"

    if cmd == "enforce":
        rounds = int(sys.argv[2]) if len(sys.argv) > 2 else 3
        enforce(rounds)
    elif cmd == "submit":
        if len(sys.argv) < 3:
            raise SystemExit("Usage: submit '<json_task>'")
        submit(sys.argv[2])
    elif cmd == "report":
        make_report()
    elif cmd == "status":
        status()
    else:
        raise SystemExit("Usage: enforce|submit|report|status")

if __name__ == "__main__":
    main()
