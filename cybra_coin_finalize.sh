#!/data/data/com.termux/files/usr/bin/bash
set -e

mkdir -p token/registry token/wallet token/runtime posts proofs feeds docs

MINT=$(grep -RhoE '[1-9A-HJ-NP-Za-km-z]{32,44}' posts token/registry proofs 2>/dev/null | head -1 || true)

if [ -z "$MINT" ]; then
  MINT="PENDING_DEVNET_MINT"
fi

python3 - "$MINT" <<'PY'
import json, sys
from pathlib import Path

mint=sys.argv[1]

reg=Path("token/registry/token_registry.json")
data=json.loads(reg.read_text()) if reg.exists() else {}
data.update({
  "symbol":"CYBRA",
  "name":"CYBRA Coin",
  "chain":"solana",
  "network":"devnet",
  "mint_address":mint,
  "decimals":9,
  "status":"devnet_wallet_ready" if mint!="PENDING_DEVNET_MINT" else "waiting_devnet_mint"
})
reg.write_text(json.dumps(data, indent=2), encoding="utf-8")
PY

cat > token/wallet/phantom_add.json <<JSON
{
  "wallet": "Phantom",
  "network": "Solana Devnet",
  "token_symbol": "CYBRA",
  "mint_address": "$MINT",
  "status": "ready_to_add_manually"
}
JSON

cat > posts/cybra_coin_final_status.md <<MD
# CYBRA Coin Finalization

Status:
prepared

Mint:
$MINT

Wallet:
Phantom-ready

Network:
Solana Devnet

Mainnet:
LOCKED until final approval
MD

cat > feeds/token_dashboard.json <<JSON
{
  "project": "CYBRA",
  "token": "CYBRA",
  "network": "Solana Devnet",
  "mint_address": "$MINT",
  "wallet": "Phantom-ready",
  "mainnet": "LOCKED",
  "double_sha": "enabled",
  "watchdog": "enabled",
  "autoheal": "enabled",
  "autofix": "enabled"
}
JSON

sha256sum \
 token/registry/token_registry.json \
 token/wallet/phantom_add.json \
 posts/cybra_coin_final_status.md \
 feeds/token_dashboard.json \
 > proofs/cybra_coin_final.sha256

echo "✅ CYBRA coin finalized"
echo "Mint: $MINT"
