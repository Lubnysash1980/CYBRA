#!/data/data/com.termux/files/usr/bin/bash
set -e

BASE="$HOME/CYBRA"

cat > "$BASE/mainnet/CYBRA/metadata/token.json" <<'JSON'
{
  "symbol": "CYBRA",
  "name": "CYBRA Native Coin",
  "network": "CYBRA Mainnet",
  "model": "native_chain_no_mint_account",
  "owner_wallet": "FesrWxqM67HrjFqsCoCHsUkRocZZBgWeg4P3T4b9FD9Y",
  "genesis_supply": 1000000,
  "logo_png": "assets/cybra_token.png",
  "logo_svg": "assets/cybra_token.svg",
  "proof": "sha256",
  "status": "mainnet_package_ready"
}
JSON

find "$BASE/mainnet/CYBRA" -type f -exec sha256sum {} \; > "$BASE/proofs/cybra_mainnet_hashes.txt"

cat > "$BASE/posts/mainnet_png_status.md" <<'MD'
# CYBRA PNG Metadata Rewrite

Metadata updated for PNG/SVG logo support.

Assets:
- assets/cybra_token.png
- assets/cybra_token.svg

Proof:
- proofs/cybra_mainnet_hashes.txt
MD

git add mainnet proofs posts site 2>/dev/null || true
git commit -m "rewrite CYBRA PNG metadata support" || true

echo "✅ PNG metadata rewritten"
