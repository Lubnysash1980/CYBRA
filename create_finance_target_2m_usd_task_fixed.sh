#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA" || exit 1

echo "=== SEND TASK: IT + FINANCE + CYBER PARLIAMENT / 2M USD TARGET ==="

mkdir -p \
  data/finance_target_2m/tasks \
  data/finance_target_2m/reports \
  data/kibra_dex_pool/private \
  parliament/committees/finance_market_price_committee/tasks \
  posts feeds proofs runtime/redis logs/finance

chmod 700 data/kibra_dex_pool/private 2>/dev/null || true

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

OWNER_WALLET = "EPEhVVhY7AXzWqcJeidWNuBqNbGDjJF35JzQPVFXEbYxv"
ALEX_MINT = "BNhNw6waDiEobccELrZ483aYEqFRzYGwwHB6DLk5VnFr"
EFI_MINT = "EfiCgx3svRwZ1voPXsnYdZo35kzyt5Ct7UHLuvnm6fcR"
USDC_MINT = "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v"

TOKENS = 32000
TARGET_USD = 2000000
PRICE = TARGET_USD / TOKENS

BASE_DECIMALS = 9
USDC_DECIMALS = 6

BASE_AMOUNT_RAW = int(TOKENS * (10 ** BASE_DECIMALS))
USDC_AMOUNT_RAW = int(TARGET_USD * (10 ** USDC_DECIMALS))

def sha(x):
    return hashlib.sha256(x.encode("utf-8")).hexdigest()

def dsha(obj):
    raw = json.dumps(obj, ensure_ascii=False, sort_keys=True)
    return sha(sha(raw))

def write(path, obj):
    p = ROOT / path
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")

def write_text(path, text):
    p = ROOT / path
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text, encoding="utf-8")

task = {
    "status": "FINANCE_TARGET_2M_USD_TASK_CREATED",
    "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
    "title": "IT + Finance + Cyber Parliament: target valuation 32,000 tokens = 2,000,000 USD",
    "owner_wallet": OWNER_WALLET,
    "tokens": {
        "alex_mint": ALEX_MINT,
        "efi_mint": EFI_MINT,
        "usdc_mint": USDC_MINT
    },
    "request": {
        "base_tokens_ui": TOKENS,
        "target_usd_total": TARGET_USD,
        "target_price_usd_per_token": PRICE,
        "formula": "2,000,000 USD / 32,000 tokens = 62.5 USD/token"
    },
    "dex_pool_target_plan": {
        "base_options": ["ALEX/USDC", "EFI/USDC"],
        "base_tokens_ui": TOKENS,
        "quote_usdc_ui": TARGET_USD,
        "base_decimals": BASE_DECIMALS,
        "quote_decimals": USDC_DECIMALS,
        "base_amount_raw": str(BASE_AMOUNT_RAW),
        "quote_amount_raw": str(USDC_AMOUNT_RAW),
        "initial_price_usd_per_token": PRICE,
        "real_liquidity_required": True,
        "important": "This is target valuation only. It becomes market proof only after real DEX pool reserves are verified on-chain."
    },
    "departments": {
        "it_department": [
            "Patch DEX config for target plan: 32,000 base tokens / 2,000,000 USDC.",
            "Keep live DEX create disabled.",
            "Generate plan/report only.",
            "Prepare blockchain reserve proof after real pool creation.",
            "Check owner wallet balance before any live transaction."
        ],
        "finance_department": [
            "Register 62.5 USD/token as target valuation, not market price.",
            "Require real 2,000,000 USDC liquidity or audited equivalent.",
            "Keep REAL_MARKET_CONFIRMED=false until on-chain proof passes.",
            "Prepare liquidity requirement and risk report."
        ],
        "cyber_parliament": [
            "Vote on target valuation proposal.",
            "Block fake/manual market proof activation.",
            "Require DEX pool proof, reserve proof, audit hash and OWNER approval."
        ]
    },
    "safety": {
        "real_payment_now": False,
        "automatic_SWIFT": False,
        "automatic_external_tx": False,
        "automatic_price_manipulation": False,
        "mainnet_deploy_allowed": False,
        "real_mainnet_tx_executed": False,
        "manual_OWNER_approval_required": True,
        "price_must_be_evidence_based": True,
        "target_price_is_not_market_price": True,
        "real_market_confirmed": False
    }
}

task["double_sha"] = dsha(task)

write("feeds/finance_target_2m_usd_task.json", task)
write("data/finance_target_2m/tasks/latest_task.json", task)
write(f"data/finance_target_2m/tasks/task_{task['double_sha'][:16]}.json", task)
write(f"parliament/committees/finance_market_price_committee/tasks/finance_target_2m_{task['double_sha'][:16]}.json", task)

