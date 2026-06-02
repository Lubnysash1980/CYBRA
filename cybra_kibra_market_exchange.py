#!/usr/bin/env python3
import json, time, hashlib, subprocess
from pathlib import Path
import redis

ROOT = Path.home() / "CYBRA"
r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

AUDIT = "cybra:kibra_market:audit"
TASKS = "cybra:kibra_market:ai_tasks"

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

def git_cmd(cmd):
    try:
        return subprocess.check_output(cmd, cwd=ROOT, text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return ""

def latest_kibra_hash():
    p = ROOT / "blockchain/kibra_chain/latest.block.hash"
    return p.read_text().strip() if p.exists() else None

def build_ai_tasks():
    return [
        {
            "task_id": "KIBRA-MINT-001",
            "topic": "Prepare real KIBRA token mint readiness",
            "type": "finance_infrastructure_task",
            "department": "finance_department",
            "goal": "Підготувати реальний mint-пакет: supply, owner/pool allocation 60/40, metadata, authority policy, manual wallet signature.",
            "real_execution": False,
            "requires_manual_owner_approval": True
        },
        {
            "task_id": "KIBRA-POOL-001",
            "topic": "Prepare real KIBRA liquidity pool readiness",
            "type": "token_pool_ai_task",
            "department": "token_pool_ai",
            "goal": "Підготувати liquidity pool proposal: 60% owner / 40% pool, стартова ліквідність, ризики, slippage, manual approval.",
            "real_execution": False,
            "requires_manual_owner_approval": True
        },
        {
            "task_id": "KIBRA-PRICE-001",
            "topic": "Build KIBRA market price engine",
            "type": "monetization_department_task",
            "department": "monetization_department",
            "goal": "Створити модель ціни: не фейкова ціна, а oracle/DEX/CEX/liquidity based price після появи реального ринку.",
            "real_execution": False,
            "requires_manual_owner_approval": False
        },
        {
            "task_id": "KIBRA-BUYERS-001",
            "topic": "Build compliant buyers and volume strategy",
            "type": "monetization_department_task",
            "department": "monetization_department",
            "goal": "Створити план попиту: utility, сервіс-каталог, proof certificates, AI task credits, без wash trading і без pump.",
            "real_execution": False,
            "requires_manual_owner_approval": False
        },
        {
            "task_id": "KIBRA-SELL-001",
            "topic": "Build sell-without-crash model",
            "type": "finance_department_task",
            "department": "finance_department",
            "goal": "Створити модель продажу без обвалу: depth, slippage, daily volume limit, TWAP/manual staged sells.",
            "real_execution": False,
            "requires_manual_owner_approval": True
        },
        {
            "task_id": "KIBRA-APPROVAL-001",
            "topic": "Create manual OWNER approval package",
            "type": "owner_orchestrator_task",
            "department": "owner_orchestrator",
            "goal": "Підготувати manual OWNER approval для mint/pool/exchange/anchor, без автоматичного виконання.",
            "real_execution": False,
            "requires_manual_owner_approval": True
        },
        {
            "task_id": "KIBRA-EXCHANGE-001",
            "topic": "Design CYBRA own exchange architecture",
            "type": "kibra_market_exchange_task",
            "department": "exchange_department",
            "goal": "Створити архітектуру власної біржі: orderbook, AMM, wallet/custody policy, KYC/AML/legal, risk, matching engine sandbox.",
            "real_execution": False,
            "requires_manual_owner_approval": True
        },
        {
            "task_id": "KIBRA-EVO-001",
            "topic": "Run KIBRA market evolution deployment",
            "type": "evolution_deployment_task",
            "department": "evolution_deployment",
            "goal": "Підштовхнути систему до розвитку: mint readiness, pool readiness, exchange readiness, monetization, proof, audit.",
            "real_execution": False,
            "requires_manual_owner_approval": True
        }
    ]

def build_exchange_architecture():
    return {
        "status": "sandbox_architecture",
        "exchange_name": "CYBRA Exchange",
        "markets": [
            "KIBRA/USDT",
            "KIBRA/UAH",
            "KIBRA/USD",
            "KIBRA/XAU",
            "KIBRA/SOL"
        ],
        "modules": {
            "matching_engine": "sandbox_orderbook_first",
            "amm_pool": "proposal_only",
            "wallets": "non_custodial_or_provider_custody_review_required",
            "payments": "licensed_provider_required",
            "kyc_aml": "required_for_real_exchange",
            "market_price_engine": "oracle_liquidity_volume_based",
            "risk_engine": "slippage_depth_volume_limits",
            "proof_engine": "KIBRA_chain_double_sha_anchor"
        },
        "hard_limits": {
            "real_trading": False,
            "real_custody": False,
            "real_fiat_payments": False,
            "real_crypto_transfers": False,
            "manual_OWNER_approval_required": True
        }
    }

def build_market_readiness():
    return {
        "real_mint": {
            "status": "proposal_ready",
            "automatic": False,
            "requires": [
                "chain selection",
                "wallet authority",
                "metadata",
                "supply confirmation",
                "manual signature",
                "OWNER approval"
            ]
        },
        "real_liquidity_pool": {
            "status": "proposal_ready",
            "automatic": False,
            "requires": [
                "DEX selection",
                "pair selection",
                "initial liquidity",
                "pool allocation",
                "slippage risk",
                "manual transaction"
            ]
        },
        "market_price": {
            "status": "not_set_until_real_liquidity",
            "rule": "Price is discovered by real pool/orderbook/liquidity, not assigned manually."
        },
        "buyers_volume": {
            "status": "utility_strategy_required",
            "methods": [
                "AI task credits",
                "proof-chain verification service",
                "anchor package service",
                "developer support credits",
                "marketplace services",
                "community demand"
            ],
            "blocked": [
                "fake buyers",
                "wash trading",
                "pump promise"
            ]
        },
        "sell_without_crash": {
            "status": "model_required",
            "rules": [
                "sell only small percent of daily real volume",
                "simulate slippage",
                "depth check",
                "staged sells",
                "manual OWNER approval",
                "no market manipulation"
            ]
        }
    }

def report():
    r.ping()

    for p in ["posts", "feeds", "proofs", "data/exchange", "data/kibra_market"]:
        (ROOT / p).mkdir(parents=True, exist_ok=True)

    ai_tasks = build_ai_tasks()
    exchange = build_exchange_architecture()
    readiness = build_market_readiness()

    (ROOT / "data/exchange/cybra_exchange_architecture.json").write_text(
        json.dumps(exchange, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )

    (ROOT / "data/kibra_market/market_readiness_plan.json").write_text(
        json.dumps(readiness, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )

    report_obj = {
        "status": "kibra_market_exchange_plan_generated",
        "time": time.time(),
        "time_iso": now_iso(),
        "latest_kibra_hash": latest_kibra_hash(),
        "ai_tasks": ai_tasks,
        "exchange_architecture": exchange,
        "market_readiness": readiness,
        "real_execution": {
            "real_mint": False,
            "real_pool": False,
            "real_exchange_trading": False,
            "real_payment": False,
            "manual_OWNER_approval_required": True
        },
        "proof_inputs": {
            "market_policy": file_sha("parliament/kibra_market/kibra_market_exchange_policy.json"),
            "exchange_department": file_sha("parliament/departments/exchange_department/department.json"),
            "kibra_chain_proof": file_sha("proofs/kibra_token_chain.sha256"),
            "monetization_proof": file_sha("proofs/monetization_department.sha256"),
            "finance_infrastructure_proof": file_sha("proofs/finance_infrastructure.sha256")
        },
        "git": {
            "branch": git_cmd(["git", "branch", "--show-current"]),
            "commit": git_cmd(["git", "rev-parse", "--short", "HEAD"]),
            "dirty_files": len(git_cmd(["git", "status", "--short"]).splitlines())
        }
    }

    report_obj["double_sha"] = dsha(json.dumps(report_obj, ensure_ascii=False, sort_keys=True))

    (ROOT / "feeds/kibra_market_exchange_plan.json").write_text(
        json.dumps(report_obj, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )

    tasks_md = ""
    for t in ai_tasks:
        tasks_md += f"- `{t['task_id']}` / `{t['type']}` — {t['topic']} → {t['goal']}\n"

    md = f"""# KIBRA Market / Mint / Pool / Exchange AI Plan

Status: **generated**

## What AI Parliament must build

1. Real token mint readiness  
2. Real liquidity pool readiness  
3. Market price engine  
4. Buyers / real volume strategy  
5. Sell-without-crash model  
6. Manual OWNER approval package  
7. Own CYBRA Exchange architecture  

## Hard rule

- Real mint: **false until manual OWNER approval**
- Real liquidity pool: **false until manual OWNER approval**
- Real exchange trading: **false until legal/provider/OWNER approval**
- Fake price: **blocked**
- Wash trading: **blocked**
- Pump/promise profit: **blocked**

## AI tasks

{tasks_md}

## Exchange architecture

- Exchange: **CYBRA Exchange**
- Mode: **sandbox architecture first**
- Markets planned: KIBRA/USDT, KIBRA/UAH, KIBRA/USD, KIBRA/XAU, KIBRA/SOL
- Matching engine: sandbox orderbook
- AMM pool: proposal only
- Price: oracle/liquidity/volume based
- KYC/AML/legal: required for real exchange
- Custody/payments: licensed provider review required

## Proof

Latest KIBRA hash:

`{latest_kibra_hash()}`

Double SHA:

`{report_obj["double_sha"]}`
"""

    (ROOT / "posts/kibra_market_exchange_plan.md").write_text(md, encoding="utf-8")

    with (ROOT / "proofs/kibra_market_exchange_plan.sha256").open("w") as f:
        subprocess.run(
            [
                "sha256sum",
                "parliament/kibra_market/kibra_market_exchange_policy.json",
                "parliament/departments/exchange_department/department.json",
                "data/exchange/cybra_exchange_architecture.json",
                "data/kibra_market/market_readiness_plan.json",
                "feeds/kibra_market_exchange_plan.json",
                "posts/kibra_market_exchange_plan.md"
            ],
            cwd=ROOT,
            stdout=f,
            stderr=subprocess.DEVNULL
        )

    r.lpush(AUDIT, json.dumps({
        "status": "kibra_market_exchange_plan_generated",
        "double_sha": report_obj["double_sha"],
        "time": report_obj["time"]
    }, ensure_ascii=False))

    print("✅ KIBRA market/exchange plan generated")
    print("Report: posts/kibra_market_exchange_plan.md")
    print("Feed: feeds/kibra_market_exchange_plan.json")
    print("Proof: proofs/kibra_market_exchange_plan.sha256")

def submit_tasks():
    tasks = build_ai_tasks()
    for t in tasks:
        task = {
            "topic": t["topic"],
            "type": t["type"],
            "priority": "critical",
            "payload": {
                "task_id": t["task_id"],
                "department": t["department"],
                "goal": t["goal"],
                "real_execution": False,
                "manual_OWNER_approval_required": t["requires_manual_owner_approval"],
                "no_market_manipulation": True,
                "no_fake_price": True,
                "no_automatic_payment": True
            }
        }
        r.lpush("cybra:parliament:queue", json.dumps(task, ensure_ascii=False))
        r.lpush(TASKS, json.dumps(task, ensure_ascii=False))

    print("✅ submitted AI tasks to parliament:", len(tasks))

def main():
    import sys
    cmd = sys.argv[1] if len(sys.argv) > 1 else "report"

    if cmd == "report":
        report()
    elif cmd == "submit":
        submit_tasks()
    elif cmd == "cycle":
        report()
        submit_tasks()
    else:
        raise SystemExit("Usage: report|submit|cycle")

if __name__ == "__main__":
    main()
