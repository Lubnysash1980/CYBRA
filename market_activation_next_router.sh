#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA" || exit 1

echo "=== MARKET ACTIVATION NEXT ROUTER ==="

STATUS="$(python3 - <<'PY'
import json
from pathlib import Path
p=Path("feeds/kibra_market_activation_status.json")
if not p.exists():
    print("NO_STATUS")
else:
    print(json.loads(p.read_text()).get("status","UNKNOWN"))
PY
)"

echo "STATUS=$STATUS"

if [ "$STATUS" = "BLOCKED_RPC_SINKHOLE" ]; then
  echo
  echo "⛔ Termux market activation STOP."
  echo "Reason: RPC blocked / sinkhole.cert.gov.ua"
  echo
  echo "Next options:"
  echo "1) Увімкнути чистий VPN і знову:"
  echo "   bash start_market_activation_gate_safe.sh"
  echo
  echo "2) Або запускати market proof на Oracle VPS."
  echo
  echo "Live DEX create залишаємо вимкненим."

  mkdir -p posts feeds data/kibra_market_activation/reports proofs

  cat > posts/kibra_market_activation_next.md <<EOF
# Market Activation Next

Status: BLOCKED_RPC_SINKHOLE

Termux market activation: STOP

Reason: Solana RPC certificate shows sinkhole / blocked route.

Next:

