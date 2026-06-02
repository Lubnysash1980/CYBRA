#!/data/data/com.termux/files/usr/bin/bash
set -e

cd "$HOME/CYBRA"

echo "=== OWNER ORCHESTRATOR + FINANCE RISK + ANCHOR + CAR PREFLIGHT ==="

mkdir -p \
  parliament/orchestrator \
  parliament/finance/risk_resolution \
  parliament/blockchain_anchor \
  parliament/car_purchase \
  posts feeds proofs logs/orchestrator logs/finance logs/anchor logs/car

redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes
sleep 1

cat > parliament/orchestrator/main_owner_orchestrator_policy.json <<'JSON'
{
  "name": "CYBRA Main Owner Orchestrator",
  "status": "active",
  "owner_role": "MAIN_ORCHESTRATOR",
  "owner_identity_mode": "local_owner_declared_not_public_git_secret",
  "powers": [
    "approve_or_reject_financial_risk",
    "approve_manual_external_blockchain_anchor",
    "approve_or_reject_car_purchase_stage",
    "start_revision",
    "start_finance_review",
    "start_analytics_review",
    "start_hash_proof",
    "block_automatic_payment"
  ],
  "limits": [
    "no_automatic_payments",
    "no_private_keys_in_git",
    "no_seed_phrase",
    "no_bank_card_data",
    "no_unverified_supplier_payment",
    "manual_signature_required_for_real_purchase",
    "manual_wallet_signature_required_for_external_anchor"
  ],
  "final_rule": "Owner is main orchestrator. System may prepare proofs, risks, ledgers and recommendations, but real payment, vehicle purchase or external blockchain transaction requires manual OWNER approval."
}
JSON

cat > parliament/finance/risk_resolution/finance_risk_resolution_policy.json <<'JSON'
{
  "name": "CYBRA Finance Risk Resolution",
  "status": "active",
  "mode": "risk_controlled",
  "risk_decision": "conditional_hold_until_documents",
  "rules": {
    "payment_execution_allowed": false,
    "advance_payment_allowed_only_after_documents": true,
    "owner_manual_approval_required": true,
    "contract_required": true,
    "invoice_required": true,
    "supplier_verification_required": true,
    "vin_or_asset_identifier_required_for_car": true,
    "ownership_transfer_check_required": true,
    "debt_lien_arrest_check_required": true,
    "tax_and_registration_costs_required": true
  }
}
JSON

cat > parliament/blockchain_anchor/external_anchor_resolution_policy.json <<'JSON'
{
  "name": "CYBRA External Blockchain Anchor Resolution",
  "status": "manual_anchor_ready",
  "mode": "prepare_anchor_package_only",
  "rules": {
    "automatic_onchain_tx": false,
    "manual_wallet_signature_required": true,
    "anchor_hash_required": true,
    "proof_package_required": true,
    "external_tx_hash_empty_until_manual_anchor": true
  },
  "anchor_targets": [
    "KIBRA local proof-chain latest block hash",
    "KIBRA token policy hash",
    "difficulty stream hash",
    "parliament review hash",
    "finance risk decision hash"
  ]
}
JSON

cat > parliament/car_purchase/car_purchase_preflight_policy.json <<'JSON'
{
  "name": "CYBRA Car Purchase Preflight",
  "status": "active",
  "mode": "tomorrow_purchase_readiness",
  "rules": {
    "no_payment_before_document_check": true,
    "vin_check_required": true,
    "seller_authority_check_required": true,
    "ownership_transfer_check_required": true,
    "lien_arrest_debt_check_required": true,
    "invoice_contract_required": true,
    "registration_costs_required": true,
    "delivery_act_required": true,
    "manual_owner_signature_required": true
  },
  "checklist": [
    "VIN / номер кузова",
    "техпаспорт або документ походження",
    "договір купівлі-продажу / рахунок",
    "акт прийому-передачі",
    "перевірка арештів/застав/обтяжень",
    "перевірка продавця",
    "сума авто",
    "податки і реєстраційні платежі",
    "умова: без повної передоплати без гарантій",
    "фінальне ручне підтвердження OWNER"
  ]
}
JSON

cat > cybra_owner_orchestrator_finance_anchor_car.py <<'PY'
#!/usr/bin/env python3
import json, time, hashlib, subprocess
from pathlib import Path
import redis

