#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "=== CYBRA MAINNET DEPLOY PREPARE ==="
echo "MAINNET MODE: BLOCKED UNTIL OWNER APPROVAL"

TS="$(date +%Y%m%d_%H%M%S)"
SLEEP_SECONDS="${1:-60}"

echo "Timestamp: $TS"
echo "Sleep before action: $SLEEP_SECONDS seconds"

read -p "Type APPROVE_MAINNET_DEPLOY to continue: " OK

if [ "$OK" != "APPROVE_MAINNET_DEPLOY" ]; then
  echo "Cancelled. Mainnet not executed."
  exit 1
fi

echo "Sleeping $SLEEP_SECONDS seconds..."
sleep "$SLEEP_SECONDS"

solana config set --url mainnet-beta

echo "MAINNET READY AFTER APPROVAL"
echo "No token created yet in this safe prepare script."

mkdir -p token/deploy/solana_mainnet/proofs

cat > token/deploy/solana_mainnet/mainnet_prepare_$TS.json <<JSON
{
  "chain": "solana_mainnet",
  "timestamp": "$TS",
  "sleep_seconds": "$SLEEP_SECONDS",
  "status": "approved_prepare_only",
  "mainnet_deploy": "not_executed"
}
JSON

sha256sum token/deploy/solana_mainnet/mainnet_prepare_$TS.json > token/deploy/solana_mainnet/proofs/mainnet_prepare_$TS.sha256

echo "✅ Mainnet timestamp sleep prepare complete"