md = f"""# Finance Target 2M USD Task

Status: {task['status']}  
Timestamp: {task['timestamp']}

## Target

Tokens: {TOKENS}  
Target USD: {TARGET_USD}  
Target price: {PRICE} USD/token  

```text
2,000,000 USD / 32,000 tokens = 62.5 USD/token

DEX Pool Target Plan

Base options:

ALEX/USDC
EFI/USDC

Base amount UI: {TOKENS}
Quote USDC UI: {TARGET_USD}

Base amount RAW: {BASE_AMOUNT_RAW}
USDC amount RAW: {USDC_AMOUNT_RAW}

Initial target price: {PRICE} USD/token

Important

This is a target valuation task, not real market proof.

REAL_MARKET_CONFIRMED stays false until:

real DEX pool exists,

real USDC reserves exist,

blockchain vault proof passes,

Cyber Parliament approves,

OWNER confirms.


Departments

IT Department: task sent
Finance Department: task sent
Cyber Parliament: task sent
Market Proof Committee: task sent
DEX Pool Committee: task sent

Safety

real_payment_now: false
automatic_SWIFT: false
automatic_external_tx: false
automatic_price_manipulation: false
mainnet_deploy_allowed: false
real_mainnet_tx_executed: false
manual_OWNER_approval_required: true
price_must_be_evidence_based: true
target_price_is_not_market_price: true

Double SHA

{task['double_sha']} """

write_text("posts/finance_target_2m_usd_task.md", md)

raw = json.dumps(task, ensure_ascii=False)

queues = [ "cybra:it_department:queue", "cybra:finance_department:queue", "cybra:parliament:queue", "cybra:ai:tasks:block_inbox", "cybra:kibra:market_proof:queue", "cybra:dex_pool:queue", "cybra:audit:queue" ]

for q in queues: subprocess.run( ["redis-cli", "LPUSH", q, raw], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL )

report = { "status": "FINANCE_TARGET_2M_USD_DISPATCHED", "timestamp": task["timestamp"], "queues": queues, "base_tokens_ui": TOKENS, "target_usd_total": TARGET_USD, "target_price_usd_per_token": PRICE, "base_amount_raw": str(BASE_AMOUNT_RAW), "quote_amount_raw": str(USDC_AMOUNT_RAW), "task_sha": task["double_sha"], "safety": task["safety"] }

write("feeds/finance_target_2m_usd_dispatch_report.json", report)
write("data/finance_target_2m/reports/latest_report.json", report)

# Also create DEX target env plan, but live creation is disabled
env_text = f"""RPC_URL=https://api.mainnet-beta.solana.com
CLUSTER=mainnet-beta
KEYPAIR_PATH=data/kibra_dex_pool/private/keypair.json
DEX_PROVIDER=raydium_cpmm

OWNER_WALLET={OWNER_WALLET}

ALEX_MINT={ALEX_MINT}
EFI_MINT={EFI_MINT}
USDC_MINT={USDC_MINT}

BASE_SYMBOL=ALEX
BASE_DECIMALS={BASE_DECIMALS}
QUOTE_SYMBOL=USDC
QUOTE_DECIMALS={USDC_DECIMALS}

KIBRA_MINT={ALEX_MINT}
KIBRA_AMOUNT_RAW={BASE_AMOUNT_RAW}
QUOTE_MINT={USDC_MINT}
QUOTE_AMOUNT_RAW={USDC_AMOUNT_RAW}

TARGET_USD_TOTAL={TARGET_USD}
TARGET_PRICE_USD_PER_TOKEN={PRICE}

FEE_CONFIG_INDEX=0
START_TIME=0

LIVE_DEX_CREATE=false
CYBRA_DEX_APPROVAL=NO
REAL_MARKET_CONFIRMED=false"""
write_text("data/kibra_dex_pool/private/.env.finance_target_2m", env_text)

with open(ROOT / "proofs/finance_target_2m_usd.sha256", "w") as f:
    subprocess.run([ "sha256sum", "feeds/finance_target_2m_usd_task.json", "feeds/finance_target_2m_usd_dispatch_report.json", "data/finance_target_2m/tasks/latest_task.json", "data/finance_target_2m/reports/latest_report.json", "posts/finance_target_2m_usd_task.md" ], cwd=ROOT, stdout=f)

print("✅ Finance target task dispatched")
print("TOKENS:", TOKENS)
print("TARGET_USD:", TARGET_USD)
print("TARGET_PRICE_USD_PER_TOKEN:", PRICE)
print("BASE_AMOUNT_RAW:", BASE_AMOUNT_RAW)
print("USDC_AMOUNT_RAW:", USDC_AMOUNT_RAW)
print("DOUBLE_SHA:", task["double_sha"])
PY

echo
echo "=== VERIFY ==="
sha256sum -c proofs/finance_target_2m_usd.sha256

echo
echo "=== QUEUES ==="
echo "IT Department:" && redis-cli LLEN cybra:it_department:queue
echo "Finance Department:" && redis-cli LLEN cybra:finance_department:queue
echo "Cyber Parliament:" && redis-cli LLEN cybra:parliament:queue
echo "AI Inbox:" && redis-cli LLEN cybra:ai:tasks:block_inbox
echo "Market Proof:" && redis-cli LLEN cybra:kibra:market_proof:queue
echo "DEX Pool:" && redis-cli LLEN cybra:dex_pool:queue
echo "Audit:" && redis-cli LLEN cybra:audit:queue

echo
echo "✅ SENT"
echo "Report: posts/finance_target_2m_usd_task.md"
