#!/data/data/com.termux/files/usr/bin/bash
set -e

mkdir -p token/deploy/solana_devnet posts proofs

cat > token/deploy/solana_devnet/deploy_cybra_spl_devnet.sh <<'BASH'
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
BASH

chmod +x token/deploy/solana_devnet/deploy_cybra_spl_devnet.sh

cat > posts/solana_devnet_spl_deploy_status.md <<'MD'
# CYBRA Solana Devnet SPL Deploy Script

Status: prepared

Script:
token/deploy/solana_devnet/deploy_cybra_spl_devnet.sh

Rules:
- devnet only
- owner approval required
- no private keys in logs
- mainnet disabled
MD

sha256sum token/deploy/solana_devnet/deploy_cybra_spl_devnet.sh posts/solana_devnet_spl_deploy_status.md > proofs/solana_devnet_spl_deploy_prepare.sha256

git add token/deploy posts/solana_devnet_spl_deploy_status.md proofs/solana_devnet_spl_deploy_prepare.sha256 solana_devnet_spl_deploy_prepare.sh
git commit -m "prepare Solana devnet SPL deploy script" || true

echo "✅ Solana devnet SPL deploy script prepared"
