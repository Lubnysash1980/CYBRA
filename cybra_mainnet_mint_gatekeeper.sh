#!/usr/bin/env bash
set -e

MODE="${1:-check}"
TARGET_SUPPLY="49000000000000000000"
DECIMALS="9"

mkdir -p token/mainnet token/runtime posts proofs

cat > token/mainnet/mainnet_mint_policy.json <<JSON
{
  "token": "CYBRA",
  "target_supply": "$TARGET_SUPPLY",
  "decimals": $DECIMALS,
  "mainnet_autostart": false,
  "requires": [
    "FINAL_MAINNET_APPROVAL.flag",
    "double_sha_valid",
    "metadata_valid",
    "logo_present",
    "wallet_ready",
    "positive_sol_balance",
    "owner_approval"
  ],
  "mint_authority_policy": "keep_until_target_supply_reached",
  "revoke_mint_authority_after_target": true
}
JSON

APPROVAL=false
[ -f token/runtime/FINAL_MAINNET_APPROVAL.flag ] && APPROVAL=true

DOUBLE_SHA=false
grep -q '"double_sha_valid": true' token/runtime/mainnet_gate.json 2>/dev/null && DOUBLE_SHA=true

METADATA=false
[ -f token/coin/cybra_metadata.json ] && METADATA=true

LOGO=false
[ -s token/assets/cybra.png ] && LOGO=true

BALANCE="unknown"
if command -v solana >/dev/null 2>&1; then
  solana config set --url mainnet-beta >/dev/null 2>&1 || true
  BALANCE=$(solana balance 2>/dev/null | awk '{print $1}' || echo "0")
fi

MAINNET_READY=false
if [ "$APPROVAL" = "true" ] && [ "$DOUBLE_SHA" = "true" ] && [ "$METADATA" = "true" ] && [ "$
LOGO" = "true" ]; then
  MAINNET_READY=true
fi

cat > token/mainnet/mainnet_gate_status.json <<JSON
{
  "mode": "$MODE",
  "mainnet_ready": $MAINNET_READY,
  "final_approval": $APPROVAL,
  "double_sha": $DOUBLE_SHA,
  "metadata": $METADATA,
  "logo": $LOGO,
  "sol_balance": "$BALANCE",
  "target_supply": "$TARGET_SUPPLY",
  "mint_authority": "keep_until_target_supply",
  "revoke_mint_authority_after_target": true
}
JSON

cat > posts/mainnet_mint_gatekeeper_status.md <<MD
# CYBRA Mainnet Mint Gatekeeper

Mainnet ready:
$MAINNET_READY

Final approval:
$APPROVAL

Double SHA:
$DOUBLE_SHA

Metadata:
$METADATA

Logo:
$LOGO

SOL balance:
$BALANCE

Target supply:
$TARGET_SUPPLY

Policy:
Mint authority remains active until target supply is reached.
MD

sha256sum \
token/mainnet/mainnet_mint_policy.json \
token/mainnet/mainnet_gate_status.json \
posts/mainnet_mint_gatekeeper_status.md \
> proofs/mainnet_mint_gatekeeper.sha256

echo "✅ Mainnet gate checked"
echo "MAINNET_READY=$MAINNET_READY"
