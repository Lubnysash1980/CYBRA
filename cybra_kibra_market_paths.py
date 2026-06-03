#!/usr/bin/env python3
import json, time, hashlib, subprocess
from pathlib import Path
from decimal import Decimal, getcontext
import redis

getcontext().prec = 50

ROOT = Path.home() / "CYBRA"
r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

AUDIT = "cybra:kibra:market_price_paths:audit"
AI_BLOCK_INBOX = "cybra:ai:tasks:block_inbox"

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

def load_json(path):
    p = ROOT / path
    if not p.exists():
        return {}
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception:
        return {}

def count_files(pattern):
    return len(list(ROOT.glob(pattern)))

def latest_hash():
    p = ROOT / "blockchain/kibra_chain/latest.block.hash"
    return p.read_text().strip() if p.exists() else None

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

def accounting():
    reward = load_json("data/kibra_mint_finance/reward_policy.json")
    block_reward = Decimal(str(reward.get("block_reward_kibra", "100")))
    task_reward = Decimal(str(reward.get("task_block_reward_kibra", "100")))

    main_blocks = Decimal(count_files("blockchain/kibra_chain/blocks/block_*.json"))
    task_blocks = Decimal(count_files("blockchain/kibra_chain/task_blocks/*.json"))
    total = main_blocks * block_reward + task_blocks * task_reward

    return {
        "main_blocks": int(main_blocks),
        "task_blocks": int(task_blocks),
        "block_reward_kibra": str(block_reward),
        "task_block_reward_kibra": str(task_reward),
        "total_mined_kibra": str(total)
    }

def make_dex_package(acc):
    total = Decimal(acc["total_mined_kibra"])
    obj = {
        "status": "dex_pool_readiness_prepared",
        "path": "DEX_POOL_READINESS",
        "purpose": "Підготувати DEX pool proof для підтвердження ринкової ціни KIBRA.",
        "chain_options": [
            "EVM-compatible chain after wrapped/bridge representation",
            "Solana DEX after wrapped/bridge representation",
            "other DEX after provider review"
        ],
        "required_for_real_price": [
            "real pool address",
            "real quote reserve",
            "real KIBRA/wrapped-KIBRA reserve",
            "pool proof / tx proof",
            "explorer URL",
            "provider review",
            "OWNER approval"
        ],
        "suggested_pilot_reserve": {
            "kibra_1_percent": str(total * Decimal("0.01")),
            "kibra_5_percent": str(total * Decimal("0.05")),
            "kibra_10_percent": str(total * Decimal("0.10")),
            "quote_usd_example_for_0_01": str(total * Decimal("0.01") * Decimal("0.01")),
            "quote_usd_example_for_0_10": str(total * Decimal("0.01") * Decimal("0.10")),
            "quote_usd_example_for_1_00": str(total * Decimal("0.01") * Decimal("1.00"))
        },
        "real_pool_now": False,
        "real_market_confirmed": False,
        "manual_OWNER_approval_required": True,
        "time": time.time(),
        "time_iso": now_iso()
    }
    obj["double_sha"] = dsha(json.dumps(obj, ensure_ascii=False, sort_keys=True))
    out = ROOT / "data/kibra_market/dex_pool_readiness/dex_pool_readiness.json"
    out.write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")
    return obj

def make_orderbook_backend_package():
    obj = {
        "status": "orderbook_backend_provider_package_prepared",
        "path": "ORDERBOOK_BACKEND_PROVIDER",
        "purpose": "Створити backend-provider proof: bid/ask, depth, spread, provider proof reference.",
        "local_backend_status": "prepared_as_internal_backend_package",
        "becomes_real_market_proof_only_if": [
            "real external buyers/sellers exist",
            "provider identity is verified",
            "bid and ask are real",
            "proof_reference exists",
            "provider_review_passed=true",
            "owner_approval=true"
        ],
        "orderbook_snapshot_file": "data/kibra_market/orderbook_backend_provider/orderbook_snapshot.json",
        "real_market_confirmed": False,
        "manual_OWNER_approval_required": True,
        "time": time.time(),
        "time_iso": now_iso()
    }
    obj["double_sha"] = dsha(json.dumps(obj, ensure_ascii=False, sort_keys=True))
    out = ROOT / "data/kibra_market/orderbook_backend_provider/backend_provider_package.json"
    out.write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")
    return obj

