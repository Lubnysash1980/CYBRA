#!/data/data/com.termux/files/usr/bin/bash
set -e

cd "$HOME/CYBRA"

echo "=== INSTALL CYBRA FINANCE: TOKEN MINT + MULTIPAYMENT + GOLD TREASURY ==="

mkdir -p \
  parliament/finance/infrastructure \
  parliament/departments/finance_department \
  token/kibra/mint \
  treasury/gold \
  payments/rails \
  posts feeds proofs logs/finance data/finance

touch .gitignore
for item in \
  "private_vault/" \
  "dump.rdb" \
  "__pycache__/" \
  "runtime/" \
  "token/runtime/rpc.env" \
  ".env" \
  "*.key" \
  "*.pem" \
  "*seed*" \
  "*secret*" \
  "*card*" \
  "*iban_private*" \
  "*bank_login*" \
  "data/finance/private/"
do
  grep -qxF "$item" .gitignore || echo "$item" >> .gitignore
done

redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes
sleep 1

cat > parliament/finance/infrastructure/finance_infrastructure_policy.json <<'JSON'
{
  "name": "CYBRA Finance Infrastructure Policy",
  "status": "active",
  "mode": "proposal_ledger_manual_execution",
  "modules": {
    "token_mint": true,
    "multipayment_rails": true,
    "iban_rails": true,
    "card_rails_tokenized_only": true,
    "gold_treasury_accounting": true,
    "multi_currency_calculation": true
  },
  "hard_limits": {
    "real_payment_execution": false,
    "automatic_bank_transfer": false,
    "automatic_card_charge": false,
    "automatic_gold_purchase": false,
    "automatic_token_mint": false,
    "automatic_fx_conversion": false,
    "manual_owner_approval_required": true,
    "licensed_provider_required_for_real_payments": true,
    "legal_tax_aml_review_required": true,
    "no_card_pan_storage": true,
    "no_cvv_storage": true,
    "no_pin_storage": true,
    "no_seed_phrase": true,
    "no_private_keys": true
  },
  "allowed": {
    "automatic_calculation": true,
    "automatic_proposal_generation": true,
    "risk_scoring": true,
    "ledger_draft": true,
    "proof_generation": true,
    "manual_execution_package": true
  }
}
JSON

cat > parliament/departments/finance_department/finance_infrastructure_extension.json <<'JSON'
{
  "extension": "token_mint_multipayment_gold",
  "status": "active",
  "description": "Розширення фінансового департаменту: монетний двір токенів, мультиплатіжна система, IBAN/card-token rails, золота казна, мультивалютні розрахунки.",
  "principle": "Calculate automatically, propose automatically, execute only manually after OWNER approval and licensed provider/legal review.",
  "owner_final_approval": true
}
JSON

cat > payments/rails/payment_rails.json <<'JSON'
{
  "name": "CYBRA Multipayment Rails",
  "status": "proposal_only",
  "rails": [
    {
      "rail": "IBAN",
      "type": "bank_transfer",
      "real_execution": false,
      "storage": "masked_iban_only",
      "requires": ["licensed_provider", "owner_approval", "invoice", "kyc_aml"]
    },
    {
      "rail": "CARD",
      "type": "card_payment",
      "real_execution": false,
      "storage": "psp_token_only_no_pan_no_cvv",
      "requires": ["PCI_DSS_scope_review", "payment_service_provider", "owner_approval"]
    },
    {
      "rail": "CRYPTO",
      "type": "manual_wallet_transaction",
      "real_execution": false,
      "storage": "public_address_only",
      "requires": ["manual_wallet_signature", "owner_approval", "chain_proof"]
    },
    {
      "rail": "GOLD_XAU",
      "type": "gold_accounting_unit",
      "real_execution": false,
      "storage": "reserve_proof_required",
      "requires": ["audited_reserve", "manual_purchase", "legal_review"]
    },
    {
      "rail": "KIBRA",
      "type": "internal_token_ledger",
      "real_execution": false,
      "storage": "proof_chain_ledger",
      "requires": ["token_mint_proposal", "hash_proof", "owner_approval_for_real_mint"]
    }
  ],
  "supported_currencies_for_calculation": [
    "UAH",
    "USD",
    "EUR",
    "PLN",
    "GBP",
    "USDT",
    "BTC",
    "SOL",
    "KIBRA",
    "XAU"
  ]
}
JSON

