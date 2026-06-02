#!/usr/bin/env python3
import json, time, hashlib, subprocess
from pathlib import Path
import redis

ROOT = Path.home() / "CYBRA"
r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

AUDIT = "cybra:kibra_bridge:audit"
OUTBOX = "cybra:kibra_bridge:network_outbox"
SEALED = "cybra:kibra_bridge:sealed_packages"
AIQ = "cybra:ai:tasks:kibra_bridge_pool_until_done"

def sha(x):
    return hashlib.sha256(x.encode("utf-8")).hexdigest()

def dsha(x):
    return sha(sha(x))

def now_iso():
    return time.strftime("%Y-%m-%dT%H:%M:%S%z")

def file_sha(path):
    p = ROOT / path
    if not p.exists():
        return None
    h = hashlib.sha256()
    with p.open("rb") as f:
        for c in iter(lambda: f.read(1024 * 1024), b""):
            h.update(c)
    return h.hexdigest()

def redis_len(key):
    try:
        return r.llen(key)
    except Exception:
        return 0

def load_json(path):
    p = ROOT / path
    if not p.exists():
        return {}
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception:
        return {}

def latest_hash():
    p = ROOT / "blockchain/kibra_chain/latest.block.hash"
    return p.read_text().strip() if p.exists() else None

def latest_blocks(limit=10):
    d = ROOT / "blockchain/kibra_chain/blocks"
    if not d.exists():
        return []
    files = sorted(d.glob("block_*.json"))[-limit:]
    out = []
    for f in files:
        try:
            obj = json.loads(f.read_text(encoding="utf-8"))
        except Exception:
            obj = {"file": str(f)}
        out.append({
            "file": str(f.relative_to(ROOT)),
            "sha256": file_sha(str(f.relative_to(ROOT))),
            "data": obj
        })
    return out