ROOT = Path.home() / "CYBRA"
r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

def sha(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()

def dsha(text):
    return sha(sha(text))

def file_sha(path):
    p = ROOT / path
    if not p.exists():
        return None
    h = hashlib.sha256()
    with p.open("rb") as f:
        for c in iter(lambda: f.read(1024 * 1024), b""):
            h.update(c)
    return h.hexdigest()

def now():
    return time.strftime("%Y-%m-%dT%H:%M:%S%z")

def redis_len(key):
    try:
        return r.llen(key)
    except Exception:
        return 0

def latest_anchor_items():
    out = []
    for raw in r.lrange("cybra:blockchain:anchor:queue", 0, 20):
        try:
            out.append(json.loads(raw))
        except Exception:
            out.append({"raw": raw})
    return out

def build_report():
    r.ping()

    latest_kibra_hash = None
    hfile = ROOT / "blockchain/kibra_chain/latest.block.hash"
    if hfile.exists():
        latest_kibra_hash = hfile.read_text().strip()

    proof_inputs = {
        "owner_orchestrator_policy": file_sha("parliament/orchestrator/main_owner_orchestrator_policy.json"),
        "finance_risk_policy": file_sha("parliament/finance/risk_resolution/finance_risk_resolution_policy.json"),
        "external_anchor_policy": file_sha("parliament/blockchain_anchor/external_anchor_resolution_policy.json"),
        "car_purchase_policy": file_sha("parliament/car_purchase/car_purchase_preflight_policy.json"),
        "kibra_latest_block_hash": latest_kibra_hash,
        "kibra_token_chain_proof": file_sha("proofs/kibra_token_chain.sha256"),
        "parliament_kibra_review_proof": file_sha("proofs/parliament_kibra_response_review.sha256")
    }

    finance_decision = {
        "status": "conditional_hold_until_documents",
        "payment_execution_allowed": False,
        "reason": "Завтрашня купівля авто можлива тільки після перевірки документів, продавця, VIN, обтяжень, договору і ручного підтвердження OWNER.",
        "allowed_next_stage": "document_collection_and_manual_review",
        "blocked": [
            "automatic payment",
            "full prepayment without guarantees",
            "payment without VIN/documents",
            "payment without seller authority check",
            "payment without ownership transfer terms"
        ]
    }

    external_anchor_decision = {
        "status": "manual_anchor_package_ready",
        "automatic_onchain_tx": False,
        "manual_wallet_signature_required": True,
        "anchor_queue_count": redis_len("cybra:blockchain:anchor:queue"),
        "latest_kibra_hash": latest_kibra_hash,
        "next_action": "Після ручного підтвердження OWNER взяти anchor_root_hash і записати у зовнішній блокчейн окремою транзакцією."
    }

    car_preflight = {
        "status": "ready_for_manual_document_check",
        "tomorrow_purchase_mode": True,
        "required_before_payment": [
            "VIN або номер кузова",
            "ціна і валюта",
            "продавець / дилер / компанія",
            "договір або рахунок",
            "акт прийому-передачі",
            "умови оплати",
            "перевірка обтяжень/арештів/застав",
            "перевірка права продавця продавати авто",
            "реєстраційні платежі",
            "фінальне ручне підтвердження OWNER"
        ]
    }

    anchor_root_base = {
        "proof_inputs": proof_inputs,
        "finance_decision": finance_decision,
        "external_anchor_decision": external_anchor_decision,
        "car_preflight": car_preflight,
        "time": time.time(),
        "time_iso": now()
    }

    anchor_root_hash = dsha(json.dumps(anchor_root_base, ensure_ascii=False, sort_keys=True))

    report = {
        "status": "owner_orchestrator_finance_anchor_car_ready",
        "time": time.time(),
        "time_iso": now(),
        "owner_role": "MAIN_ORCHESTRATOR",
        "finance_decision": finance_decision,
        "external_anchor_decision": external_anchor_decision,
        "car_preflight": car_preflight,
        "proof_inputs": proof_inputs,
        "anchor_root_hash": anchor_root_hash,
        "redis": {
            "parliament_queue": redis_len("cybra:parliament:queue"),
            "parliament_results": redis_len("cybra:parliament:results"),
            "finance_ledger": redis_len("cybra:finance:ledger"),
            "finance_audit": redis_len("cybra:finance:audit"),
            "anchor_queue": redis_len("cybra:blockchain:anchor:queue"),
            "kibra_audit": redis_len("cybra:kibra_chain:audit")
        },
        "anchor_queue_preview": latest_anchor_items()
    }

    report["double_sha"] = dsha(json.dumps(report, ensure_ascii=False, sort_keys=True))

    (ROOT / "feeds/owner_orchestrator_finance_anchor_car.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )

    md = f"""# CYBRA Owner Orchestrator / Finance Risk / External Anchor / Car Purchase Preflight

Status: **ready**

## Owner role

- OWNER role: **MAIN_ORCHESTRATOR**
- Real payment execution: **false**
- Real external blockchain transaction: **false**
- Manual OWNER approval required: **true**

## Finance risk decision

- Decision: **{finance_decision["status"]}**
- Payment execution allowed: **false**
- Allowed next stage: **{finance_decision["allowed_next_stage"]}**

Reason:

{finance_decision["reason"]}

## External blockchain anchor

- Status: **{external_anchor_decision["status"]}**
- Automatic on-chain tx: **false**
- Manual wallet signature required: **true**
- Anchor queue count: **{external_anchor_decision["anchor_queue_count"]}**
- Latest KIBRA hash: `{latest_kibra_hash}`
- Anchor root hash: `{anchor_root_hash}`

## Car purchase tomorrow: preflight

Before any payment, collect and verify:

{chr(10).join("- " + x for x in car_preflight["required_before_payment"])}

## Blocked

{chr(10).join("- " + x for x in finance_decision["blocked"])}

## Redis state

- Parliament queue: {report["redis"]["parliament_queue"]}
- Parliament results: {report["redis"]["parliament_results"]}
- Finance ledger: {report["redis"]["finance_ledger"]}
- Finance audit: {report["redis"]["finance_audit"]}
- Anchor queue: {report["redis"]["anchor_queue"]}
- KIBRA audit: {report["redis"]["kibra_audit"]}

## Proof

Double SHA:

`{report["double_sha"]}`

Anchor root hash:

`{anchor_root_hash}`
"""

    (ROOT / "posts/owner_orchestrator_finance_anchor_car.md").write_text(md, encoding="utf-8")

    with (ROOT / "proofs/owner_orchestrator_finance_anchor_car.sha256").open("w") as f:
        subprocess.run([
            "sha256sum",
            "parliament/orchestrator/main_owner_orchestrator_policy.json",
            "parliament/finance/risk_resolution/finance_risk_resolution_policy.json",
            "parliament/blockchain_anchor/external_anchor_resolution_policy.json",
            "parliament/car_purchase/car_purchase_preflight_policy.json",
            "feeds/owner_orchestrator_finance_anchor_car.json",
            "posts/owner_orchestrator_finance_anchor_car.md"
        ], cwd=ROOT, stdout=f, stderr=subprocess.DEVNULL)

    r.lpush("cybra:owner_orchestrator:audit", json.dumps({
        "status": "main_orchestrator_set",
        "owner_role": "MAIN_ORCHESTRATOR",
        "anchor_root_hash": anchor_root_hash,
        "finance_decision": finance_decision["status"],
        "car_preflight": car_preflight["status"],
        "time": report["time"]
    }, ensure_ascii=False))

    r.lpush("cybra:finance:risk_resolution", json.dumps(finance_decision, ensure_ascii=False))
    r.lpush("cybra:blockchain:anchor:manual_ready", json.dumps(external_anchor_decision, ensure_ascii=False))
    r.lpush("cybra:car_purchase:preflight", json.dumps(car_preflight, ensure_ascii=False))

    print("✅ OWNER MAIN ORCHESTRATOR SET")
    print("✅ Finance risk:", finance_decision["status"])
    print("✅ External anchor:", external_anchor_decision["status"])
    print("✅ Car preflight:", car_preflight["status"])
    print("Anchor root hash:", anchor_root_hash)
    print("Report: posts/owner_orchestrator_finance_anchor_car.md")
    print("Feed: feeds/owner_orchestrator_finance_anchor_car.json")
    print("Proof: proofs/owner_orchestrator_finance_anchor_car.sha256")

def main():
    build_report()

if __name__ == "__main__":
    main()
PY

chmod +x cybra_owner_orchestrator_finance_anchor_car.py

cat > owner_orchestrator_handler.sh <<'EOF2'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"
python3 cybra_owner_orchestrator_finance_anchor_car.py
EOF2

chmod +x owner_orchestrator_handler.sh

cat > cybra_owner_orchestrator.sh <<'EOF2'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

case "${1:-status}" in
  run)
    python3 cybra_owner_orchestrator_finance_anchor_car.py
    ;;
  task)
    cybra parliament '{"topic":"Set OWNER as MAIN_ORCHESTRATOR and resolve finance risk / external anchor / car preflight","type":"owner_orchestrator_task","priority":"critical","payload":{"owner_role":"MAIN_ORCHESTRATOR","finance_risk":"conditional_hold_until_documents","external_anchor":"manual_anchor_package_ready","car_purchase":"tomorrow_preflight","real_payment_execution":false,"manual_owner_approval_required":true}}'
    ;;
  status)
    redis-cli ping
    echo "OWNER_ORCHESTRATOR_AUDIT: $(redis-cli LLEN cybra:owner_orchestrator:audit)"
    echo "FINANCE_RISK_RESOLUTION: $(redis-cli LLEN cybra:finance:risk_resolution)"
    echo "ANCHOR_MANUAL_READY: $(redis-cli LLEN cybra:blockchain:anchor:manual_ready)"
    echo "CAR_PREFLIGHT: $(redis-cli LLEN cybra:car_purchase:preflight)"
    echo "PARLIAMENT_QUEUE: $(redis-cli LLEN cybra:parliament:queue)"
    echo "PARLIAMENT_RESULTS: $(redis-cli LLEN cybra:parliament:results)"
    test -f posts/owner_orchestrator_finance_anchor_car.md && echo "REPORT: exists" || echo "REPORT: missing"
    ;;
  report)
    cat posts/owner_orchestrator_finance_anchor_car.md
    ;;
  feed)
    cat feeds/owner_orchestrator_finance_anchor_car.json
    ;;
  proof)
    cat proofs/owner_orchestrator_finance_anchor_car.sha256
    ;;
  anchor-ready)
    redis-cli LRANGE cybra:blockchain:anchor:manual_ready 0 10
    ;;
  car)
    redis-cli LRANGE cybra:car_purchase:preflight 0 10
    ;;
  *)
    echo "Usage: bash cybra_owner_orchestrator.sh run|task|status|report|feed|proof|anchor-ready|car"
    ;;
