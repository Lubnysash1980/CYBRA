#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA" || exit 1

echo "=== CREATE IT TASKS: TWO SOLANA MINTS + NATIVE TOKEN + POOL ==="

mkdir -p \
  data/it_department/tasks \
  data/finance_department/tasks \
  data/kibra_dex_pool/tasks \
  data/native_token_nft_proof/tasks \
  data/solana_two_mints_native_pool/reports \
  posts feeds proofs runtime/redis logs/it \
  data/kibra_dex_pool/private

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

OWNER = "EPEhVVhY7AXzWqcJeidWNuBqNbGDjJF35JzPVFXEbYxv"

ALEX_MINT = "BNhNw6waDiEobccELrZ483aYEqFRzYGwwHB6DLk5VnFr"
EFI_MINT = "EfiCgx3svRwZ1voPXsnYdZo35kzyt5Ct7UHLuvnm6fcR"
KIBRA_NATIVE_MINT = "F5zxQyxq8qWdyauN8ArPofkKKVFxbeTAWSd1oeyazfeU"
USDC_MINT = "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v"

BASE_TOKENS = 32000
TARGET_USDC = 2000000
PRICE = TARGET_USDC / BASE_TOKENS

BASE_DECIMALS = 9
USDC_DECIMALS = 6

BASE_AMOUNT_RAW = int(BASE_TOKENS * (10 ** BASE_DECIMALS))
USDC_AMOUNT_RAW = int(TARGET_USDC * (10 ** USDC_DECIMALS))

def sha(x):
    return hashlib.sha256(x.encode("utf-8")).hexdigest()

def dsha(obj):
    raw = json.dumps(obj, ensure_ascii=False, sort_keys=True)
    return sha(sha(raw))

def write_json(path, obj):
    p = ROOT / path
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")

def write_text(path, text):
    p = ROOT / path
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text, encoding="utf-8")

timestamp = time.strftime("%Y-%m-%dT%H:%M:%S%z")

task = {
    "status": "IT_TASK_TWO_SOLANA_MINTS_NATIVE_TOKEN_POOL_CREATED",
    "timestamp": timestamp,
    "title": "IT Department: prepare pool tasks for two Solana mints and native token proof",
    "owner_wallet": OWNER,
    "solana_mints": {
        "mint_1": {
            "symbol": "ALEX",
            "mint": ALEX_MINT,
            "pool_pair": "ALEX/USDC"
        },
        "mint_2": {
            "symbol": "EFI",
            "mint": EFI_MINT,
            "pool_pair": "EFI/USDC"
        },
        "quote": {
            "symbol": "USDC",
            "mint": USDC_MINT
        }
    },
    "native_token": {
        "symbol": "KIBRA",
        "mint": KIBRA_NATIVE_MINT,
        "proof_type": "NFT_PROOF_OF_NATIVE_TOKEN"
    },
    "pool_target": {
        "base_tokens_ui": BASE_TOKENS,
        "quote_usdc_ui": TARGET_USDC,
        "target_price_usd_per_token": PRICE,
        "base_amount_raw": str(BASE_AMOUNT_RAW),
        "quote_amount_raw": str(USDC_AMOUNT_RAW),
        "pairs_to_prepare": [
            "ALEX/USDC",
            "EFI/USDC"
        ],
        "native_token_proof_to_attach": "KIBRA NFT-proof metadata"
    },
    "it_department_tasks": [
        {
            "task": "Prepare ALEX/USDC pool plan",
            "base_mint": ALEX_MINT,
            "quote_mint": USDC_MINT,
            "base_amount_raw": str(BASE_AMOUNT_RAW),
            "quote_amount_raw": str(USDC_AMOUNT_RAW),
            "live_create": False
        },
        {
            "task": "Prepare EFI/USDC pool plan",
            "base_mint": EFI_MINT,
            "quote_mint": USDC_MINT,
            "base_amount_raw": str(BASE_AMOUNT_RAW),
            "quote_amount_raw": str(USDC_AMOUNT_RAW),
            "live_create": False
        },
        {
            "task": "Attach native KIBRA token NFT-proof to pool package",
            "native_token_mint": KIBRA_NATIVE_MINT,
            "proof_required": True,
            "real_onchain_nft_mint_now": False
        },
        {
            "task": "Run clean RPC gate before any blockchain proof",
            "blocked_rpc_action": "If sinkhole.cert.gov.ua detected, stop live activation and use Oracle VPS/VPN.",
            "required_before_real_tx": True
        },
        {
            "task": "Run owner balance check after clean RPC",
            "check": [
                "owner has 32,000 ALEX or 32,000 EFI",
                "owner/liquidity source has 2,000,000 USDC",
                "owner has SOL for fees"
            ],
            "required_before_real_tx": True
        }
    ],
    "finance_department_tasks": [
        "Keep 62.5 USD/token as target reference only.",
        "Do not mark real market price until DEX reserves are on-chain verified.",
        "Require USDC reserve proof before market confirmation.",
        "Prepare liquidity requirement report."
    ],
    "cyber_parliament_tasks": [
        "Review pool proposal.",
        "Review native token NFT-proof.",
        "Block fake/manual price activation.",
        "Approve only after real reserve proof and OWNER confirmation."
    ],
    "safety": {
        "real_payment_now": False,
        "automatic_SWIFT": False,
        "automatic_external_tx": False,
        "automatic_price_manipulation": False,
        "mainnet_deploy_allowed": False,
        "real_mainnet_tx_executed": False,
        "real_market_confirmed": False,
        "live_dex_create": False,
        "manual_OWNER_approval_required": True,
        "approval_phrase_required_later": "I_ACCEPT_DEX_POOL_CREATION_RISK"
    }
}

task["double_sha"] = dsha(task)
short = task["double_sha"][:16]

