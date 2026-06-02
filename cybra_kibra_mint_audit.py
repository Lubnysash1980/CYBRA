#!/usr/bin/env python3
import json
import time
import hashlib
import subprocess
from pathlib import Path

import redis

ROOT = Path.home() / "CYBRA"
r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

AUDIT = "cybra:kibra:mint_audit:audit"
RECS = "cybra:kibra:mint_audit:recommendations"
AIQ = "cybra:ai:tasks:kibra_mint_audit"

def sha(x):
    return hashlib.sha256(x.encode("utf-8")).hexdigest()

def dsha(x):
    return sha(sha(x))

def now_iso():
    return time.strftime("%Y-%m-%dT%H:%M:%S%z")

def exists(path):
    return (ROOT / path).exists()

def file_sha(path):
    p = ROOT / path
    if not p.exists():
        return None
    h = hashlib.sha256()
    with p.open("rb") as f:
        for c in iter(lambda: f.read(1024 * 1024), b""):
            h.update(c)
    return h.hexdigest()

def load_json(path):
    p = ROOT / path
    if not p.exists():
        return {}
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception:
        return {}

def redis_len(key):
    try:
        return r.llen(key)
    except Exception:
        return 0

def redis_scard(key):
    try:
        return r.scard(key)
    except Exception:
        return 0

def latest_hash():
    p = ROOT / "blockchain/kibra_chain/latest.block.hash"
    return p.read_text().strip() if p.exists() else None