esac
EOF2

chmod +x cybra_owner_orchestrator.sh

redis-cli HSET cybra:executor:mapping owner_orchestrator_task owner_orchestrator_handler.sh >/dev/null

python3 - <<'PY'
from pathlib import Path

p = Path("parliament_executor_v6.py")
s = p.read_text()

if 'r.hget("cybra:executor:mapping", task_type)' not in s:
    old = "script_name = SCRIPT_MAP.get(task_type)"
    new = 'script_name = r.hget("cybra:executor:mapping", task_type) or SCRIPT_MAP.get(task_type)'
    if old in s:
        s = s.replace(old, new, 1)

if '"owner_orchestrator_task"' not in s:
    i = s.find("SCRIPT_MAP")
    j = s.find("{", i)
    if i >= 0 and j >= 0:
        s = s[:j+1] + '\n    "owner_orchestrator_task": "owner_orchestrator_handler.sh",' + s[j+1:]

p.write_text(s)
print("✅ owner_orchestrator_task mapping ready")
PY

rm -rf __pycache__
python3 -m py_compile parliament_executor_v6.py
rm -rf __pycache__

echo
echo "=== RUN DIRECT ==="
bash cybra_owner_orchestrator.sh run

echo
echo "=== RUN THROUGH PARLIAMENT TASK ==="
bash cybra_owner_orchestrator.sh task
for i in $(seq 1 20); do
  python3 parliament_executor_v6.py || true
  sleep 1
  [ "$(redis-cli LLEN cybra:parliament:queue)" = "0" ] && break
done

echo
echo "=== STATUS ==="
bash cybra_owner_orchestrator.sh status
cybra status || true

echo
echo "=== REPORT ==="
cat posts/owner_orchestrator_finance_anchor_car.md

echo
echo "✅ DONE"
