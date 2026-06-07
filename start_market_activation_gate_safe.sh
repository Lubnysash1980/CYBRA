#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA" || exit 1

echo "=== CYBRA / KIBRA MARKET ACTIVATION GATE SAFE ==="

mkdir -p \
  data/kibra_market_activation/reports \
  data/kibra_market_activation/tasks \
  data/kibra_dex_pool/private \
  posts feeds proofs logs runtime/redis

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

OWNER_WALLET = "EPEhVVhY7AXzWqcJeidWNuBqNbGDjJF35JzPVFXEbYxv"
ALEX_MINT = "BNhNw6waDiEobccELrZ483aYEqFRzYGwwHB6DLk5VnFr"
EFI_MINT = "EfiCgx3svRwZ1voPXsnYdZo35kzyt5Ct7UHLuvnm6fcR"
USDC_MINT = "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v"

TARGET_TOKENS = 32000
TARGET_USD = 2000000
TARGET_PRICE = TARGET_USD / TARGET_TOKENS

def run(cmd, timeout=30):
    try:
        r = subprocess.run(
            cmd,
            cwd=ROOT,
            shell=True,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=timeout
        )
        return r.returncode, r.stdout
    except Exception as e:
        return 999, str(e)

def sha(x):
    return hashlib.sha256(x.encode("utf-8")).hexdigest()

def dsha(obj):
    return sha(sha(json.dumps(obj, ensure_ascii=False, sort_keys=True)))

def write_json(path, obj):
    p = ROOT / path
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")

def write_text(path, text):
    p = ROOT / path
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text, encoding="utf-8")

rc, tls_out = run("curl -Iv https://api.mainnet-beta.solana.com 2>&1 | head -80", 40)

sinkhole = "sinkhole.cert.gov.ua" in tls_out.lower()
tls_ok = (rc == 0 and not sinkhole and "SSL connection using" in tls_out)

if sinkhole:
    gate_status = "BLOCKED_RPC_SINKHOLE"
elif tls_ok:
    gate_status = "RPC_TLS_CLEAN_READY_FOR_BALANCE_CHECK"
else:
    gate_status = "RPC_TLS_UNKNOWN_NOT_READY"

activation = {
    "status": gate_status,
    "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
    "owner_wallet": OWNER_WALLET,
    "target": {
        "tokens": TARGET_TOKENS,
        "target_usd": TARGET_USD,
        "target_price_usd_per_token": TARGET_PRICE,
        "formula": "2,000,000 USD / 32,000 tokens = 62.5 USD/token"
    },
    "tokens": {
        "alex_mint": ALEX_MINT,
        "efi_mint": EFI_MINT,
        "usdc_mint": USDC_MINT
    },
    "market_activation_steps": [
        "Use clean RPC / Oracle VPS / VPN.",
        "Run DEX pool safe plan.",
        "Verify owner token balance.",
        "Verify USDC liquidity balance.",
        "Create real DEX pool only after OWNER approval.",
        "Verify on-chain pool vault reserves.",
        "Submit reserve proof to Cyber Parliament.",
        "Only then set REAL_MARKET_CONFIRMED=true."
    ],
    "current_gate": {
        "rpc_tls_ok": tls_ok,
        "rpc_sinkhole_detected": sinkhole,
        "dex_live_create_allowed": False,
        "market_activation_allowed_now": False,
        "reason": "Live activation is blocked until clean RPC and real on-chain reserve proof exist."
    },
    "safety": {
        "real_payment_now": False,
        "automatic_SWIFT": False,
        "automatic_external_tx": False,
        "automatic_price_manipulation": False,
        "mainnet_deploy_allowed": False,
        "real_mainnet_tx_executed": False,
        "manual_OWNER_approval_required": True,
        "target_price_is_not_market_price": True,
        "real_market_confirmed": False
    },
    "tls_check_head": tls_out[-3000:]
}

activation["double_sha"] = dsha(activation)

write_json("feeds/kibra_market_activation_status.json", activation)
write_json("data/kibra_market_activation/reports/latest_report.json", activation)
write_json("data/kibra_market_activation/tasks/market_activation_gate_task.json", activation)

md = f"""# KIBRA / CYBRA Market Activation Gate

Status: {activation['status']}  
Timestamp: {activation['timestamp']}

## Target

32,000 tokens = 2,000,000 USD  
Target price: 62.5 USD/token

## Current Gate

rpc_tls_ok: {tls_ok}  
rpc_sinkhole_detected: {sinkhole}  
dex_live_create_allowed: false  
market_activation_allowed_now: false  
real_market_confirmed: false  
real_mainnet_tx_executed: false  

## Next real activation path

1. Clean RPC / Oracle VPS / VPN.
2. DEX pool safe plan.
3. Owner token balance check.
4. USDC liquidity balance check.
5. Real DEX pool creation only after OWNER approval.
6. Blockchain reserve proof.
7. Cyber Parliament approval.
8. REAL_MARKET_CONFIRMED=true only after proof.

## Safety

real_payment_now: false  
automatic_external_tx: false  
automatic_price_manipulation: false  
mainnet_deploy_allowed: false  
real_mainnet_tx_executed: false  
manual_OWNER_approval_required: true  
target_price_is_not_market_price: true  

## Double SHA

{activation['double_sha']}
"""

write_text("posts/kibra_market_activation_status.md", md)

raw = json.dumps(activation, ensure_ascii=False)

for q in [
    "cybra:market_activation:queue",
    "cybra:finance_department:queue",
    "cybra:parliament:queue",
    "cybra:audit:queue"
]:
    subprocess.run(["redis-cli", "LPUSH", q, raw], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

with open(ROOT / "proofs/kibra_market_activation_status.sha256", "w") as f:
    subprocess.run([
        "sha256sum",
        "feeds/kibra_market_activation_status.json",
        "data/kibra_market_activation/reports/latest_report.json",
        "data/kibra_market_activation/tasks/market_activation_gate_task.json",
        "posts/kibra_market_activation_status.md"
    ], cwd=ROOT, stdout=f)

print("STATUS:", activation["status"])
print("RPC_TLS_OK:", tls_ok)
print("SINKHOLE:", sinkhole)
print("TARGET_PRICE:", TARGET_PRICE)
print("DOUBLE_SHA:", activation["double_sha"])
PY

echo
echo "=== VERIFY ==="
sha256sum -c proofs/kibra_market_activation_status.sha256

echo
echo "=== QUEUES ==="
echo "Market activation:" && redis-cli LLEN cybra:market_activation:queue
echo "Finance:" && redis-cli LLEN cybra:finance_department:queue
echo "Parliament:" && redis-cli LLEN cybra:parliament:queue
echo "Audit:" && redis-cli LLEN cybra:audit:queue

echo
echo "=== REPORT ==="
cat posts/kibra_market_activation_status.md

echo
echo "✅ MARKET ACTIVATION GATE CREATED"
