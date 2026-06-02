#!/usr/bin/env python3
import json
import time
import hashlib
import subprocess
from pathlib import Path

import redis

ROOT = Path.home() / "CYBRA"
r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

AUDIT = "cybra:finance:infrastructure:audit"
MINT_PROPOSALS = "cybra:token_mint:proposals"
PAYMENT_PROPOSALS = "cybra:payment:settlement:proposals"
GOLD_PROPOSALS = "cybra:treasury:gold:proposals"

def sha(x):
    return hashlib.sha256(x.encode("utf-8")).hexdigest()

def dsha(x):
    return sha(sha(x))

def now_iso():
    return time.strftime("%Y-%m-%dT%H:%M:%S%z")

def load_json(path):
    p = ROOT / path
    if not p.exists():
        return {}
    return json.loads(p.read_text(encoding="utf-8"))

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

def git_cmd(cmd):
    try:
        return subprocess.check_output(cmd, cwd=ROOT, text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return ""

def mask_value(v):
    s = str(v)
    if len(s) <= 8:
        return "***"
    return s[:4] + "***" + s[-4:]

def sanitize(obj):
    if isinstance(obj, dict):
        out = {}
        sensitive_keys = {
            "card", "card_pan", "pan", "cvv", "cvc", "pin",
            "iban", "bank_login", "password", "private_key",
            "seed", "seed_phrase", "secret"
        }
        for k, v in obj.items():
            lk = str(k).lower()
            if lk in sensitive_keys or "card" in lk or "iban" in lk or "secret" in lk or "password" in lk or "seed" in lk:
                out[k] = mask_value(v)
            else:
                out[k] = sanitize(v)
        return out
    if isinstance(obj, list):
        return [sanitize(x) for x in obj]
    return obj

def report():
    r.ping()

    for p in ["posts", "feeds", "proofs", "logs/finance", "data/finance"]:
        (ROOT / p).mkdir(parents=True, exist_ok=True)

    policy = load_json("parliament/finance/infrastructure/finance_infrastructure_policy.json")
    rails = load_json("payments/rails/payment_rails.json")
    mint = load_json("token/kibra/mint/kibra_mint_policy.json")
    gold = load_json("treasury/gold/gold_treasury_policy.json")

    obj = {
        "status": "finance_infrastructure_report_generated",
        "time": time.time(),
        "time_iso": now_iso(),
        "modules": {
            "token_mint": True,
            "multipayment_rails": True,
            "iban": True,
            "card_tokenized_only": True,
            "gold_treasury": True,
            "multi_currency_calculation": True
        },
        "execution_policy": {
            "real_payment_execution": False,
            "automatic_bank_transfer": False,
            "automatic_card_charge": False,
            "automatic_gold_purchase": False,
            "automatic_token_mint": False,
            "automatic_fx_conversion": False,
            "automatic_calculation": True,
            "automatic_proposal_generation": True,
            "manual_owner_approval_required": True
        },
        "supported_currencies": rails.get("supported_currencies_for_calculation", []),
        "redis": {
            "mint_proposals": redis_len(MINT_PROPOSALS),
            "payment_proposals": redis_len(PAYMENT_PROPOSALS),
            "gold_proposals": redis_len(GOLD_PROPOSALS),
            "finance_ledger": redis_len("cybra:finance:ledger"),
            "finance_audit": redis_len("cybra:finance:audit")
        },
        "proof_inputs": {
            "infrastructure_policy": file_sha("parliament/finance/infrastructure/finance_infrastructure_policy.json"),
            "payment_rails": file_sha("payments/rails/payment_rails.json"),
            "mint_policy": file_sha("token/kibra/mint/kibra_mint_policy.json"),
            "gold_policy": file_sha("treasury/gold/gold_treasury_policy.json")
        },
        "git": {
            "branch": git_cmd(["git", "branch", "--show-current"]),
            "commit": git_cmd(["git", "rev-parse", "--short", "HEAD"]),
            "dirty_files": len(git_cmd(["git", "status", "--short"]).splitlines())
        }
    }

    obj["double_sha"] = dsha(json.dumps(obj, ensure_ascii=False, sort_keys=True))

    (ROOT / "feeds/finance_infrastructure_report.json").write_text(
        json.dumps(obj, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )

    md = f"""# CYBRA Finance Infrastructure

Status: **active**  
Mode: proposal ledger + manual execution

## Included

- Token mint / монетний двір токенів: **proposal only**
- Multipayment rails: **proposal only**
- IBAN: **masked only, manual provider execution**
- Cards: **PSP token only, no PAN/CVV/PIN storage**
- Gold treasury / XAU accounting: **proposal only**
- Multi-currency calculations: **automatic**
- Real transfers: **manual OWNER approval only**

## Hard limits

- Real payment execution: **false**
- Automatic bank transfer: **false**
- Automatic card charge: **false**
- Automatic gold purchase: **false**
- Automatic token mint: **false**
- Automatic FX conversion: **false**

## Supported calculation currencies

{chr(10).join("- " + x for x in obj["supported_currencies"])}

## Redis

- Mint proposals: {obj["redis"]["mint_proposals"]}
- Payment proposals: {obj["redis"]["payment_proposals"]}
- Gold proposals: {obj["redis"]["gold_proposals"]}
- Finance ledger: {obj["redis"]["finance_ledger"]}
- Finance audit: {obj["redis"]["finance_audit"]}

## Proof

Double SHA:

`{obj["double_sha"]}`

## Files

- `parliament/finance/infrastructure/finance_infrastructure_policy.json`
- `payments/rails/payment_rails.json`
- `token/kibra/mint/kibra_mint_policy.json`
- `treasury/gold/gold_treasury_policy.json`
- `feeds/finance_infrastructure_report.json`
- `posts/finance_infrastructure_report.md`
- `proofs/finance_infrastructure.sha256`
"""

    (ROOT / "posts/finance_infrastructure_report.md").write_text(md, encoding="utf-8")

    with (ROOT / "proofs/finance_infrastructure.sha256").open("w") as f:
        subprocess.run(
            [
                "sha256sum",
                "parliament/finance/infrastructure/finance_infrastructure_policy.json",
                "payments/rails/payment_rails.json",
                "token/kibra/mint/kibra_mint_policy.json",
                "treasury/gold/gold_treasury_policy.json",
                "feeds/finance_infrastructure_report.json",
                "posts/finance_infrastructure_report.md"
            ],
            cwd=ROOT,
            stdout=f,
            stderr=subprocess.DEVNULL
        )

    r.lpush(AUDIT, json.dumps({
        "status": "finance_infrastructure_report_generated",
        "double_sha": obj["double_sha"],
        "time": obj["time"]
    }, ensure_ascii=False))

    print("✅ CYBRA finance infrastructure report generated")
    print("Double SHA:", obj["double_sha"])
    print("Report: posts/finance_infrastructure_report.md")
    print("Feed: feeds/finance_infrastructure_report.json")
    print("Proof: proofs/finance_infrastructure.sha256")

def mint_proposal(amount="49000000000000000"):
    obj = {
        "status": "token_mint_proposal_only",
        "token": "KIBRA",
        "amount_raw": str(amount),
        "automatic_mint": False,
        "manual_owner_approval_required": True,
        "manual_wallet_signature_required": True,
        "time": time.time()
    }
    obj["double_sha"] = dsha(json.dumps(obj, ensure_ascii=False, sort_keys=True))
    r.lpush(MINT_PROPOSALS, json.dumps(obj, ensure_ascii=False))
    r.lpush("cybra:finance:ledger", json.dumps(obj, ensure_ascii=False))
    print(json.dumps(obj, ensure_ascii=False, indent=2))

def settlement_proposal(raw):
    data = sanitize(json.loads(raw))

    obj = {
        "status": "settlement_proposal_only",
        "input_sanitized": data,
        "automatic_calculation_allowed": True,
        "real_transfer_execution": False,
        "automatic_bank_transfer": False,
        "automatic_card_charge": False,
        "automatic_gold_conversion": False,
        "manual_owner_approval_required": True,
        "licensed_provider_required": True,
        "rate_source": "manual_oracle_required",
        "time": time.time()
    }

    obj["double_sha"] = dsha(json.dumps(obj, ensure_ascii=False, sort_keys=True))
    r.lpush(PAYMENT_PROPOSALS, json.dumps(obj, ensure_ascii=False))
    r.lpush("cybra:finance:ledger", json.dumps(obj, ensure_ascii=False))

    print("✅ settlement proposal created")
    print(json.dumps(obj, ensure_ascii=False, indent=2))

def gold_proposal(amount_xau="0"):
    obj = {
        "status": "gold_treasury_proposal_only",
        "unit": "XAU",
        "amount_xau": str(amount_xau),
        "automatic_gold_purchase": False,
        "gold_backing_claim": False,
        "reserve_proof_required": True,
        "manual_owner_approval_required": True,
        "licensed_custodian_or_provider_required": True,
        "time": time.time()
    }
    obj["double_sha"] = dsha(json.dumps(obj, ensure_ascii=False, sort_keys=True))
    r.lpush(GOLD_PROPOSALS, json.dumps(obj, ensure_ascii=False))
    r.lpush("cybra:finance:ledger", json.dumps(obj, ensure_ascii=False))
    print(json.dumps(obj, ensure_ascii=False, indent=2))

def main():
    import sys
    cmd = sys.argv[1] if len(sys.argv) > 1 else "report"

    if cmd == "report":
        report()
    elif cmd == "mint-proposal":
        amount = sys.argv[2] if len(sys.argv) > 2 else "49000000000000000"
        mint_proposal(amount)
    elif cmd == "settlement-proposal":
        if len(sys.argv) < 3:
            raise SystemExit("Usage: settlement-proposal '<json>'")
        settlement_proposal(sys.argv[2])
    elif cmd == "gold-proposal":
        amount = sys.argv[2] if len(sys.argv) > 2 else "0"
        gold_proposal(amount)
    else:
        raise SystemExit("Usage: report|mint-proposal [amount]|settlement-proposal '<json>'|gold-proposal [amount_xau]")

if __name__ == "__main__":
    main()
