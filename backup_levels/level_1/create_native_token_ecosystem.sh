#!/data/data/com.termux/files/usr/bin/bash
set -e

BASE="$HOME/CYBRA"
OWNER="FesrWxqM67HrjFqsCoCHsUkRocZZBgWeg4P3T4b9FD9Y"

mkdir -p "$BASE/native_tokens/CYBRA"/{chain,pools,metadata,proofs}
mkdir -p "$BASE/proofs" "$BASE/site" "$BASE/posts"

cat > "$BASE/native_tokens/CYBRA/metadata/token.json" <<JSON
{
  "symbol": "CYBRA",
  "name": "CYBRA Native Coin",
  "model": "native_chain_no_mint_account",
  "owner_wallet": "$OWNER",
  "genesis_supply": 1000000,
  "proof": "sha256",
  "status": "created"
}
JSON

cat > "$BASE/native_tokens/CYBRA/chain/genesis.json" <<JSON
{
  "index": 0,
  "type": "genesis",
  "symbol": "CYBRA",
  "owner_wallet": "$OWNER",
  "supply": 1000000
}
JSON

cat > "$BASE/native_tokens/CYBRA/pools/pools.json" <<JSON
{
  "reserve_pool": 400000,
  "liquidity_pool": 300000,
  "work_pool": 200000,
  "reward_pool": 100000
}
JSON

find "$BASE/native_tokens/CYBRA" -type f -exec sha256sum {} \; > "$BASE/proofs/native_tokens_hashes.txt"

cat > "$BASE/site/index.html" <<HTML
<h1>CYBRA Native Coin</h1>
<p>Model: native chain, no mint account</p>
<p>Owner wallet: $OWNER</p>
<p>Supply: 1000000</p>
HTML

cat > "$BASE/posts/native_token_status.md" <<MD
# CYBRA Native Token Status

CYBRA Native Coin created.

Owner wallet: $OWNER  
Supply: 1000000  
Model: native_chain_no_mint_account  

Proofs: proofs/native_tokens_hashes.txt
MD

git add native_tokens proofs site posts create_native_token_ecosystem.sh 2>/dev/null || true
git commit -m "create CYBRA native token ecosystem" 2>/dev/null || true

echo "✅ CYBRA native token ecosystem created"
