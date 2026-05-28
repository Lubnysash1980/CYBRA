#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "=== CYBRA Solana Devnet SPL Deploy ==="
echo "Mode: DEVNET ONLY"

solana config set --url devnet

echo "Owner approval required before creating token."
read -p "Type APPROVE_DEVNET_DEPLOY to continue: " OK

if [ "$OK" != "APPROVE_DEVNET_DEPLOY" ]; then
  echo "Cancelled."
  exit 1
fi

echo "Creating SPL token..."
MINT=$(spl-token create-token | awk '/Creating token/ {print $3}')

echo "Creating token account..."
ACCOUNT=$(spl-token create-account "$MINT" | awk '/Creating account/ {print $3}')

echo "Minting supply..."
spl-token mint "$MINT" 1000000 "$ACCOUNT"

mkdir -p token/deploy/solana_devnet/proofs

cat > token/deploy/solana_devnet/devnet_mint_result.json <<JSON
{
  "chain": "solana_devnet",
  "symbol": "CYBRA",
  "mint": "$MINT",
  "account": "$ACCOUNT",
  "supply": 1000000,
  "status": "created_devnet"
}
JSON

sha256sum token/deploy/solana_devnet/devnet_mint_result.json > token/deploy/solana_devnet/proofs/devnet_mint_result.sha256

echo "✅ Devnet token created"
echo "Mint: $MINT"
echo "Account: $ACCOUNT"