def build_pool_monetization():
    plan = {
        "status": "pool_monetization_plan_created",
        "native_coin": "KIBRA",
        "external_mint": False,
        "real_payment": False,
        "pool_reward_source": "native_block_reward_accounting",
        "pool_reward_usage": [
            "AI task credits",
            "block creation rewards",
            "proof validation rewards",
            "bridge package rewards",
            "developer marketplace credits"
        ],
        "allocation_model": {
            "owner_reserve_percent": 60,
            "ai_pool_percent": 40,
            "real_distribution_now": False,
            "accounting_only": True
        },
        "monetization_rule": "KIBRA value must come from utility, usage, demand and liquidity readiness; no fake price or guaranteed profit.",
        "safety": {
            "no_fake_volume": True,
            "no_market_manipulation": True,
            "manual_OWNER_approval_required_for_real_launch": True
        }
    }

    (ROOT / "data/kibra_pool_monetization/pool_monetization_plan.json").write_text(
        json.dumps(plan, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )
    return plan

def build_bridge_package():
    blocks = latest_blocks(10)
    plan = build_pool_monetization()

    package = {
        "status": "sealed_bridge_package_created",
        "bridge_type": "closed_sha_bridge",
        "time": time.time(),
        "time_iso": now_iso(),
        "latest_kibra_hash": latest_hash(),
        "blocks_count": len(blocks),
        "blocks": blocks,
        "pool_monetization": plan,
        "network_outbox": True,
        "real_network_broadcast_now": False,
        "manual_OWNER_approval_required": True,
        "safety": {
            "no_private_keys": True,
            "no_seed_phrase": True,
            "no_real_external_tx": True,
            "no_payment_execution": True
        },
        "proof_inputs": {
            "bridge_policy": file_sha("parliament/kibra_bridge/policy.json"),
            "bridge_department": file_sha("parliament/departments/kibra_bridge_department/department.json"),
            "kibra_chain_proof": file_sha("proofs/kibra_token_chain.sha256"),
            "native_kibra_proof": file_sha("proofs/native_kibra_ai_task_package.sha256"),
            "ai_until_done_proof": file_sha("proofs/ai_until_done_report.sha256")
        }
    }

    canonical = json.dumps(package, ensure_ascii=False, sort_keys=True)
    package["bridge_sha_seal"] = dsha(canonical)
    package["sealed_id"] = "KIBRA-BRIDGE-" + package["bridge_sha_seal"][:16]

    outbox_file = ROOT / f"data/kibra_bridge/outbox/{package['sealed_id']}.json"
    sealed_file = ROOT / f"data/kibra_bridge/sealed/{package['sealed_id']}.sealed.json"

    outbox_file.write_text(json.dumps(package, ensure_ascii=False, indent=2), encoding="utf-8")
    sealed_file.write_text(json.dumps({
        "sealed_id": package["sealed_id"],
        "bridge_sha_seal": package["bridge_sha_seal"],
        "latest_kibra_hash": package["latest_kibra_hash"],
        "blocks_count": package["blocks_count"],
        "real_network_broadcast_now": False,
        "manual_OWNER_approval_required": True,
        "outbox_file": str(outbox_file.relative_to(ROOT))
    }, ensure_ascii=False, indent=2), encoding="utf-8")

    r.lpush(OUTBOX, json.dumps(package, ensure_ascii=False))
    r.lpush(SEALED, json.dumps({
        "sealed_id": package["sealed_id"],
        "bridge_sha_seal": package["bridge_sha_seal"],
        "time": package["time"]
    }, ensure_ascii=False))

    r.lpush("cybra:blockchain:anchor:manual_ready", json.dumps({
        "type": "kibra_closed_sha_bridge_package",
        "sealed_id": package["sealed_id"],
        "bridge_sha_seal": package["bridge_sha_seal"],
        "real_external_tx": False,
        "manual_OWNER_approval_required": True,
        "time": package["time"]
    }, ensure_ascii=False))

    return package, outbox_file, sealed_file

def create_ai_tasks():
    tasks = [
        {
            "topic": "Finish AI Parliament tasks until completion",
            "type": "ai_until_done_task",
            "priority": "critical",
            "payload": {
                "goal": "Work until AI tasks are complete",
                "real_execution": False,
                "manual_OWNER_approval_required": True
            }
        },
        {
            "topic": "KIBRA pool monetization for AI block creation",
            "type": "kibra_bridge_pool_task",
            "priority": "critical",
            "payload": {
                "goal": "Monetize pool accounting through AI task credits and block creation rewards",
                "native_coin": True,
                "external_mint": False,
                "real_payment": False,
                "pool_reward_accounting": True,
                "manual_OWNER_approval_required": True
            }
        },
        {
            "topic": "KIBRA block network outbox bridge",
            "type": "kibra_bridge_pool_task",
            "priority": "critical",
            "payload": {
                "goal": "Package KIBRA blocks into closed SHA bridge outbox for future network broadcast",
                "closed_sha_bridge": True,
                "real_network_broadcast_now": False,
                "manual_OWNER_approval_required": True
            }
        },
        {
            "topic": "KIBRA bridge SHA seal verification",
            "type": "kibra_bridge_pool_task",
            "priority": "critical",
            "payload": {
                "goal": "Verify bridge package SHA seal and prepare manual anchor package",
                "closed_sha_seal": True,
                "external_anchor_manual_only": True
            }
        }
    ]

    for t in tasks:
        t["payload"].update({
            "no_private_keys": True,
            "no_seed_phrase": True,
            "no_automatic_payment": True,
            "no_automatic_exchange_launch": True,
            "no_market_manipulation": True,
            "no_guaranteed_profit": True
        })
        r.lpush(AIQ, json.dumps(t, ensure_ascii=False))

    return tasks

def report(submit_ai=False):
    for d in ["posts", "feeds", "proofs", "data/kibra_bridge/outbox", "data/kibra_bridge/sealed", "data/kibra_pool_monetization"]:
        (ROOT / d).mkdir(parents=True, exist_ok=True)

    package, outbox_file, sealed_file = build_bridge_package()
    tasks = create_ai_tasks() if submit_ai else []

    report_obj = {
        "status": "kibra_bridge_pool_monetization_report_generated",
        "time": time.time(),
        "time_iso": now_iso(),
        "submit_ai": submit_ai,
        "ai_tasks_created": len(tasks),
        "latest_kibra_hash": latest_hash(),
        "bridge_package": {
            "sealed_id": package["sealed_id"],
            "bridge_sha_seal": package["bridge_sha_seal"],
            "blocks_count": package["blocks_count"],
            "outbox_file": str(outbox_file.relative_to(ROOT)),
            "sealed_file": str(sealed_file.relative_to(ROOT)),
            "real_network_broadcast_now": False,
            "manual_OWNER_approval_required": True
        },
        "redis": {
            "ai_queue": redis_len(AIQ),
            "bridge_outbox": redis_len(OUTBOX),
            "sealed_packages": redis_len(SEALED),
            "manual_anchor_ready": redis_len("cybra:blockchain:anchor:manual_ready"),
            "parliament_queue": redis_len("cybra:parliament:queue"),
            "parliament_failed": redis_len("cybra:parliament:failed")
        },
        "safety": {
            "real_payment_execution": False,
            "external_mint": False,
            "real_network_broadcast_now": False,
            "automatic_bridge_broadcast": False,
            "manual_OWNER_approval_required": True
        }
    }

    report_obj["double_sha"] = dsha(json.dumps(report_obj, ensure_ascii=False, sort_keys=True))

    (ROOT / "feeds/kibra_bridge_pool_monetization_report.json").write_text(
        json.dumps(report_obj, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )

    md = f"""# KIBRA Bridge / Pool / Monetization / Until Done

Status: **generated**

## What was created

- Pool monetization model: **created**
- AI block creation pool task: **created**
- Closed SHA bridge: **created**
- Network outbox package: **created**
- Manual anchor ready: **created**
- Real network broadcast now: **false**
- External mint: **false**
- Manual OWNER approval required: **true**

## Bridge

- Sealed ID: `{package['sealed_id']}`
- Bridge SHA seal: `{package['bridge_sha_seal']}`
- Blocks packed: **{package['blocks_count']}**
- Outbox file: `{outbox_file.relative_to(ROOT)}`
- Sealed file: `{sealed_file.relative_to(ROOT)}`

## Redis

- AI queue: {report_obj['redis']['ai_queue']}
- Bridge outbox: {report_obj['redis']['bridge_outbox']}
- Sealed packages: {report_obj['redis']['sealed_packages']}
- Manual anchor ready: {report_obj['redis']['manual_anchor_ready']}

## Safety

This module does **not** broadcast to a real external network.  
It creates a sealed bridge package and network outbox only.

## Double SHA

`{report_obj['double_sha']}`
"""

    (ROOT / "posts/kibra_bridge_pool_monetization_report.md").write_text(md, encoding="utf-8")

    with (ROOT / "proofs/kibra_bridge_pool_monetization.sha256").open("w") as f:
        subprocess.run([
            "sha256sum",
            "parliament/kibra_bridge/policy.json",
            "parliament/departments/kibra_bridge_department/department.json",
            "data/kibra_pool_monetization/pool_monetization_plan.json",
            str(outbox_file.relative_to(ROOT)),
            str(sealed_file.relative_to(ROOT)),
            "feeds/kibra_bridge_pool_monetization_report.json",
            "posts/kibra_bridge_pool_monetization_report.md"
        ], cwd=ROOT, stdout=f, stderr=subprocess.DEVNULL)

    r.lpush(AUDIT, json.dumps({
        "status": "bridge_pool_report_generated",
        "sealed_id": package["sealed_id"],
        "bridge_sha_seal": package["bridge_sha_seal"],
        "submit_ai": submit_ai,
        "time": report_obj["time"]
    }, ensure_ascii=False))

    print("✅ KIBRA bridge/pool/monetization report generated")
    print("Sealed ID:", package["sealed_id"])
    print("Bridge SHA seal:", package["bridge_sha_seal"])
    print("AI tasks created:", len(tasks))
    print("Report: posts/kibra_bridge_pool_monetization_report.md")

def main():
    import sys
    cmd = sys.argv[1] if len(sys.argv) > 1 else "report"
    if cmd == "report":
        report(submit_ai=False)
    elif cmd == "submit-ai":
        report(submit_ai=True)
    else:
        raise SystemExit("Usage: report|submit-ai")

if __name__ == "__main__":
    main()
