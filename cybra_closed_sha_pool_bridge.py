#!/usr/bin/env python3
import json
import time
import hashlib
import subprocess
from pathlib import Path

import redis

ROOT = Path.home() / "CYBRA"
r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

TASK_MEMPOOL = "cybra:kibra:task_blocks:mempool"
POOL_QUEUE = "cybra:kibra:pool:mining_blocks"
BRIDGE_OUTBOX = "cybra:kibra:closed_sha_pool_bridge:outbox"
BRIDGE_SEALED = "cybra:kibra:closed_sha_pool_bridge:sealed"
BRIDGE_SEEN = "cybra:kibra:closed_sha_pool_bridge:seen"
AUDIT = "cybra:kibra:closed_sha_pool_bridge:audit"
AI_BLOCK_INBOX = "cybra:ai:tasks:block_inbox"

def sha(x: str) -> str:
    return hashlib.sha256(x.encode("utf-8")).hexdigest()

def dsha(x: str) -> str:
    return sha(sha(x))

def now_iso():
    return time.strftime("%Y-%m-%dT%H:%M:%S%z")

def latest_hash():
    p = ROOT / "blockchain/kibra_chain/latest.block.hash"
    return p.read_text().strip() if p.exists() else None

def redis_len(k):
    try:
        return r.llen(k)
    except Exception:
        return 0

def count_files(pattern):
    return len(list(ROOT.glob(pattern)))

def load_json_raw(raw):
    try:
        obj = json.loads(raw)
        if isinstance(obj, dict):
            return obj
        return {"raw": obj}
    except Exception:
        return {"raw": raw}

def file_sha(path):
    p = ROOT / path
    if not p.exists():
        return None
    h = hashlib.sha256()
    with p.open("rb") as f:
        for c in iter(lambda: f.read(1024 * 1024), b""):
            h.update(c)
    return h.hexdigest()

