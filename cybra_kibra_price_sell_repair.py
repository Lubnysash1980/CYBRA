#!/usr/bin/env python3
import json, time, hashlib, shutil, subprocess
from decimal import Decimal, getcontext
from pathlib import Path
import redis

getcontext().prec = 50

ROOT = Path.home() / "CYBRA"
r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

AUDIT = "cybra:kibra_price_sell_repair:audit"
SELL_PROPOSALS = "cybra:kibra:sell_proposals"
BROKEN_BLOCKS = "cybra:kibra:broken_blocks"
REPAIR_QUEUE = "cybra:kibra:mint_repair:queue"
AIQ = "cybra:ai:tasks:kibra_price_sell_repair"

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

def scan_blocks():
    block_dir = ROOT / "blockchain/kibra_chain/blocks"
    broken = []
    good = []

    if not block_dir.exists():
        return good, [{
            "reason": "blocks_directory_missing",
            "path": "blockchain/kibra_chain/blocks"
        }]

    for f in sorted(block_dir.glob("block_*.json")):
        rel = str(f.relative_to(ROOT))
        try:
            obj = json.loads(f.read_text(encoding="utf-8"))
            if not isinstance(obj, dict) or len(obj) == 0:
                raise ValueError("empty_or_not_object")

            block_hash_like = any(k in obj for k in [
                "hash", "block_hash", "double_sha", "pow_hash", "current_hash", "latest_hash"
            ])

            good.append({
                "file": rel,
                "sha256": file_sha(rel),
                "hash_field_detected": block_hash_like
            })

        except Exception as e:
            item = {
                "file": rel,
                "reason": str(e),
                "sha256": file_sha(rel)
            }
            broken.append(item)

            target = ROOT / "data/kibra_mint_repair/broken" / f.name
            try:
                shutil.copy2(f, target)
            except Exception:
                pass

            r.lpush(BROKEN_BLOCKS, json.dumps(item, ensure_ascii=False))
            r.lpush(REPAIR_QUEUE, json.dumps({
                "type": "repair_or_replacement_block",
                "broken_block": item,
                "department": "kibra_mint_repair_department",
                "real_network_release": False,
                "manual_OWNER_approval_required": True,
                "time": time.time()
            }, ensure_ascii=False))

    return good, broken

def chain_verify():
    try:
        cp = subprocess.run(
            ["bash", "cybra_kibra_chain.sh", "verify"],
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=120
        )
        return {
            "ok": cp.returncode == 0,
            "returncode": cp.returncode,
            "output_tail": cp.stdout[-1200:]
        }
    except Exception as e:
        return {
            "ok": False,
            "error": str(e)
        }

def market_price():
    """
    Market price exists only if real pool reserves/orderbook/trades are recorded.
    pool_reserves format:
    {
      "source": "real_pool_or_orderbook",
      "quote_reserve_usd": "1000",
      "kibra_reserve": "1000000"
    }
    """
    reserves = load_json("data/kibra_market/pool_reserves.json")

    if reserves:
        try:
            quote = Decimal(str(reserves.get("quote_reserve_usd", "0")))
            kibra = Decimal(str(reserves.get("kibra_reserve", "0")))
            if quote > 0 and kibra > 0:
                price = quote / kibra
                return {
                    "status": "market_reference_price_available",
                    "price_usd_per_kibra": str(price),
                    "source": reserves.get("source", "pool_reserves"),
                    "quote_reserve_usd": str(quote),
                    "kibra_reserve": str(kibra),
                    "real_market_confirmed": bool(reserves.get("real_market_confirmed", False))
                }
        except Exception as e:
            return {
                "status": "invalid_price_source",
                "error": str(e),
                "price_usd_per_kibra": "0",
                "real_market_confirmed": False
            }

    return {
        "status": "no_real_market_price_yet",
        "price_usd_per_kibra": "0",
        "reason": "confirmed blocks prove chain/emission, but market price requires liquidity, buyers, orderbook or pool reserves",
        "real_market_confirmed": False
    }