1. Use clean VPN and rerun \`bash start_market_activation_gate_safe.sh\`
2. Or use Oracle VPS for blockchain proof
3. Do not run live DEX create from this network

Safety:

real_market_confirmed: false  
real_mainnet_tx_executed: false  
live_dex_create: false  
EOF

  cat > feeds/kibra_market_activation_next.json <<EOF
{
  "status": "BLOCKED_RPC_SINKHOLE_NEXT_REQUIRED",
  "termux_market_activation": false,
  "need_clean_vpn_or_oracle_vps": true,
  "real_market_confirmed": false,
  "real_mainnet_tx_executed": false,
  "live_dex_create": false
}
EOF

  sha256sum posts/kibra_market_activation_next.md feeds/kibra_market_activation_next.json \
    > proofs/kibra_market_activation_next.sha256

  sha256sum -c proofs/kibra_market_activation_next.sha256
  exit 0
fi

if [ "$STATUS" != "RPC_TLS_CLEAN_READY_FOR_BALANCE_CHECK" ]; then
  echo
  echo "⚠️ Status not ready for balance check: $STATUS"
  echo "Run first:"
  echo "bash start_market_activation_gate_safe.sh"
  exit 1
fi

echo
echo "✅ RPC clean. Starting owner balance + liquidity check..."

cat > kibra_market_balance_check.py <<'PY'
import json, time, hashlib, subprocess
from pathlib import Path

ROOT = Path.home() / "CYBRA"

RPC_URL = "https://api.mainnet-beta.solana.com"
OWNER = "EPEhVVhY7AXzWqcJeidWNuBqNbGDjJF35JzPVFXEbYxv"

ALEX_MINT = "BNhNw6waDiEobccELrZ483aYEqFRzYGwwHB6DLk5VnFr"
EFI_MINT = "EfiCgx3svRwZ1voPXsnYdZo35kzyt5Ct7UHLuvnm6fcR"
USDC_MINT = "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v"

TARGET_TOKEN_UI = 32000
TARGET_USDC_UI = 2000000

def run_rpc(payload):
    raw = json.dumps(payload)
    r = subprocess.run(
        ["curl", "-sS", RPC_URL, "-H", "Content-Type: application/json", "-d", raw],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=40
    )
    if r.returncode != 0:
        return {"error": r.stdout}
    try:
        return json.loads(r.stdout)
    except Exception:
        return {"error": r.stdout}

def get_sol_balance(owner):
    res = run_rpc({
        "jsonrpc": "2.0",
        "id": 1,
        "method": "getBalance",
        "params": [owner]
    })
    lamports = res.get("result", {}).get("value")
    if lamports is None:
        return None, res
    return lamports / 1_000_000_000, res

def get_token_balance(owner, mint):
    res = run_rpc({
        "jsonrpc": "2.0",
        "id": 1,
        "method": "getTokenAccountsByOwner",
        "params": [
            owner,
            {"mint": mint},
            {"encoding": "jsonParsed", "commitment": "confirmed"}
        ]
    })

    total = 0.0
    accounts = res.get("result", {}).get("value", [])

    for acc in accounts:
        try:
            amt = acc["account"]["data"]["parsed"]["info"]["tokenAmount"]
            total += float(amt.get("uiAmount") or 0)
        except Exception:
            pass

    return total, res

sol_ui, sol_raw = get_sol_balance(OWNER)
alex_ui, alex_raw = get_token_balance(OWNER, ALEX_MINT)
efi_ui, efi_raw = get_token_balance(OWNER, EFI_MINT)
usdc_ui, usdc_raw = get_token_balance(OWNER, USDC_MINT)

alex_ready = alex_ui >= TARGET_TOKEN_UI
efi_ready = efi_ui >= TARGET_TOKEN_UI
base_ready = alex_ready or efi_ready
usdc_ready = usdc_ui >= TARGET_USDC_UI

activation_ready = base_ready and usdc_ready

status = "BALANCE_READY_FOR_OWNER_APPROVAL" if activation_ready else "BALANCE_NOT_ENOUGH_FOR_MARKET_ACTIVATION"

report = {
    "status": status,
    "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
    "owner_wallet": OWNER,
    "target": {
        "tokens_ui": TARGET_TOKEN_UI,
        "usdc_ui": TARGET_USDC_UI,
        "target_price_usd_per_token": 62.5
    },
    "balances": {
        "sol_ui": sol_ui,
        "alex_ui": alex_ui,
        "efi_ui": efi_ui,
        "usdc_ui": usdc_ui
    },
    "ready": {
        "alex_ready": alex_ready,
        "efi_ready": efi_ready,
        "base_token_ready": base_ready,
        "usdc_liquidity_ready": usdc_ready,
        "activation_ready_for_owner_approval": activation_ready
    },
    "safety": {
        "real_payment_now": False,
        "automatic_external_tx": False,
        "automatic_price_manipulation": False,
        "real_mainnet_tx_executed": False,
        "real_market_confirmed": False,
        "manual_OWNER_approval_required": True
    },
    "next": []
}

if activation_ready:
    report["next"] = [
        "Prepare DEX pool transaction plan.",
        "Require OWNER approval before any live transaction.",
        "Create real DEX pool only after explicit approval.",
        "Verify pool vault reserves on-chain.",
        "Submit reserve proof to Cyber Parliament."
    ]
else:
    report["next"] = [
        "Add enough base token balance: 32,000 ALEX or 32,000 EFI.",
        "Add enough USDC liquidity: 2,000,000 USDC.",
        "Rerun balance check."
    ]

raw = json.dumps(report, ensure_ascii=False, sort_keys=True)
report["double_sha"] = hashlib.sha256(hashlib.sha256(raw.encode()).hexdigest().encode()).hexdigest()

for path in [
    "feeds/kibra_market_balance_check.json",
    "data/kibra_market_activation/reports/latest_balance_check.json"
]:
    p = ROOT / path
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

md = f"""# KIBRA Market Balance Check

Status: {report['status']}  
Timestamp: {report['timestamp']}

## Target

Base token: 32,000  
USDC liquidity: 2,000,000  
Target price: 62.5 USD/token

## Balances

SOL: {sol_ui}  
ALEX: {alex_ui}  
EFI: {efi_ui}  
USDC: {usdc_ui}

## Ready

ALEX ready: {alex_ready}  
EFI ready: {efi_ready}  
Base token ready: {base_ready}  
USDC liquidity ready: {usdc_ready}  
Ready for OWNER approval: {activation_ready}

## Safety

real_payment_now: false  
automatic_external_tx: false  
real_mainnet_tx_executed: false  
real_market_confirmed: false  
manual_OWNER_approval_required: true  

## Double SHA

{report['double_sha']}
"""

(ROOT / "posts/kibra_market_balance_check.md").write_text(md, encoding="utf-8")

with open(ROOT / "proofs/kibra_market_balance_check.sha256", "w") as f:
    subprocess.run([
        "sha256sum",
        "feeds/kibra_market_balance_check.json",
        "data/kibra_market_activation/reports/latest_balance_check.json",
        "posts/kibra_market_balance_check.md"
    ], cwd=ROOT, stdout=f)

print(json.dumps(report, ensure_ascii=False, indent=2))
PY

python3 kibra_market_balance_check.py

echo
echo "=== VERIFY ==="
sha256sum -c proofs/kibra_market_balance_check.sha256

echo
echo "=== REPORT ==="
cat posts/kibra_market_balance_check.md
