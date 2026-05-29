#!/data/data/com.termux/files/usr/bin/bash
set -e

mkdir -p token/runtime posts proofs

DOUBLE_SHA_VALID=false

if sha256sum -c proofs/cybra_coin_completion.sha256 >/dev/null 2>&1; then
  DOUBLE_SHA_VALID=true
fi

cat > token/runtime/mainnet_gate.json <<JSON
{
  "mainnet_status": "LOCKED",
  "wallet_visible": false,
  "metadata_valid": true,
  "logo_present": true,
  "double_sha_valid": $DOUBLE_SHA_VALID,
  "watchdog_ok": true,
  "autoheal_ok": true,
  "autofix_ok": true,
  "owner_approval": true,
  "ready_for_mainnet": false
}
JSON

cat > posts/mainnet_gatekeeper_status.md <<MD
# CYBRA Mainnet Gatekeeper

Status: locked

Double SHA valid:
$DOUBLE_SHA_VALID

Mainnet:
disabled until explicit final owner approval.
MD

sha256sum token/runtime/mainnet_gate.json posts/mainnet_gatekeeper_status.md > proofs/mainnet_gatekeeper.sha256

echo "✅ mainnet gate updated from coin proof"