def make_orderbook_snapshot(bid="0", ask="0", depth_kibra="0", provider="internal_backend_draft"):
    bid_d = Decimal(str(bid))
    ask_d = Decimal(str(ask))
    mid = (bid_d + ask_d) / Decimal("2") if bid_d > 0 and ask_d > 0 else Decimal("0")
    spread = ((ask_d - bid_d) / mid * Decimal("100")) if mid > 0 else Decimal("0")

    obj = {
        "status": "internal_orderbook_snapshot_created",
        "provider_name": provider,
        "market_pair": "KIBRA/USD",
        "bid": str(bid_d),
        "ask": str(ask_d),
        "mid_price": str(mid),
        "spread_percent": str(spread),
        "depth_kibra": str(depth_kibra),
        "real_market_confirmed": False,
        "provider_review_passed": False,
        "owner_approval": False,
        "note": "Це внутрішній backend snapshot. Для real market proof потрібні зовнішні реальні bid/ask і provider review.",
        "time": time.time(),
        "time_iso": now_iso()
    }
    obj["double_sha"] = dsha(json.dumps(obj, ensure_ascii=False, sort_keys=True))
    out = ROOT / "data/kibra_market/orderbook_backend_provider/orderbook_snapshot.json"
    out.write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")
    return obj

def make_peg_package(acc):
    total = Decimal(acc["total_mined_kibra"])

    prices = ["0.01", "0.10", "1.00"]
    reserve_options = {}
    for p in prices:
        price = Decimal(p)
        reserve_options[f"peg_usd_{p}"] = {
            "price_usd_per_kibra": p,
            "reserve_required_for_total_mined": str(total * price),
            "reserve_required_for_10_percent_float": str(total * Decimal("0.10") * price),
            "reserve_required_for_5_percent_float": str(total * Decimal("0.05") * price)
        }

    obj = {
        "status": "reserve_backed_peg_package_prepared",
        "path": "RESERVE_BACKED_PEG",
        "purpose": "Підготувати модель привʼязки KIBRA до резерву USD/UAH/іншого активу.",
        "reserve_options": reserve_options,
        "required_for_real_peg": [
            "real reserve amount",
            "reserve custody/provider proof",
            "redemption policy",
            "legal/AML/tax review",
            "OWNER approval",
            "published proof"
        ],
        "real_peg_now": False,
        "real_market_confirmed": False,
        "manual_OWNER_approval_required": True,
        "time": time.time(),
        "time_iso": now_iso()
    }
    obj["double_sha"] = dsha(json.dumps(obj, ensure_ascii=False, sort_keys=True))
    out = ROOT / "data/kibra_market/reserve_backed_peg/peg_package.json"
    out.write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")
    return obj

def make_external_anchor_request(acc):
    obj = {
        "status": "external_anchor_request_prepared",
        "path": "EXTERNAL_BLOCKCHAIN_ANCHOR",
        "purpose": "Публічно заякорити latest KIBRA hash, shares, pool proof і market-path package root у зовнішній блокчейн.",
        "latest_kibra_hash": latest_hash(),
        "accounting": acc,
        "file_hashes": {
            "pool_confirm": file_sha("feeds/kibra_pool_confirm_report.json"),
            "stats": file_sha("feeds/kibra_stats_recommendations_report.json"),
            "liquidity": file_sha("feeds/kibra_mint_liquidity_report.json"),
            "price_committee": file_sha("feeds/kibra_price_confirmation_committee_report.json")
        },
        "confirms_price": False,
        "supports_price_confirmation": True,
        "external_tx_now": False,
        "manual_OWNER_approval_required": True,
        "time": time.time(),
        "time_iso": now_iso()
    }
    obj["anchor_root"] = dsha(json.dumps(obj, ensure_ascii=False, sort_keys=True))
    out = ROOT / "data/kibra_market/external_anchor_requests/price_paths_anchor_request.json"
    out.write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")
    return obj