def create_sell_proposal(price_obj):
    price = Decimal(str(price_obj.get("price_usd_per_kibra", "0")))

    proposal = {
        "status": "sell_proposal_created" if price > 0 else "sell_blocked_no_market_price",
        "time": time.time(),
        "time_iso": now_iso(),
        "native_coin": "KIBRA",
        "sell_at_market_price": price > 0,
        "market_price_usd_per_kibra": str(price),
        "price_source": price_obj,
        "real_sell_execution_now": False,
        "automatic_exchange_trade": False,
        "manual_OWNER_approval_required": True,
        "rules": [
            "sell only after real market price exists",
            "sell only by staged proposal",
            "check liquidity depth",
            "check slippage",
            "no fake price",
            "no wash trading"
        ]
    }

    proposal["double_sha"] = dsha(json.dumps(proposal, ensure_ascii=False, sort_keys=True))

    (ROOT / "data/kibra_sell/latest_sell_proposal.json").write_text(
        json.dumps(proposal, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )

    r.lpush(SELL_PROPOSALS, json.dumps(proposal, ensure_ascii=False))
    return proposal

def create_ai_tasks(price_obj, broken):
    tasks = [
        {
            "topic": "KIBRA market price from real pool liquidity",
            "type": "kibra_price_sell_repair_task",
            "priority": "critical",
            "payload": {
                "goal": "Determine KIBRA price only from real liquidity/orderbook/pool reserves",
                "current_price": price_obj,
                "no_fake_price": True,
                "real_sell_execution_now": False,
                "manual_OWNER_approval_required": True
            }
        },
        {
            "topic": "KIBRA sell at market price proposal",
            "type": "kibra_price_sell_repair_task",
            "priority": "critical",
            "payload": {
                "goal": "Create sell proposal when market price exists",
                "sell_at_market_price": True,
                "automatic_trade": False,
                "slippage_check_required": True,
                "manual_OWNER_approval_required": True
            }
        },
        {
            "topic": "KIBRA broken block repair by native mint department",
            "type": "kibra_price_sell_repair_task",
            "priority": "critical",
            "payload": {
                "goal": "Send broken blocks back to mint repair department",
                "broken_blocks_found": len(broken),
                "repair_queue": "cybra:kibra:mint_repair:queue",
                "replacement_block_required_if_needed": True,
                "real_network_release": False,
                "manual_OWNER_approval_required": True
            }
        },
        {
            "topic": "KIBRA pool miners catch blocks and generate pool reward accounting",
            "type": "kibra_bridge_pool_task",
            "priority": "high",
            "payload": {
                "goal": "Pool miners create/catch blocks, validated blocks get reward accounting",
                "native_coin": True,
                "external_mint": False,
                "real_payment": False,
                "pool_accounting_only": True
            }
        },
        {
            "topic": "AI Parliament finish KIBRA market and repair tasks until done",
            "type": "ai_until_done_task",
            "priority": "critical",
            "payload": {
                "goal": "Work until KIBRA price/sell/repair AI tasks are completed",
                "real_execution": False,
                "manual_OWNER_approval_required": True
            }
        }
    ]

    for t in tasks:
        t["payload"].update({
            "no_private_keys": True,
            "no_seed_phrase": True,
            "no_automatic_payment": True,
            "no_automatic_external_tx": True,
            "no_market_manipulation": True,
            "no_guaranteed_profit": True
        })
        r.lpush(AIQ, json.dumps(t, ensure_ascii=False))

    return tasks

def report(submit_ai=False):
    for d in ["posts", "feeds", "proofs", "data/kibra_market", "data/kibra_sell", "data/kibra_mint_repair/broken", "data/kibra_mint_repair/repaired"]:
        (ROOT / d).mkdir(parents=True, exist_ok=True)

    good, broken = scan_blocks()
    verify = chain_verify()
    price_obj = market_price()
    sell = create_sell_proposal(price_obj)
    tasks = create_ai_tasks(price_obj, broken) if submit_ai else []

    report_obj = {
        "status": "kibra_price_sell_repair_report_generated",
        "time": time.time(),
        "time_iso": now_iso(),
        "latest_kibra_hash": latest_hash(),
        "chain_verify": verify,
        "blocks": {
            "good_count": len(good),
            "broken_count": len(broken),
            "broken": broken
        },
        "market_price": price_obj,
        "sell_proposal": sell,
        "ai_tasks_created": len(tasks),
        "submit_ai": submit_ai,
        "redis": {
            "sell_proposals": redis_len(SELL_PROPOSALS),
            "broken_blocks": redis_len(BROKEN_BLOCKS),
            "repair_queue": redis_len(REPAIR_QUEUE),
            "ai_queue": redis_len(AIQ),
            "parliament_queue": redis_len("cybra:parliament:queue"),
            "parliament_failed": redis_len("cybra:parliament:failed")
        },
        "safety": {
            "real_sell_execution_now": False,
            "automatic_trade": False,
            "automatic_payment": False,
            "automatic_external_tx": False,
            "manual_OWNER_approval_required": True
        }
    }

    report_obj["double_sha"] = dsha(json.dumps(report_obj, ensure_ascii=False, sort_keys=True))

    (ROOT / "feeds/kibra_price_sell_repair_report.json").write_text(
        json.dumps(report_obj, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )

    md = f"""# KIBRA Price / Sell / Mint Repair Report

Status: **generated**

## Logic

- Confirmed blocks prove KIBRA chain/emission.
- Market price appears only from real liquidity, buyers, orderbook or pool reserves.
- Sell at market price creates proposal first.
- Broken blocks return to Mint Repair Department.

## Chain

- Latest KIBRA hash: `{latest_hash()}`
- Chain verify OK: **{verify.get('ok')}**
- Good blocks scanned: **{len(good)}**
- Broken blocks found: **{len(broken)}**

## Market price

- Status: **{price_obj.get('status')}**
- Price USD per KIBRA: `{price_obj.get('price_usd_per_kibra')}`
- Real market confirmed: **{price_obj.get('real_market_confirmed')}**

## Sell

- Sell proposal status: **{sell.get('status')}**
- Real sell execution now: **false**
- Manual OWNER approval required: **true**

## Repair

- Broken block queue: **{report_obj['redis']['broken_blocks']}**
- Mint repair queue: **{report_obj['redis']['repair_queue']}**

## AI

- AI tasks created: **{len(tasks)}**
- AI queue: **{report_obj['redis']['ai_queue']}**

## Proof

Double SHA:

`{report_obj['double_sha']}`
"""

    (ROOT / "posts/kibra_price_sell_repair_report.md").write_text(md, encoding="utf-8")

    with (ROOT / "proofs/kibra_price_sell_repair.sha256").open("w") as f:
        subprocess.run([
            "sha256sum",
            "parliament/departments/kibra_market_price_committee/committee.json",
            "parliament/departments/kibra_mint_repair_department/department.json",
            "parliament/kibra_price_sell_repair/policy.json",
            "data/kibra_sell/latest_sell_proposal.json",
            "feeds/kibra_price_sell_repair_report.json",
            "posts/kibra_price_sell_repair_report.md"
        ], cwd=ROOT, stdout=f, stderr=subprocess.DEVNULL)

    r.lpush(AUDIT, json.dumps({
        "status": "kibra_price_sell_repair_report_generated",
        "price_status": price_obj.get("status"),
        "broken_blocks": len(broken),
        "submit_ai": submit_ai,
        "double_sha": report_obj["double_sha"],
        "time": report_obj["time"]
    }, ensure_ascii=False))

    print("✅ KIBRA price/sell/repair report generated")
    print("Price status:", price_obj.get("status"))
    print("Price USD:", price_obj.get("price_usd_per_kibra"))
    print("Broken blocks:", len(broken))
    print("AI tasks:", len(tasks))
    print("Report: posts/kibra_price_sell_repair_report.md")

def set_reserves(quote_usd, kibra_reserve, source):
    obj = {
        "source": source,
        "quote_reserve_usd": str(quote_usd),
        "kibra_reserve": str(kibra_reserve),
        "real_market_confirmed": False,
        "note": "Manual reserve input. Mark real_market_confirmed only after verified exchange/pool/orderbook proof.",
        "time": time.time(),
        "time_iso": now_iso()
    }
    (ROOT / "data/kibra_market").mkdir(parents=True, exist_ok=True)
    (ROOT / "data/kibra_market/pool_reserves.json").write_text(
        json.dumps(obj, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )
    print("✅ pool reserves recorded")
    print("Run: bash cybra_kibra_price.sh report")

def main():
    import sys
    cmd = sys.argv[1] if len(sys.argv) > 1 else "report"

    if cmd == "report":
        report(submit_ai=False)
    elif cmd == "submit-ai":
        report(submit_ai=True)
    elif cmd == "set-reserves":
        if len(sys.argv) < 4:
            raise SystemExit("Usage: set-reserves <quote_usd> <kibra_reserve> [source]")
        set_reserves(sys.argv[2], sys.argv[3], sys.argv[4] if len(sys.argv) > 4 else "manual_pool_reserves")
    else:
        raise SystemExit("Usage: report|submit-ai|set-reserves")

if __name__ == "__main__":
    main()