def git_cmd(cmd):
    try:
        return subprocess.check_output(cmd, cwd=ROOT, text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return ""

def make_sealed_envelope(raw, source_queue):
    task_block = load_json_raw(raw)

    canonical = json.dumps(task_block, ensure_ascii=False, sort_keys=True)
    payload_sha = sha(canonical)

    bridge_id = dsha(json.dumps({
        "payload_sha256": payload_sha,
        "source_queue": source_queue,
        "latest_kibra_hash": latest_hash(),
        "time_bucket": int(time.time() // 60)
    }, ensure_ascii=False, sort_keys=True))

    sealed = {
        "status": "sealed_task_block_for_pool_mining",
        "bridge_id": bridge_id,
        "source_queue": source_queue,
        "created_at": time.time(),
        "created_at_iso": now_iso(),
        "latest_kibra_hash": latest_hash(),
        "payload_sha256": payload_sha,
        "task_block_payload": task_block,
        "sealed_mode": True,
        "pool_mining_required": True,
        "existing_mining_system": True,
        "real_external_tx_now": False,
        "manual_OWNER_approval_required": True
    }

    sealed["double_sha"] = dsha(json.dumps(sealed, ensure_ascii=False, sort_keys=True))

    sealed_file = ROOT / "data/kibra_closed_sha_pool_bridge/sealed" / f"{bridge_id[:16]}.sealed.json"
    sealed_file.parent.mkdir(parents=True, exist_ok=True)
    sealed_file.write_text(json.dumps(sealed, ensure_ascii=False, indent=2), encoding="utf-8")

    envelope = {
        "status": "closed_sha_pool_mining_envelope",
        "bridge_id": bridge_id,
        "source_queue": source_queue,
        "created_at": sealed["created_at"],
        "created_at_iso": sealed["created_at_iso"],
        "latest_kibra_hash": sealed["latest_kibra_hash"],
        "payload_sha256": payload_sha,
        "sealed_file": str(sealed_file.relative_to(ROOT)),
        "sealed_file_sha256": file_sha(str(sealed_file.relative_to(ROOT))),
        "double_sha": sealed["double_sha"],
        "pool_mining_required": True,
        "pool_queue": POOL_QUEUE,
        "full_payload_public": False,
        "connect_to_existing_mining_system": True,
        "real_external_tx_now": False,
        "manual_OWNER_approval_required": True
    }

    outbox_file = ROOT / "data/kibra_closed_sha_pool_bridge/outbox" / f"{bridge_id[:16]}.pool_envelope.json"
    outbox_file.parent.mkdir(parents=True, exist_ok=True)
    outbox_file.write_text(json.dumps(envelope, ensure_ascii=False, indent=2), encoding="utf-8")

    return bridge_id, sealed, envelope

def dispatch(limit=200):
    items = r.lrange(TASK_MEMPOOL, 0, limit - 1)

    dispatched = 0
    skipped = 0

    for raw in items:
        bridge_id, sealed, envelope = make_sealed_envelope(raw, TASK_MEMPOOL)

        if r.sadd(BRIDGE_SEEN, bridge_id):
            r.lpush(POOL_QUEUE, json.dumps(envelope, ensure_ascii=False))
            r.lpush(BRIDGE_OUTBOX, json.dumps(envelope, ensure_ascii=False))
            r.lpush(BRIDGE_SEALED, json.dumps({
                "bridge_id": bridge_id,
                "sealed_file": envelope["sealed_file"],
                "double_sha": envelope["double_sha"],
                "time": envelope["created_at"]
            }, ensure_ascii=False))
            dispatched += 1
        else:
            skipped += 1

    make_report(dispatched, skipped)
    print("✅ closed SHA bridge dispatch complete")
    print("DISPATCHED:", dispatched)
    print("SKIPPED:", skipped)
    print("TASK_MEMPOOL:", redis_len(TASK_MEMPOOL))
    print("POOL_QUEUE:", redis_len(POOL_QUEUE))
    print("BRIDGE_OUTBOX:", redis_len(BRIDGE_OUTBOX))

def run_existing_mining_system():
    cmds = [
        ["bash", "cybra_ai_blocks.sh", "until-done"],
        ["bash", "cybra_ai_blocks.sh", "cycle"],
        ["python3", "cybra_ai_tasks_to_blocks.py", "mine"]
    ]

    ran = []
    for cmd in cmds:
        target = ROOT / cmd[1] if cmd[0] == "bash" else ROOT / cmd[1]
        if target.exists():
            try:
                subprocess.run(cmd, cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=60)
                ran.append(" ".join(cmd))
                break
            except Exception:
                pass

    return ran

def cycle():
    if (ROOT / "cybra_ai_block_enforcer.sh").exists():
        subprocess.run(["bash", "cybra_ai_block_enforcer.sh", "enforce", "3"], cwd=ROOT)

    dispatch(500)

    ran = run_existing_mining_system()

    dispatch(500)
    make_report(0, 0, mining_ran=ran)

    print("✅ closed SHA pool bridge cycle complete")
    print("MINING_SYSTEM_RAN:", ran)
    status()

def submit_task(task_json):
    obj = load_json_raw(task_json)
    obj.setdefault("topic", "Closed SHA pool bridge task")
    obj.setdefault("type", "generic_ai_safe_task")
    obj.setdefault("priority", "high")
    obj.setdefault("payload", {})
    if not isinstance(obj["payload"], dict):
        obj["payload"] = {"original_payload": obj["payload"]}

    obj["payload"].update({
        "route": "AI task -> task-block -> closed SHA pool bridge -> pool mining",
        "convert_to_mining_block_first": True,
        "closed_sha_bridge_required": True,
        "pool_mining_required": True,
        "real_external_tx_now": False,
        "manual_OWNER_approval_required": True
    })

    r.lpush(AI_BLOCK_INBOX, json.dumps(obj, ensure_ascii=False))
    print("✅ task added to AI block inbox")
    print("Run: bash cybra_closed_sha_bridge.sh cycle")

def make_report(dispatched=0, skipped=0, mining_ran=None):
    mining_ran = mining_ran or []

    for d in ["posts", "feeds", "proofs", "data/kibra_closed_sha_pool_bridge/reports"]:
        (ROOT / d).mkdir(parents=True, exist_ok=True)

    obj = {
        "status": "kibra_closed_sha_pool_bridge_report_generated",
        "time": time.time(),
        "time_iso": now_iso(),
        "dispatched_now": dispatched,
        "skipped_now": skipped,
        "mining_system_ran": mining_ran,
        "latest_kibra_hash": latest_hash(),
        "redis": {
            "ai_block_inbox": redis_len(AI_BLOCK_INBOX),
            "task_block_mempool": redis_len(TASK_MEMPOOL),
            "pool_mining_blocks": redis_len(POOL_QUEUE),
            "bridge_outbox": redis_len(BRIDGE_OUTBOX),
            "bridge_sealed": redis_len(BRIDGE_SEALED),
            "bridge_seen": r.scard(BRIDGE_SEEN),
            "task_blocks_mined": redis_len("cybra:kibra:task_blocks:mined"),
            "parliament_queue": redis_len("cybra:parliament:queue"),
            "parliament_failed": redis_len("cybra:parliament:failed")
        },
        "files": {
            "sealed_files": count_files("data/kibra_closed_sha_pool_bridge/sealed/*.json"),
            "outbox_files": count_files("data/kibra_closed_sha_pool_bridge/outbox/*.json")
        },
        "integration": {
            "existing_mining_system": True,
            "pool_queue": POOL_QUEUE,
            "task_mempool": TASK_MEMPOOL,
            "ai_block_enforcer": (ROOT / "cybra_ai_block_enforcer.sh").exists(),
            "ai_tasks_to_blocks": (ROOT / "cybra_ai_tasks_to_blocks.py").exists(),
            "cybra_ai_blocks_cli": (ROOT / "cybra_ai_blocks.sh").exists()
        },
        "git": {
            "branch": git_cmd(["git", "branch", "--show-current"]),
            "commit": git_cmd(["git", "rev-parse", "--short", "HEAD"]),
            "dirty_files": len(git_cmd(["git", "status", "--short"]).splitlines())
        },
        "safety": {
            "full_payload_public": False,
            "real_external_tx_now": False,
            "real_payment_now": False,
            "real_sell_now": False,
            "manual_OWNER_approval_required": True
        }
    }

    obj["double_sha"] = dsha(json.dumps(obj, ensure_ascii=False, sort_keys=True))

    (ROOT / "feeds/kibra_closed_sha_pool_bridge_report.json").write_text(
        json.dumps(obj, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )

    (ROOT / "data/kibra_closed_sha_pool_bridge/reports/latest_report.json").write_text(
        json.dumps(obj, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )

    md = f"""# KIBRA Closed SHA Pool Bridge

Status: **active**

## Purpose

Закритий SHA-міст передає task-blocks у pool mining queue існуючої майнінг-системи.

## Flow

AI task → AI Block Enforcer → task-block mempool → Closed SHA seal → pool mining queue → existing mining system → mined block.

## Current

- Dispatched now: **{dispatched}**
- Skipped now: **{skipped}**
- AI block inbox: **{obj['redis']['ai_block_inbox']}**
- Task-block mempool: **{obj['redis']['task_block_mempool']}**
- Pool mining blocks: **{obj['redis']['pool_mining_blocks']}**
- Bridge outbox: **{obj['redis']['bridge_outbox']}**
- Bridge sealed: **{obj['redis']['bridge_sealed']}**
- Bridge seen: **{obj['redis']['bridge_seen']}**
- Task-blocks mined: **{obj['redis']['task_blocks_mined']}**
- Parliament queue: **{obj['redis']['parliament_queue']}**
- Parliament failed: **{obj['redis']['parliament_failed']}**

## Files

- Sealed files: **{obj['files']['sealed_files']}**
- Outbox files: **{obj['files']['outbox_files']}**

## Mining integration

- Existing mining system: **true**
- Pool queue: `{POOL_QUEUE}`
- Task mempool: `{TASK_MEMPOOL}`
- AI Block Enforcer exists: **{obj['integration']['ai_block_enforcer']}**
- AI tasks-to-blocks exists: **{obj['integration']['ai_tasks_to_blocks']}**
- cybra_ai_blocks CLI exists: **{obj['integration']['cybra_ai_blocks_cli']}**

## Safety

- Full payload public: **false**
- Real external tx now: **false**
- Real payment/sell: **false**
- OWNER approval required: **true**

## Double SHA

`{obj['double_sha']}`
"""

    (ROOT / "posts/kibra_closed_sha_pool_bridge_report.md").write_text(md, encoding="utf-8")

    with (ROOT / "proofs/kibra_closed_sha_pool_bridge.sha256").open("w") as f:
        subprocess.run([
            "sha256sum",
            "parliament/departments/kibra_closed_sha_pool_bridge_department/department.json",
            "parliament/kibra_closed_sha_pool_bridge/policy.json",
            "feeds/kibra_closed_sha_pool_bridge_report.json",
            "posts/kibra_closed_sha_pool_bridge_report.md"
        ], cwd=ROOT, stdout=f, stderr=subprocess.DEVNULL)

    r.lpush(AUDIT, json.dumps({
        "status": "bridge_report_generated",
        "dispatched": dispatched,
        "skipped": skipped,
        "pool_queue": obj["redis"]["pool_mining_blocks"],
        "bridge_outbox": obj["redis"]["bridge_outbox"],
        "double_sha": obj["double_sha"],
        "time": obj["time"]
    }, ensure_ascii=False))

def status():
    print("PONG" if r.ping() else "NO REDIS")
    print("AI_BLOCK_INBOX:", redis_len(AI_BLOCK_INBOX))
    print("TASK_BLOCK_MEMPOOL:", redis_len(TASK_MEMPOOL))
    print("POOL_MINING_BLOCKS:", redis_len(POOL_QUEUE))
    print("BRIDGE_OUTBOX:", redis_len(BRIDGE_OUTBOX))
    print("BRIDGE_SEALED:", redis_len(BRIDGE_SEALED))
    print("BRIDGE_SEEN:", r.scard(BRIDGE_SEEN))
    print("TASK_BLOCKS_MINED:", redis_len("cybra:kibra:task_blocks:mined"))
    print("PARLIAMENT_QUEUE:", redis_len("cybra:parliament:queue"))
    print("PARLIAMENT_FAILED:", redis_len("cybra:parliament:failed"))
    print("REPORT_EXISTS:", (ROOT / "posts/kibra_closed_sha_pool_bridge_report.md").exists())

def main():
    import sys
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"

    if cmd == "dispatch":
        limit = int(sys.argv[2]) if len(sys.argv) > 2 else 200
        dispatch(limit)
    elif cmd == "cycle":
        cycle()
    elif cmd == "submit":
        if len(sys.argv) < 3:
            raise SystemExit("Usage: submit '<json_task>'")
        submit_task(sys.argv[2])
    elif cmd == "report":
        make_report()
    elif cmd == "status":
        status()
    else:
        raise SystemExit("Usage: status|dispatch|cycle|submit|report")

if __name__ == "__main__":
    main()