write_json("feeds/solana_two_mints_native_pool_it_task.json", task)
write_json("data/it_department/tasks/solana_two_mints_native_pool_task.json", task)
write_json("data/finance_department/tasks/solana_two_mints_native_pool_task.json", task)
write_json("data/kibra_dex_pool/tasks/solana_two_mints_native_pool_task.json", task)
write_json("data/native_token_nft_proof/tasks/native_token_pool_proof_task.json", task)
write_json("data/solana_two_mints_native_pool/reports/latest_report.json", task)

env_text = f"""# CYBRA two Solana mints + native token pool task
RPC_URL=https://api.mainnet-beta.solana.com
CLUSTER=mainnet-beta

OWNER_WALLET={OWNER}

ALEX_MINT={ALEX_MINT}
EFI_MINT={EFI_MINT}
KIBRA_NATIVE_MINT={KIBRA_NATIVE_MINT}
USDC_MINT={USDC_MINT}

BASE_TOKENS_UI={BASE_TOKENS}
TARGET_USDC_UI={TARGET_USDC}
TARGET_PRICE_USD_PER_TOKEN={PRICE}

BASE_AMOUNT_RAW={BASE_AMOUNT_RAW}
QUOTE_AMOUNT_RAW={USDC_AMOUNT_RAW}

POOL_PAIR_1=ALEX/USDC
POOL_PAIR_2=EFI/USDC

LIVE_DEX_CREATE=false
CYBRA_DEX_APPROVAL=NO
REAL_MARKET_CONFIRMED=false
REAL_MAINNET_TX_EXECUTED=false
MANUAL_OWNER_APPROVAL_REQUIRED=true
"""
write_text("data/kibra_dex_pool/private/.env.two_mints_native_pool", env_text)

md = f"""# IT Task: Two Solana Mints + Native Token + Pool

Status: {task['status']}  
Timestamp: {timestamp}

## Mints

ALEX mint: `{ALEX_MINT}`  
EFI mint: `{EFI_MINT}`  
Native KIBRA token mint: `{KIBRA_NATIVE_MINT}`  
USDC mint: `{USDC_MINT}`  

## Pool target

Pairs:

- ALEX/USDC
- EFI/USDC

Base tokens: {BASE_TOKENS}  
Target USDC: {TARGET_USDC}  
Target price reference: {PRICE} USD/token  

Base raw: {BASE_AMOUNT_RAW}  
USDC raw: {USDC_AMOUNT_RAW}

## IT tasks

- Prepare ALEX/USDC safe pool plan.
- Prepare EFI/USDC safe pool plan.
- Attach native KIBRA NFT-proof.
- Require clean RPC before blockchain proof.
- Require owner balance check before live transaction.
- Keep live DEX creation disabled.

## Safety

real_payment_now: false  
automatic_external_tx: false  
automatic_price_manipulation: false  
mainnet_deploy_allowed: false  
real_mainnet_tx_executed: false  
real_market_confirmed: false  
live_dex_create: false  
manual_OWNER_approval_required: true  

## Double SHA

{task['double_sha']}
"""
write_text("posts/solana_two_mints_native_pool_it_task.md", md)

raw = json.dumps(task, ensure_ascii=False)

queues = [
    "cybra:it_department:queue",
    "cybra:finance_department:queue",
    "cybra:dex_pool:queue",
    "cybra:nft_proof:queue",
    "cybra:native_token:proof_queue",
    "cybra:parliament:queue",
    "cybra:audit:queue",
    "cybra:ai:tasks:block_inbox",
    "cybra:market_activation:queue"
]

for q in queues:
    subprocess.run(["redis-cli", "LPUSH", q, raw], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

with open(ROOT / "proofs/solana_two_mints_native_pool_it_task.sha256", "w") as f:
    subprocess.run([
        "sha256sum",
        "feeds/solana_two_mints_native_pool_it_task.json",
        "data/it_department/tasks/solana_two_mints_native_pool_task.json",
        "data/finance_department/tasks/solana_two_mints_native_pool_task.json",
        "data/kibra_dex_pool/tasks/solana_two_mints_native_pool_task.json",
        "data/native_token_nft_proof/tasks/native_token_pool_proof_task.json",
        "data/solana_two_mints_native_pool/reports/latest_report.json",
        "posts/solana_two_mints_native_pool_it_task.md"
    ], cwd=ROOT, stdout=f)

print("✅ IT task created")
print("ALEX:", ALEX_MINT)
print("EFI:", EFI_MINT)
print("KIBRA_NATIVE:", KIBRA_NATIVE_MINT)
print("USDC:", USDC_MINT)
print("TARGET_PRICE:", PRICE)
print("DOUBLE_SHA:", task["double_sha"])
PY

echo
echo "=== VERIFY ==="
sha256sum -c proofs/solana_two_mints_native_pool_it_task.sha256

echo
echo "=== QUEUES ==="
echo "IT:" && redis-cli LLEN cybra:it_department:queue
echo "Finance:" && redis-cli LLEN cybra:finance_department:queue
echo "DEX Pool:" && redis-cli LLEN cybra:dex_pool:queue
echo "NFT Proof:" && redis-cli LLEN cybra:nft_proof:queue
echo "Native Proof:" && redis-cli LLEN cybra:native_token:proof_queue
echo "Parliament:" && redis-cli LLEN cybra:parliament:queue
echo "Audit:" && redis-cli LLEN cybra:audit:queue
echo "AI Inbox:" && redis-cli LLEN cybra:ai:tasks:block_inbox
echo "Market activation:" && redis-cli LLEN cybra:market_activation:queue

echo
echo "=== REPORT ==="
cat posts/solana_two_mints_native_pool_it_task.md

echo
echo "✅ DONE"