cat > token/kibra/mint/kibra_mint_policy.json <<'JSON'
{
  "name": "KIBRA Token Mint Policy",
  "status": "proposal_only",
  "token": {
    "name": "Кібра",
    "symbol": "KIBRA",
    "total_supply_raw": "49000000000000000",
    "owner_percent": 60,
    "pool_percent": 40
  },
  "mint_rules": {
    "automatic_mint": false,
    "manual_wallet_signature_required": true,
    "mint_authority_protection_required": true,
    "freeze_authority_policy_required": true,
    "metadata_proof_required": true,
    "pool_allocation_proposal_required": true,
    "owner_final_approval_required": true
  }
}
JSON

cat > treasury/gold/gold_treasury_policy.json <<'JSON'
{
  "name": "CYBRA Gold Treasury Policy",
  "status": "proposal_only",
  "unit": "XAU",
  "purpose": "Вести облік пропозицій конвертації вартості у золото як treasury accounting unit.",
  "rules": {
    "automatic_gold_purchase": false,
    "automatic_conversion": false,
    "gold_backing_claim_allowed_without_audit": false,
    "reserve_proof_required": true,
    "manual_owner_approval_required": true,
    "licensed_custodian_or_provider_required": true,
    "legal_tax_review_required": true
  }
}
JSON

cat > cybra_finance_infrastructure.py <<'PY'
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
PY

chmod +x cybra_finance_infrastructure.py

cat > finance_infrastructure_handler.sh <<'EOF2'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

python3 cybra_finance_infrastructure.py report

bash cybra_finance.sh report >/dev/null 2>&1 || true
bash cybra_monetization.sh report >/dev/null 2>&1 || true
bash cybra_hash_test.sh run >/dev/null 2>&1 || true
bash cybra_institution.sh check >/dev/null 2>&1 || true
EOF2

chmod +x finance_infrastructure_handler.sh

cat > cybra_finance_infra.sh <<'EOF2'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

CMD="${1:-status}"
shift || true

