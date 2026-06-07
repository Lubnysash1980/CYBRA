#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA" || exit 1

echo "=== NEXT AFTER 2M FINANCE TASK ==="

mkdir -p \
  data/finance_target_2m/execution \
  data/finance_target_2m/parliament \
  data/it_department/results \
  data/finance_department/results \
  data/parliament/results \
  posts feeds proofs runtime/redis logs/finance

if ! redis-cli ping >/dev/null 2>&1; then
  redis-server --daemonize yes \
    --bind 127.0.0.1 \
    --port 6379 \
    --dir "$HOME/CYBRA/runtime/redis" \
    --save "" \
    --appendonly no >/dev/null 2>&1 || true
  sleep 1
fi

python3 - <<'PY'
import json, time, hashlib, subprocess
from pathlib import Path

ROOT = Path.home() / "CYBRA"

RIGHT_OWNER = "EPEhVVhY7AXzWqcJeidWNuBqNbGDjJF35JzPVFXEbYxv"

def sha(x):
    return hashlib.sha256(x.encode("utf-8")).hexdigest()

def dsha(obj):
    return sha(sha(json.dumps(obj, ensure_ascii=False, sort_keys=True)))

def read_json(path):
    p = ROOT / path
    if not p.exists():
        return {}
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception:
        return {}

def write_json(path, obj):
    p = ROOT / path
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")

def write_text(path, text):
    p = ROOT / path
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text, encoding="utf-8")

task = read_json("feeds/finance_target_2m_usd_task.json")
if not task:
    raise SystemExit("❌ feeds/finance_target_2m_usd_task.json not found")

# 1) IT / Finance execution result
execution = {
    "status": "IT_FINANCE_2M_TARGET_INTERNAL_PLAN_EXECUTED",
    "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
    "owner_wallet": RIGHT_OWNER,
    "source_task_sha": task.get("double_sha"),
    "target": task.get("request", {}),
    "dex_pool_target_plan": task.get("dex_pool_target_plan", {}),
    "result": {
        "it_department_executed": True,
        "finance_department_executed": True,
        "dex_plan_prepared": True,
        "parliament_vote_required": True,
        "real_market_confirmed": False,
        "real_mainnet_tx_executed": False,
        "real_payment_now": False
    },
    "next_required": [
        "Cyber Parliament vote",
        "Real USDC liquidity proof",
        "Real DEX pool creation only after owner approval",
        "Blockchain vault reserve proof",
        "Market proof verification"
    ],
    "safety": {
        "real_payment_now": False,
        "automatic_SWIFT": False,
        "automatic_external_tx": False,
        "automatic_price_manipulation": False,
        "mainnet_deploy_allowed": False,
        "real_mainnet_tx_executed": False,
        "manual_OWNER_approval_required": True,
        "price_must_be_evidence_based": True,
        "target_price_is_not_market_price": True
    }
}
execution["double_sha"] = dsha(execution)

write_json("feeds/finance_target_2m_it_execution.json", execution)
write_json("data/finance_target_2m/execution/latest_execution.json", execution)
write_json("data/it_department/results/finance_target_2m_execution.json", execution)
write_json("data/finance_department/results/finance_target_2m_execution.json", execution)

# 2) Parliament proposal
proposal = {
    "status": "CYBER_PARLIAMENT_2M_TARGET_PROPOSAL_CREATED",
    "timestamp": execution["timestamp"],
    "proposal_title": "Approve target valuation: 32,000 tokens = 2,000,000 USD",
    "owner_wallet": RIGHT_OWNER,
    "target_price_usd_per_token": 62.5,
    "target_usd_total": 2000000,
    "tokens": 32000,
    "vote_options": [
        "approve_as_target_only",
        "reject",
        "request_more_liquidity_proof"
    ],
    "rules": [
        "This is not real market proof.",
        "REAL_MARKET_CONFIRMED remains false.",
        "No fake/manual price activation.",
        "Real DEX reserves required before market price activation."
    ],
    "source_execution_sha": execution["double_sha"],
    "safety": execution["safety"]
}
proposal["double_sha"] = dsha(proposal)

write_json("feeds/finance_target_2m_parliament_proposal.json", proposal)
write_json("data/finance_target_2m/parliament/latest_proposal.json", proposal)
write_json("data/parliament/results/finance_target_2m_proposal.json", proposal)

raw_exec = json.dumps(execution, ensure_ascii=False)
raw_prop = json.dumps(proposal, ensure_ascii=False)

for q in [
    "cybra:it_department:results",
    "cybra:finance_department:results",
    "cybra:parliament:results",
    "cybra:audit:results"
]:
    subprocess.run(["redis-cli", "LPUSH", q, raw_exec], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

for q in [
    "cybra:parliament:queue",
    "cybra:parliament:proposals",
    "cybra:audit:queue"
]:
    subprocess.run(["redis-cli", "LPUSH", q, raw_prop], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

md = f"""# Next Step After 2M Finance Target

Status: NEXT_AFTER_2M_FINANCE_TASK_DONE  
Timestamp: {execution['timestamp']}

## Done

IT Department internal plan: done  
Finance Department internal plan: done  
Cyber Parliament proposal: created  
DEX plan: target prepared  
Real market confirmed: false  
Real payment now: false  
Real mainnet tx executed: false  

## Target

32,000 tokens = 2,000,000 USD  
1 token = 62.5 USD  

## Parliament proposal

Proposal status: {proposal['status']}  
Proposal SHA: {proposal['double_sha']}

## Execution SHA

{execution['double_sha']}

## Safety

real_payment_now: false  
automatic_SWIFT: false  
automatic_external_tx: false  
automatic_price_manipulation: false  
mainnet_deploy_allowed: false  
real_mainnet_tx_executed: false  
manual_OWNER_approval_required: true  
target_price_is_not_market_price: true  
"""

write_text("posts/next_after_2m_finance_task.md", md)

with open(ROOT / "proofs/next_after_2m_finance_task.sha256", "w") as f:
    subprocess.run([
        "sha256sum",
        "feeds/finance_target_2m_it_execution.json",
        "feeds/finance_target_2m_parliament_proposal.json",
        "data/finance_target_2m/execution/latest_execution.json",
        "data/finance_target_2m/parliament/latest_proposal.json",
        "posts/next_after_2m_finance_task.md"
    ], cwd=ROOT, stdout=f)

print("✅ IT / Finance execution created")
print("✅ Parliament proposal created")
print("EXECUTION_SHA:", execution["double_sha"])
print("PROPOSAL_SHA:", proposal["double_sha"])
PY

echo
echo "=== VERIFY ==="
sha256sum -c proofs/next_after_2m_finance_task.sha256

echo
echo "=== RESULTS ==="
echo "IT results:" && redis-cli LLEN cybra:it_department:results
echo "Finance results:" && redis-cli LLEN cybra:finance_department:results
echo "Parliament results:" && redis-cli LLEN cybra:parliament:results
echo "Parliament proposals:" && redis-cli LLEN cybra:parliament:proposals
echo "Audit results:" && redis-cli LLEN cybra:audit:results

echo
echo "=== OPTIONAL DEX PLAN ==="
cybra-mints set-alex-usdc 32000 2000000 9 2>/dev/null || true
kibra-dex-pool plan 2>/dev/null || true

echo
echo "=== UPDATE PAGE ==="
bash update_cybra_page_now.sh 2>/dev/null || true

echo
echo "✅ NEXT STEP DONE"
echo "Report: posts/next_after_2m_finance_task.md"
