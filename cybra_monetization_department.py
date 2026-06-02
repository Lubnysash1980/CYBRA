#!/usr/bin/env python3
import json
import time
import hashlib
import subprocess
from pathlib import Path
from collections import Counter

import redis

ROOT = Path.home() / "CYBRA"
r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

AUDIT_KEY = "cybra:monetization:audit"
PROPOSALS_KEY = "cybra:monetization:proposals"
EVOLUTION_KEY = "cybra:monetization:evolution_cycles"

def sha(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()

def dsha(text: str) -> str:
    return sha(sha(text))

def now_iso():
    return time.strftime("%Y-%m-%dT%H:%M:%S%z")

def file_sha(path: str):
    p = ROOT / path
    if not p.exists():
        return None
    h = hashlib.sha256()
    with p.open("rb") as f:
        for c in iter(lambda: f.read(1024 * 1024), b""):
            h.update(c)
    return h.hexdigest()

def load_json(path: str):
    p = ROOT / path
    if not p.exists():
        return {}
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception:
        return {}

def git_cmd(cmd):
    try:
        return subprocess.check_output(cmd, cwd=ROOT, text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return ""

def redis_len(key):
    try:
        return r.llen(key)
    except Exception:
        return 0

def build_utility_catalog():
    return [
        {
            "service_id": "KIBRA-AI-TASK",
            "name": "AI task execution credit",
            "spend_model": "KIBRA can be spent as internal credit for AI tasks",
            "real_payment": False,
            "requires_owner_approval": False,
            "price_mode": "internal_reference_unit"
        },
        {
            "service_id": "KIBRA-PROOF-CERT",
            "name": "Proof-chain certificate",
            "spend_model": "KIBRA can be spent to generate/verify proof report",
            "real_payment": False,
            "requires_owner_approval": False,
            "price_mode": "proof_service_unit"
        },
        {
            "service_id": "KIBRA-ANCHOR-PACKAGE",
            "name": "External blockchain anchor package",
            "spend_model": "KIBRA can reserve a manual anchor package",
            "real_payment": False,
            "requires_owner_approval": True,
            "price_mode": "manual_anchor_unit"
        },
        {
            "service_id": "KIBRA-REVISION",
            "name": "Revision / analytics report",
            "spend_model": "KIBRA can be used to request revision and analytics reports",
            "real_payment": False,
            "requires_owner_approval": False,
            "price_mode": "report_unit"
        },
        {
            "service_id": "KIBRA-DEV-SUPPORT",
            "name": "Developer support credit",
            "spend_model": "KIBRA can represent internal developer support priority",
            "real_payment": False,
            "requires_owner_approval": True,
            "price_mode": "proposal_only"
        }
    ]

def build_price_model():
    return {
        "status": "proposal_only",
        "price_is_guaranteed": False,
        "external_market_price": None,
        "internal_reference": {
            "unit_name": "KIBRA Utility Unit",
            "symbol": "KUU",
            "meaning": "Internal accounting unit for CYBRA services; not a guaranteed market price.",
            "recommended_use": [
                "AI task fee accounting",
                "proof certificate fee accounting",
                "manual anchor package accounting",
                "pool reward accounting"
            ]
        },
        "value_drivers": [
            "real utility",
            "service catalog",
            "verified proof-chain",
            "external anchor trust",
            "liquidity proposal after owner approval",
            "community demand",
            "transparent treasury ledger"
        ],
        "blocked": [
            "guaranteed profit",
            "fake price",
            "pump promise",
            "automatic market manipulation",
            "unapproved external trading"
        ]
    }

def build_liquidity_plan():
    return {
        "status": "manual_proposal_only",
        "owner_allocation_percent": 60,
        "pool_allocation_percent": 40,
        "pool_creation": {
            "automatic": False,
            "manual_owner_approval_required": True,
            "legal_tax_review_required": True,
            "wallet_signature_required": True
        },
        "stages": [
            "internal utility proof",
            "service catalog activation",
            "treasury ledger proposal",
            "manual liquidity pool design",
            "risk review",
            "owner approval",
            "manual transaction only",
            "external anchor proof"
        ]
    }

def build_evolution_tasks():
    return [
        {
            "task_id": "MON-EVO-001",
            "department": "evolution_guard",
            "goal": "Перевірити, що монетизація розвиває utility і не створює деградацію/маніпуляцію.",
            "output": "evolution decision"
        },
        {
            "task_id": "MON-FIN-001",
            "department": "finance_department",
            "goal": "Перевірити liquidity proposal, 60/40 allocation, treasury і відсутність automatic payments.",
            "output": "finance risk report"
        },
        {
            "task_id": "MON-REV-001",
            "department": "revision_organ",
            "goal": "Перевірити, чи є proof, policy, no private keys, no automatic trading.",
            "output": "revision report"
        },
        {
            "task_id": "MON-ANA-001",
            "department": "analytics_committee",
            "goal": "Оцінити, які utility-сервіси можуть створити попит на KIBRA.",
            "output": "analytics report"
        },
        {
            "task_id": "MON-HASH-001",
            "department": "hash_module",
            "goal": "Записати monetization model у double-SHA proof і anchor package.",
            "output": "hash proof"
        }
    ]

def build_spend_task(service_id="KIBRA-AI-TASK", amount="0"):
    return {
        "status": "spend_proposal_only",
        "token": "KIBRA",
        "service_id": service_id,
        "amount": amount,
        "real_payment": False,
        "external_transfer": False,
        "manual_owner_approval_required": False,
        "note": "Internal spendability proof only; not real on-chain spending.",
        "time": time.time()
    }

def report():
    r.ping()

    for p in ["posts", "feeds", "proofs", "logs/monetization", "data/monetization", "token/kibra/monetization"]:
        (ROOT / p).mkdir(parents=True, exist_ok=True)

    policy = load_json("parliament/monetization/kibra_monetization_policy.json")
    kibra_status = load_json("feeds/kibra_token_chain_status.json")
    finance_report = load_json("feeds/finance_department_report.json")
    parliament_review = load_json("feeds/parliament_kibra_response_review.json")
    external_anchor = load_json("feeds/external_anchor_package.json")

    utility_catalog = build_utility_catalog()
    price_model = build_price_model()
    liquidity_plan = build_liquidity_plan()
    evolution_tasks = build_evolution_tasks()

    latest_hash = None
    hfile = ROOT / "blockchain/kibra_chain/latest.block.hash"
    if hfile.exists():
        latest_hash = hfile.read_text().strip()

    monetization_block = {
        "module": "CYBRA Monetization Department",
        "status": "generated",
        "time": time.time(),
        "time_iso": now_iso(),
        "token": policy.get("token", {}),
        "latest_kibra_hash": latest_hash,
        "utility_catalog": utility_catalog,
        "price_model": price_model,
        "liquidity_plan": liquidity_plan,
        "evolution_tasks": evolution_tasks,
        "dependencies": {
            "kibra_chain_status": bool(kibra_status),
            "finance_report": bool(finance_report),
            "parliament_review": bool(parliament_review),
            "external_anchor_package": bool(external_anchor)
        },
        "proof_inputs": {
            "monetization_policy": file_sha("parliament/monetization/kibra_monetization_policy.json"),
            "department": file_sha("parliament/departments/monetization_department/department.json"),
            "kibra_chain_proof": file_sha("proofs/kibra_token_chain.sha256"),
            "external_anchor_package": file_sha("proofs/external_anchor_package.sha256"),
            "finance_department": file_sha("proofs/finance_department.sha256")
        },
        "redis": {
            "monetization_audit": redis_len(AUDIT_KEY),
            "monetization_proposals": redis_len(PROPOSALS_KEY),
            "finance_ledger": redis_len("cybra:finance:ledger"),
            "anchor_manual_ready": redis_len("cybra:blockchain:anchor:manual_ready"),
            "parliament_results": redis_len("cybra:parliament:results")
        },
        "git": {
            "branch": git_cmd(["git", "branch", "--show-current"]),
            "commit": git_cmd(["git", "rev-parse", "--short", "HEAD"]),
            "dirty_files": len(git_cmd(["git", "status", "--short"]).splitlines())
        }
    }

    monetization_block["double_sha"] = dsha(json.dumps(monetization_block, ensure_ascii=False, sort_keys=True))

    (ROOT / "feeds/monetization_department_report.json").write_text(
        json.dumps(monetization_block, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )

    (ROOT / "token/kibra/monetization/utility_catalog.json").write_text(
        json.dumps(utility_catalog, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )

    (ROOT / "token/kibra/monetization/price_model_proposal.json").write_text(
        json.dumps(price_model, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )

    (ROOT / "token/kibra/monetization/liquidity_plan_proposal.json").write_text(
        json.dumps(liquidity_plan, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )

    r.lpush(AUDIT_KEY, json.dumps({
        "status": "monetization_report_generated",
        "double_sha": monetization_block["double_sha"],
        "latest_kibra_hash": latest_hash,
        "time": monetization_block["time"]
    }, ensure_ascii=False))

    r.lpush(PROPOSALS_KEY, json.dumps({
        "status": "monetization_proposal",
        "token": "KIBRA",
        "model": "utility_first_proposal_only",
        "price_guaranteed": False,
        "liquidity_pool_automatic": False,
        "manual_owner_approval_required": True,
        "double_sha": monetization_block["double_sha"],
        "time": monetization_block["time"]
    }, ensure_ascii=False))

    r.lpush(EVOLUTION_KEY, json.dumps({
        "status": "evolution_cycle_ready",
        "tasks": evolution_tasks,
        "time": monetization_block["time"],
        "double_sha": monetization_block["double_sha"]
    }, ensure_ascii=False))

    util_md = ""
    for x in utility_catalog:
        util_md += f"- `{x['service_id']}` — {x['name']} / {x['spend_model']}\n"

    evo_md = ""
    for x in evolution_tasks:
        evo_md += f"- `{x['task_id']}` / {x['department']} — {x['goal']}\n"

    md = f"""# CYBRA Monetization Department

Status: **active**  
Mode: **proposal + proof + evolution only**

## Token

- Name: **Кібра**
- Symbol: **KIBRA**
- Total supply: **49 000 000 000 000 000**
- OWNER allocation: **60%**
- Pool allocation: **40%**

## Main rule

KIBRA must first become useful before it can have a real market price.

No guaranteed price.  
No automatic payments.  
No automatic trading.  
No market manipulation.  
Real pool/liquidity requires manual OWNER approval.

## Spendability model

{util_md}

## Price model

- External market price: **not set**
- Internal utility unit: **proposal only**
- Price guarantee: **false**
- Value drivers:
  - utility;
  - proof-chain;
  - external anchor package;
  - service catalog;
  - treasury transparency;
  - real demand;
  - manual liquidity proposal.

## Liquidity plan

- 60% OWNER allocation
- 40% pool allocation
- Real pool creation: **manual only**
- Legal/tax review: **required**
- Wallet signature: **manual only**

## Evolution tasks

{evo_md}

## Proof

Latest KIBRA hash:

`{latest_hash}`

Monetization Double SHA:

`{monetization_block["double_sha"]}`

## Files

- `parliament/departments/monetization_department/department.json`
- `parliament/monetization/kibra_monetization_policy.json`
- `token/kibra/monetization/utility_catalog.json`
- `token/kibra/monetization/price_model_proposal.json`
- `token/kibra/monetization/liquidity_plan_proposal.json`
- `feeds/monetization_department_report.json`
- `posts/monetization_department_report.md`
- `proofs/monetization_department.sha256`
"""

    (ROOT / "posts/monetization_department_report.md").write_text(md, encoding="utf-8")

    with (ROOT / "proofs/monetization_department.sha256").open("w") as f:
        subprocess.run(
            [
                "sha256sum",
                "parliament/departments/monetization_department/department.json",
                "parliament/monetization/kibra_monetization_policy.json",
                "token/kibra/monetization/utility_catalog.json",
                "token/kibra/monetization/price_model_proposal.json",
                "token/kibra/monetization/liquidity_plan_proposal.json",
                "feeds/monetization_department_report.json",
                "posts/monetization_department_report.md"
            ],
            cwd=ROOT,
            stdout=f,
            stderr=subprocess.DEVNULL
        )

    print("✅ CYBRA Monetization Department report generated")
    print("Double SHA:", monetization_block["double_sha"])
    print("Report: posts/monetization_department_report.md")
    print("Feed: feeds/monetization_department_report.json")
    print("Proof: proofs/monetization_department.sha256")

def spend(service_id, amount):
    proposal = build_spend_task(service_id, amount)
    proposal["double_sha"] = dsha(json.dumps(proposal, ensure_ascii=False, sort_keys=True))
    r.lpush("cybra:monetization:spend_proposals", json.dumps(proposal, ensure_ascii=False))
    print("✅ spend proposal created")
    print(json.dumps(proposal, ensure_ascii=False, indent=2))

def main():
    import sys
    cmd = sys.argv[1] if len(sys.argv) > 1 else "report"

    if cmd == "report":
        report()
    elif cmd == "spend":
        service_id = sys.argv[2] if len(sys.argv) > 2 else "KIBRA-AI-TASK"
        amount = sys.argv[3] if len(sys.argv) > 3 else "0"
        spend(service_id, amount)
    else:
        raise SystemExit("Usage: report | spend <service_id> <amount>")

if __name__ == "__main__":
    main()