def git_cmd(cmd):
    try:
        return subprocess.check_output(cmd, cwd=ROOT, text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return ""

def count_files(pattern):
    return len(list(ROOT.glob(pattern)))

def scan_required():
    required = {
        "native_kibra_policy": "parliament/native_kibra/policy/native_kibra_policy.json",
        "native_kibra_report": "feeds/native_kibra_ai_task_package.json",
        "kibra_chain_status": "feeds/kibra_token_chain_status.json",
        "kibra_latest_hash": "blockchain/kibra_chain/latest.block.hash",
        "pool_confirm_report": "feeds/kibra_pool_confirm_report.json",
        "difficulty_classes": "feeds/kibra_difficulty_classes_report.json",
        "bridge_report": "feeds/kibra_bridge_pool_monetization_report.json",
        "block_ai_support": "feeds/kibra_block_ai_support_report.json",
        "ai_tasks_to_blocks": "feeds/ai_tasks_to_mining_blocks_report.json",
        "price_sell_repair": "feeds/kibra_price_sell_repair_report.json",
        "mint_promotion": "feeds/kibra_mint_promotion_report.json",
        "promotion_page": "website/kibra/promotion.html",
        "mint_repair_department": "parliament/departments/kibra_mint_repair_department/department.json",
        "mint_promotion_department": "parliament/departments/kibra_mint_repair_department/promotion_department/department.json"
    }

    rows = []
    for name, path in required.items():
        rows.append({
            "name": name,
            "path": path,
            "exists": exists(path),
            "sha256": file_sha(path)
        })
    return rows

def scan_blocks():
    blocks = list((ROOT / "blockchain/kibra_chain/blocks").glob("block_*.json")) if exists("blockchain/kibra_chain/blocks") else []
    task_blocks = list((ROOT / "blockchain/kibra_chain/task_blocks").glob("*.json")) if exists("blockchain/kibra_chain/task_blocks") else []

    broken = []
    pool_tagged = 0
    shares_total = 0

    for f in blocks:
        try:
            obj = json.loads(f.read_text(encoding="utf-8"))
            text = json.dumps(obj, ensure_ascii=False).lower()
            if any(x in text for x in ["pool", "miner", "pool_id", "mining_pool", "pool_reward", "pool_accounting"]):
                pool_tagged += 1

            shares = obj.get("shares_count") or obj.get("shares") or 0
            if isinstance(shares, list):
                shares = len(shares)
            if isinstance(shares, int):
                shares_total += shares
        except Exception as e:
            broken.append({
                "file": str(f.relative_to(ROOT)),
                "error": str(e)
            })

    return {
        "blocks_total": len(blocks),
        "task_blocks_total": len(task_blocks),
        "pool_tagged_blocks": pool_tagged,
        "shares_total": shares_total,
        "broken_blocks_detected": broken
    }

def detect_gaps(required_rows, block_state):
    gaps = []

    for row in required_rows:
        if not row["exists"]:
            gaps.append({
                "level": "missing",
                "area": row["name"],
                "message": f"Missing required file: {row['path']}",
                "task_type": "kibra_mint_audit_task",
                "suggested_action": "repair_or_create_missing_module"
            })

    if block_state["blocks_total"] == 0:
        gaps.append({
            "level": "critical",
            "area": "blocks",
            "message": "No KIBRA blocks found.",
            "task_type": "kibra_token_chain_task",
            "suggested_action": "bash cybra_kibra_chain.sh mine 1"
        })

    if block_state["pool_tagged_blocks"] < block_state["blocks_total"]:
        gaps.append({
            "level": "warning",
            "area": "pool_attribution",
            "message": "Not all blocks have pool/miner attribution.",
            "task_type": "kibra_bridge_pool_task",
            "suggested_action": "bash cybra_pool_confirm_report.sh"
        })

    if block_state["task_blocks_total"] == 0:
        gaps.append({
            "level": "development",
            "area": "ai_task_blocks",
            "message": "No AI task mining blocks found.",
            "task_type": "ai_tasks_to_blocks_task",
            "suggested_action": "bash cybra_ai_blocks.sh cycle"
        })

    if redis_len("cybra:kibra:mint_repair:queue") > 0:
        gaps.append({
            "level": "repair",
            "area": "mint_repair_queue",
            "message": "Mint repair queue has items.",
            "task_type": "kibra_price_sell_repair_task",
            "suggested_action": "bash cybra_kibra_price.sh report"
        })

    if redis_len("cybra:kibra:broken_blocks") > 0:
        gaps.append({
            "level": "repair",
            "area": "broken_blocks",
            "message": "Broken blocks exist in Redis.",
            "task_type": "kibra_price_sell_repair_task",
            "suggested_action": "bash cybra_kibra_price.sh report"
        })

    if redis_len("cybra:parliament:failed") > 0:
        gaps.append({
            "level": "warning",
            "area": "parliament_failed",
            "message": "Parliament failed queue is not empty.",
            "task_type": "existing_tasks_activation_task",
            "suggested_action": "bash cybra_existing_tasks.sh repair"
        })

    return gaps

def make_ai_tasks(gaps):
    tasks = []

    for i, gap in enumerate(gaps, 1):
        tasks.append({
            "topic": f"KIBRA Mint Audit Repair {i}: {gap['area']}",
            "type": gap.get("task_type", "kibra_mint_audit_task"),
            "priority": "high",
            "payload": {
                "source": "kibra_mint_audit_department",
                "area": gap["area"],
                "audit_level": gap["level"],
                "message": gap["message"],
                "suggested_action": gap["suggested_action"],
                "real_payment": False,
                "real_sell": False,
                "fake_price": False,
                "fake_volume": False,
                "external_tx": False,
                "manual_OWNER_approval_required": True
            }
        })

    if not tasks:
        tasks.append({
            "topic": "KIBRA Mint Audit OK Evolution",
            "type": "kibra_mint_promotion_task",
            "priority": "normal",
            "payload": {
                "source": "kibra_mint_audit_department",
                "message": "No critical mint audit gaps found. Continue promotion, utility, bridge proof and AI-task block evolution.",
                "real_payment": False,
                "real_sell": False,
                "manual_OWNER_approval_required": True
            }
        })

    return tasks

def report(submit_ai=False):
    for d in ["posts", "feeds", "proofs", "data/kibra_mint_audit"]:
        (ROOT / d).mkdir(parents=True, exist_ok=True)

    required = scan_required()
    block_state = scan_blocks()
    gaps = detect_gaps(required, block_state)
    tasks = make_ai_tasks(gaps)

    if submit_ai:
        for t in tasks:
            r.lpush(AIQ, json.dumps(t, ensure_ascii=False))

    ok_files = len([x for x in required if x["exists"]])
    total_files = len(required)
    score = int((ok_files / max(1, total_files)) * 70)

    if block_state["blocks_total"] > 0:
        score += 10
    if block_state["pool_tagged_blocks"] == block_state["blocks_total"] and block_state["blocks_total"] > 0:
        score += 10
    if block_state["task_blocks_total"] > 0:
        score += 10

    score -= min(40, len(gaps) * 5)
    score = max(0, min(100, score))

    report_obj = {
        "status": "kibra_mint_audit_report_generated",
        "time": time.time(),
        "time_iso": now_iso(),
        "submit_ai": submit_ai,
        "score": score,
        "latest_kibra_hash": latest_hash(),
        "required_files": required,
        "block_state": block_state,
        "gaps": gaps,
        "ai_tasks_prepared": len(tasks),
        "ai_tasks_submitted": len(tasks) if submit_ai else 0,
        "redis": {
            "mint_audit_audit": redis_len(AUDIT),
            "mint_audit_recommendations": redis_len(RECS),
            "mint_audit_ai_queue": redis_len(AIQ),
            "parliament_queue": redis_len("cybra:parliament:queue"),
            "parliament_failed": redis_len("cybra:parliament:failed"),
            "task_block_mempool": redis_len("cybra:kibra:task_blocks:mempool"),
            "task_blocks_mined": redis_len("cybra:kibra:task_blocks:mined"),
            "pool_mining_blocks": redis_len("cybra:kibra:pool:mining_blocks"),
            "mint_repair_queue": redis_len("cybra:kibra:mint_repair:queue"),
            "broken_blocks": redis_len("cybra:kibra:broken_blocks")
        },
        "git": {
            "branch": git_cmd(["git", "branch", "--show-current"]),
            "commit": git_cmd(["git", "rev-parse", "--short", "HEAD"]),
            "dirty_files": len(git_cmd(["git", "status", "--short"]).splitlines())
        },
        "safety": {
            "real_payment": False,
            "real_sell": False,
            "fake_price": False,
            "fake_volume": False,
            "wash_trading": False,
            "guaranteed_profit": False,
            "external_tx": False,
            "manual_OWNER_approval_required": True
        }
    }

    report_obj["double_sha"] = dsha(json.dumps(report_obj, ensure_ascii=False, sort_keys=True))

    (ROOT / "feeds/kibra_mint_audit_report.json").write_text(
        json.dumps(report_obj, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )

    (ROOT / "data/kibra_mint_audit/ai_tasks.json").write_text(
        json.dumps(tasks, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )

    req_md = ""
    for x in required:
        mark = "✅" if x["exists"] else "❌"
        req_md += f"- {mark} `{x['name']}` → `{x['path']}`\n"

    gaps_md = ""
    for g in gaps:
        gaps_md += f"- **{g['level']}** / `{g['area']}`: {g['message']} Action: `{g['suggested_action']}`\n"
    if not gaps_md:
        gaps_md = "- ✅ critical gaps not found\n"

    md = f"""# KIBRA Mint Audit Department

Status: **active**  
Parent: **KIBRA Mint Repair Department**

## Score

- Mint audit score: **{score}/100**
- Latest KIBRA hash: `{latest_hash()}`
- AI tasks prepared: **{len(tasks)}**
- AI tasks submitted now: **{len(tasks) if submit_ai else 0}**

## Block state

- Blocks total: **{block_state['blocks_total']}**
- Task blocks total: **{block_state['task_blocks_total']}**
- Pool-tagged blocks: **{block_state['pool_tagged_blocks']}**
- Shares total: **{block_state['shares_total']}**
- Broken block files detected: **{len(block_state['broken_blocks_detected'])}**

## Required modules

{req_md}

## Gaps / Recommendations

{gaps_md}

## Redis

- Parliament queue: **{report_obj['redis']['parliament_queue']}**
- Parliament failed: **{report_obj['redis']['parliament_failed']}**
- Task blocks mined: **{report_obj['redis']['task_blocks_mined']}**
- Pool mining blocks: **{report_obj['redis']['pool_mining_blocks']}**
- Mint repair queue: **{report_obj['redis']['mint_repair_queue']}**
- Broken blocks: **{report_obj['redis']['broken_blocks']}**

## Safety

- Real payment: **false**
- Real sell: **false**
- Fake price: **false**
- Fake volume: **false**
- Guaranteed profit: **false**
- External tx: **false**
- Manual OWNER approval required: **true**

## Double SHA

`{report_obj['double_sha']}`
"""

    (ROOT / "posts/kibra_mint_audit_report.md").write_text(md, encoding="utf-8")

    with (ROOT / "proofs/kibra_mint_audit.sha256").open("w") as f:
        subprocess.run([
            "sha256sum",
            "parliament/departments/kibra_mint_repair_department/audit_department/department.json",
            "parliament/kibra_mint_audit/policy.json",
            "feeds/kibra_mint_audit_report.json",
            "data/kibra_mint_audit/ai_tasks.json",
            "posts/kibra_mint_audit_report.md"
        ], cwd=ROOT, stdout=f, stderr=subprocess.DEVNULL)

    r.lpush(AUDIT, json.dumps({
        "status": "kibra_mint_audit_report_generated",
        "score": score,
        "gaps": len(gaps),
        "submit_ai": submit_ai,
        "double_sha": report_obj["double_sha"],
        "time": report_obj["time"]
    }, ensure_ascii=False))

    r.lpush(RECS, json.dumps({
        "status": "kibra_mint_audit_recommendations",
        "gaps": gaps,
        "time": report_obj["time"],
        "double_sha": report_obj["double_sha"]
    }, ensure_ascii=False))

    print("✅ KIBRA mint audit report generated")
    print("SCORE:", score)
    print("GAPS:", len(gaps))
    print("AI_TASKS_PREPARED:", len(tasks))
    print("AI_SUBMITTED:", submit_ai)
    print("REPORT: posts/kibra_mint_audit_report.md")
    print("PROOF: proofs/kibra_mint_audit.sha256")

def main():
    import sys
    cmd = sys.argv[1] if len(sys.argv) > 1 else "report"

    if cmd == "report":
        report(False)
    elif cmd == "submit-ai":
        report(True)
    else:
        raise SystemExit("Usage: report|submit-ai")

if __name__ == "__main__":
    main()
