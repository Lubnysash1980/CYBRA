#!/data/data/com.termux/files/usr/bin/bash
set -e

BASE="$HOME/CYBRA"
OWNER="FesrWxqM67HrjFqsCoCHsUkRocZZBgWeg4P3T4b9FD9Y"

mkdir -p "$BASE/mainnet/CYBRA"/{chain,pools,metadata,proofs,assets}
mkdir -p "$BASE/proofs" "$BASE/site/assets" "$BASE/posts"

cp "$BASE/site/assets/cybra_token.png" "$BASE/mainnet/CYBRA/assets/cybra_token.png" 2>/dev/null || true

cat > "$BASE/mainnet/CYBRA/metadata/token.json" <<JSON
{
  "symbol": "CYBRA",
  "name": "CYBRA Native Coin",
  "network": "CYBRA Mainnet",
  "model": "native_chain_no_mint_account",
  "owner_wallet": "$OWNER",
  "genesis_supply": 1000000,
  "logo": "assets/cybra_token.png",
  "status": "mainnet_package_ready"
}
JSON

cat > "$BASE/mainnet/CYBRA/chain/genesis.json" <<JSON
{
  "index": 0,
  "type": "mainnet_genesis",
  "symbol": "CYBRA",
  "owner_wallet": "$OWNER",
  "supply": 1000000
}
JSON

cat > "$BASE/mainnet/CYBRA/pools/pools.json" <<JSON
{
  "reserve_pool": 400000,
  "liquidity_pool": 300000,
  "work_pool": 200000,
  "reward_pool": 100000
}
JSON

find "$BASE/mainnet/CYBRA" -type f -exec sha256sum {} \; > "$BASE/proofs/cybra_mainnet_hashes.txt"

cat > "$BASE/posts/cybra_mainnet_status.md" <<MD
# CYBRA Mainnet Status

CYBRA Native Coin mainnet package prepared.

Owner wallet: $OWNER  
Supply: 1000000  
Model: native_chain_no_mint_account  
Proof: proofs/cybra_mainnet_hashes.txt
MD

git add mainnet proofs posts site 2>/dev/null || true
git commit -m "prepare CYBRA native mainnet package" || true

echo "✅ CYBRA native mainnet package ready"