def make_ai_tasks(acc, dex, orderbook, peg, anchor):
    tasks = [
        {
            "topic": "KIBRA DEX pool readiness proof",
            "type": "kibra_mint_liquidity_task",
            "priority": "critical",
            "payload": {
                "source": "kibra_market_price_paths_department",
                "path": "DEX_POOL_READINESS",
                "goal": "Підготувати реальний DEX pool proof: pool address, reserves, tx proof, explorer URL, provider review, OWNER approval.",
                "dex_package_sha": dex["double_sha"],
                "convert_to_mining_block_first": True,
                "real_pool_now": False,
                "real_sell_now": False,
                "fake_price": False,
                "fake_volume": False,
                "manual_OWNER_approval_required": True
            }
        },
        {
            "topic": "KIBRA orderbook backend provider proof",
            "type": "kibra_price_confirmation_committee_task",
            "priority": "critical",
            "payload": {
                "source": "kibra_market_price_paths_department",
                "path": "ORDERBOOK_BACKEND_PROVIDER",
                "goal": "Підготувати backend-provider/orderbook proof із bid/ask/depth/spread і правилами provider review.",
                "orderbook_package_sha": orderbook["double_sha"],
                "convert_to_mining_block_first": True,
                "real_market_confirmed": False,
                "manual_OWNER_approval_required": True
            }
        },
        {
            "topic": "KIBRA reserve-backed peg proof",
            "type": "kibra_mint_management_task",
            "priority": "critical",
            "payload": {
                "source": "kibra_market_price_paths_department",
                "path": "RESERVE_BACKED_PEG",
                "goal": "Підготувати reserve-backed peg: reserve amount, custody proof, redemption policy, provider review, OWNER approval.",
                "peg_package_sha": peg["double_sha"],
                "convert_to_mining_block_first": True,
                "real_peg_now": False,
                "real_payment_now": False,
                "manual_OWNER_approval_required": True
            }
        },
        {
            "topic": "KIBRA external blockchain anchor for shares and market-path package",
            "type": "kibra_bridge_pool_task",
            "priority": "high",
            "payload": {
                "source": "kibra_market_price_paths_department",
                "path": "EXTERNAL_BLOCKCHAIN_ANCHOR",
                "goal": "Підготувати зовнішній anchor latest hash/shares/market package root. Anchor підтримує доказ, але не підтверджує ціну сам по собі.",
                "anchor_root": anchor["anchor_root"],
                "convert_to_mining_block_first": True,
                "external_tx_now": False,
                "manual_OWNER_approval_required": True
            }
        },
        {
            "topic": "KIBRA real market price gate completion",
            "type": "kibra_mint_liquidity_task",
            "priority": "critical",
            "payload": {
                "source": "kibra_market_price_paths_department",
                "path": "REAL_MARKET_PRICE_GATE",
                "goal": "Заповнити real_market_proof.json тільки після DEX/orderbook/provider/peg proof і перевірити gate.",
                "convert_to_mining_block_first": True,
                "real_market_confirmed_now": False,
                "action": "bash cybra_real_market_price_gate.sh template && bash cybra_real_market_price_gate.sh verify",
                "manual_OWNER_approval_required": True
            }
        }
    ]
    return tasks