case "$CMD" in
  run|report)
    python3 cybra_finance_infrastructure.py report
    cat posts/finance_infrastructure_report.md
    ;;
  task)
    cybra parliament '{"topic":"CYBRA Finance Infrastructure: token mint multipayment gold treasury","type":"finance_infrastructure_task","priority":"critical","payload":{"mode":"token_mint_multipayment_gold","automatic_calculation":true,"real_payment_execution":false,"automatic_token_mint":false,"automatic_gold_purchase":false,"manual_owner_approval_required":true}}'
    ;;
  mint-proposal)
    python3 cybra_finance_infrastructure.py mint-proposal "${1:-49000000000000000}"
    ;;
  settlement-proposal)
    python3 cybra_finance_infrastructure.py settlement-proposal "$1"
    ;;
  gold-proposal)
    python3 cybra_finance_infrastructure.py gold-proposal "${1:-0}"
    ;;
  status)
    redis-cli ping
    echo "FIN_INFRA_AUDIT: $(redis-cli LLEN cybra:finance:infrastructure:audit)"
    echo "MINT_PROPOSALS: $(redis-cli LLEN cybra:token_mint:proposals)"
    echo "PAYMENT_PROPOSALS: $(redis-cli LLEN cybra:payment:settlement:proposals)"
    echo "GOLD_PROPOSALS: $(redis-cli LLEN cybra:treasury:gold:proposals)"
    echo "FINANCE_LEDGER: $(redis-cli LLEN cybra:finance:ledger)"
    echo "PARLIAMENT_QUEUE: $(redis-cli LLEN cybra:parliament:queue)"
    echo "PARLIAMENT_RESULTS: $(redis-cli LLEN cybra:parliament:results)"
    test -f posts/finance_infrastructure_report.md && echo "REPORT: exists" || echo "REPORT: missing"
    ;;
  rails)
    cat payments/rails/payment_rails.json
    ;;
  policy)
    cat parliament/finance/infrastructure/finance_infrastructure_policy.json
    ;;
  mint-policy)
    cat token/kibra/mint/kibra_mint_policy.json
    ;;
  gold-policy)
    cat treasury/gold/gold_treasury_policy.json
    ;;
  proposals)
    echo "=== MINT ==="
    redis-cli LRANGE cybra:token_mint:proposals 0 10
    echo
    echo "=== PAYMENT ==="
    redis-cli LRANGE cybra:payment:settlement:proposals 0 10
    echo
    echo "=== GOLD ==="
    redis-cli LRANGE cybra:treasury:gold:proposals 0 10
    ;;
  proof)
    cat proofs/finance_infrastructure.sha256
    ;;
  *)
    echo "Usage: bash cybra_finance_infra.sh report|task|mint-proposal|settlement-proposal|gold-proposal|status|rails|policy|mint-policy|gold-policy|proposals|proof"
    ;;
esac
EOF2

chmod +x cybra_finance_infra.sh

redis-cli HSET cybra:executor:mapping finance_infrastructure_task finance_infrastructure_handler.sh >/dev/null

python3 - <<'PY'
from pathlib import Path

p = Path("parliament_executor_v6.py")
s = p.read_text()

if 'r.hget("cybra:executor:mapping", task_type)' not in s:
    old = "script_name = SCRIPT_MAP.get(task_type)"
    new = 'script_name = r.hget("cybra:executor:mapping", task_type) or SCRIPT_MAP.get(task_type)'
    if old in s:
        s = s.replace(old, new, 1)

if '"finance_infrastructure_task"' not in s:
    i = s.find("SCRIPT_MAP")
    j = s.find("{", i)
    if i >= 0 and j >= 0:
        s = s[:j+1] + '\n    "finance_infrastructure_task": "finance_infrastructure_handler.sh",' + s[j+1:]

p.write_text(s)
print("✅ finance_infrastructure_task mapping ready")
PY

rm -rf __pycache__
python3 -m py_compile parliament_executor_v6.py
python3 -m py_compile cybra_finance_infrastructure.py
rm -rf __pycache__

echo
echo "=== 1. RUN REPORT ==="
bash cybra_finance_infra.sh report

echo
echo "=== 2. CREATE TEST PROPOSALS ==="
bash cybra_finance_infra.sh mint-proposal 49000000000000000

bash cybra_finance_infra.sh settlement-proposal '{
  "from": "KIBRA",
  "to": "XAU",
  "amount": "1000",
  "rail": "GOLD_XAU",
  "note": "test internal calculation proposal only"
}'

bash cybra_finance_infra.sh gold-proposal 0

echo
echo "=== 3. RUN THROUGH PARLIAMENT ==="
bash cybra_finance_infra.sh task

for i in $(seq 1 30); do
  echo "round=$i queue=$(redis-cli LLEN cybra:parliament:queue)"
  python3 parliament_executor_v6.py || true
  sleep 1
  [ "$(redis-cli LLEN cybra:parliament:queue)" = "0" ] && break
done

echo
echo "=== 4. STATUS ==="
bash cybra_finance_infra.sh status
cybra status || true

echo
echo "=== 5. PROOF CHECK ==="
sha256sum -c proofs/finance_infrastructure.sha256

echo
echo "✅ CYBRA FINANCE INFRASTRUCTURE INSTALLED"
