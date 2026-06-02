#!/data/data/com.termux/files/usr/bin/bash
set -e

mkdir -p posts proofs token/wallet

MINT=$(grep -RhoE '[1-9A-HJ-NP-Za-km-z]{32,44}' posts token/registry proofs 2>/dev/null | head -1 || true)

if [ -z "$MINT" ]; then
  echo "❌ Mint address не знайдено"
  exit 1
fi

cat > token/wallet/phantom_add.json <<JSON
{
  "wallet": "Phantom",
  "network": "Solana Devnet",
  "token_symbol": "CYBRA",
  "mint_address": "$MINT",
  "status": "ready_to_add_manually"
}
JSON

cat > posts/phantom_add_cybra.md <<MD
# Add CYBRA to Phantom

Network:
Solana Devnet

Token:
CYBRA

Mint address:
$MINT

Steps:
1. Open Phantom
2. Switch network to Devnet
3. Add / Manage tokens
4. Paste mint address
5. Confirm
MD

sha256sum token/wallet/phantom_add.json posts/phantom_add_cybra.md > proofs/phantom_add_cybra.sha256

echo "✅ Phantom add prepared"
echo "Mint: $MINT"