def report(submit_ai=False):
    for d in [
        "posts", "feeds", "proofs",
        "data/kibra_market/paths",
        "data/kibra_market/dex_pool_readiness",
        "data/kibra_market/orderbook_backend_provider",
        "data/kibra_market/reserve_backed_peg",
        "data/kibra_market/external_anchor_requests"
    ]:
        (ROOT / d).mkdir(parents=True, exist_ok=True)

    acc = accounting()
    dex = make_dex_package(acc)
    orderbook = make_orderbook_backend_package()
    peg = make_peg_package(acc)
    anchor = make_external_anchor_request(acc)
    tasks = make_ai_tasks(acc, dex, orderbook, peg, anchor)

    if submit_ai:
        for t in tasks:
            r.lpush(AI_BLOCK_INBOX, json.dumps(t, ensure_ascii=False))

    paths = {
        "status": "market_price_paths_prepared",
        "time": time.time(),
        "time_iso": now_iso(),
        "accounting": acc,
        "latest_kibra_hash": latest_hash(),
        "possible_now": [
            "prepare DEX pool readiness package",
            "prepare orderbook/backend provider package",
            "prepare reserve-backed peg package",
            "prepare external blockchain anchor request",
            "send AI tasks to block inbox"
        ],
        "not_done_automatically": [
            "real DEX pool creation",
            "real external transaction",
            "real payment",
            "real sell",
            "real market confirmation without proof"
        ],
        "files": {
            "dex": "data/kibra_market/dex_pool_readiness/dex_pool_readiness.json",
            "orderbook": "data/kibra_market/orderbook_backend_provider/backend_provider_package.json",
            "peg": "data/kibra_market/reserve_backed_peg/peg_package.json",
            "anchor": "data/kibra_market/external_anchor_requests/price_paths_anchor_request.json"
        },
        "ai_tasks_prepared": len(tasks),
        "ai_tasks_submitted_to_block_inbox": len(tasks) if submit_ai else 0,
        "queues": {
            "block_inbox": redis_len(AI_BLOCK_INBOX),
            "task_block_mempool": redis_len("cybra:kibra:task_blocks:mempool"),
            "task_blocks_mined": redis_len("cybra:kibra:task_blocks:mined"),
            "pool_mining_blocks": redis_len("cybra:kibra:pool:mining_blocks"),
            "parliament_queue": redis_len("cybra:parliament:queue"),
            "parliament_failed": redis_len("cybra:parliament:failed")
        },
        "git": {
            "branch": git_cmd(["git", "branch", "--show-current"]),
            "commit": git_cmd(["git", "rev-parse", "--short", "HEAD"]),
            "dirty_files": len(git_cmd(["git", "status", "--short"]).splitlines())
        },
        "safety": {
            "real_market_confirmed": False,
            "real_sell_now": False,
            "real_payment_now": False,
            "external_tx_now": False,
            "fake_price": False,
            "fake_volume": False,
            "wash_trading": False,
            "manual_OWNER_approval_required": True
        }
    }

    paths["double_sha"] = dsha(json.dumps(paths, ensure_ascii=False, sort_keys=True))

    (ROOT / "data/kibra_market/paths/available_price_paths.json").write_text(
        json.dumps(paths, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )

    (ROOT / "feeds/kibra_market_price_paths_report.json").write_text(
        json.dumps(paths, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )

    md = f"""# KIBRA Market Price Paths

Status: **prepared**

## What is possible now

1. DEX pool readiness package
2. Orderbook/backend-provider proof package
3. Reserve-backed peg package
4. External blockchain anchor request
5. AI tasks to block inbox and mining blocks

## Accounting

- Main blocks: **{acc['main_blocks']}**
- Task blocks: **{acc['task_blocks']}**
- Total mined KIBRA: **{acc['total_mined_kibra']}**
- Latest KIBRA hash: `{latest_hash()}`

## Files

- DEX: `data/kibra_market/dex_pool_readiness/dex_pool_readiness.json`
- Orderbook/backend provider: `data/kibra_market/orderbook_backend_provider/backend_provider_package.json`
- Reserve-backed peg: `data/kibra_market/reserve_backed_peg/peg_package.json`
- External anchor request: `data/kibra_market/external_anchor_requests/price_paths_anchor_request.json`

## Rule

Internal blockchain and external anchor prove blocks/shares/hash.  
Market price is confirmed only by DEX pool / orderbook provider / reserve-backed peg proof.

## AI tasks

- Prepared: **{len(tasks)}**
- Submitted to block inbox: **{len(tasks) if submit_ai else 0}**

## Safety

- Real market confirmed: **false**
- Real sell now: **false**
- External tx now: **false**
- Fake price: **false**
- Fake volume: **false**
- OWNER approval required: **true**

## Double SHA

`{paths['double_sha']}`
"""
    (ROOT / "posts/kibra_market_price_paths_report.md").write_text(md, encoding="utf-8")

    with (ROOT / "proofs/kibra_market_price_paths.sha256").open("w") as f:
        subprocess.run([
            "sha256sum",
            "parliament/departments/kibra_mint_repair_department/price_confirmation_committee/market_paths_department/department.json",
            "data/kibra_market/paths/available_price_paths.json",
            "data/kibra_market/dex_pool_readiness/dex_pool_readiness.json",
            "data/kibra_market/orderbook_backend_provider/backend_provider_package.json",
            "data/kibra_market/reserve_backed_peg/peg_package.json",
            "data/kibra_market/external_anchor_requests/price_paths_anchor_request.json",
            "feeds/kibra_market_price_paths_report.json",
            "posts/kibra_market_price_paths_report.md"
        ], cwd=ROOT, stdout=f, stderr=subprocess.DEVNULL)

    r.lpush(AUDIT, json.dumps({
        "status": "market_price_paths_report_generated",
        "submit_ai": submit_ai,
        "ai_tasks": len(tasks),
        "double_sha": paths["double_sha"],
        "time": paths["time"]
    }, ensure_ascii=False))

    print("✅ KIBRA market price paths prepared")
    print("TOTAL_MINED_KIBRA:", acc["total_mined_kibra"])
    print("AI_TASKS_PREPARED:", len(tasks))
    print("AI_SUBMITTED_TO_BLOCK_INBOX:", len(tasks) if submit_ai else 0)
    print("REPORT: posts/kibra_market_price_paths_report.md")
    print("PROOF: proofs/kibra_market_price_paths.sha256")

def status():
    print("PONG" if r.ping() else "NO REDIS")
    print("MARKET_PATHS_AUDIT:", redis_len(AUDIT))
    print("BLOCK_INBOX:", redis_len(AI_BLOCK_INBOX))
    print("TASK_BLOCK_MEMPOOL:", redis_len("cybra:kibra:task_blocks:mempool"))
    print("TASK_BLOCKS_MINED:", redis_len("cybra:kibra:task_blocks:mined"))
    print("POOL_MINING_BLOCKS:", redis_len("cybra:kibra:pool:mining_blocks"))
    print("PARLIAMENT_QUEUE:", redis_len("cybra:parliament:queue"))
    print("PARLIAMENT_FAILED:", redis_len("cybra:parliament:failed"))
    print("REPORT_EXISTS:", (ROOT / "posts/kibra_market_price_paths_report.md").exists())

def main():
    import sys
    cmd = sys.argv[1] if len(sys.argv) > 1 else "report"

    if cmd == "report":
        report(False)
    elif cmd == "submit-ai":
        report(True)
    elif cmd == "status":
        status()
    elif cmd == "orderbook-snapshot":
        bid = sys.argv[2] if len(sys.argv) > 2 else "0"
        ask = sys.argv[3] if len(sys.argv) > 3 else "0"
        depth = sys.argv[4] if len(sys.argv) > 4 else "0"
        provider = sys.argv[5] if len(sys.argv) > 5 else "internal_backend_draft"
        obj = make_orderbook_snapshot(bid, ask, depth, provider)
        print(json.dumps(obj, ensure_ascii=False, indent=2))
    else:
        raise SystemExit("Usage: report|submit-ai|status|orderbook-snapshot <bid> <ask> <depth> [provider]")

if __name__ == "__main__":
    main()
