#!/data/data/com.termux/files/usr/bin/bash
set -e

BASE="$HOME/CYBRA"
mkdir -p "$BASE/posts" "$BASE/proofs"

echo "=== CYBRA FINAL REVIEW ==="

find native_tokens mainnet pmz proofs posts site -type f 2>/dev/null -exec sha256sum {} \; > proofs/final_review_hashes.txt

cat > posts/cybra_final_status.md <<MD
# CYBRA Final Status

## Готово
- Native token structure
- Genesis
- Pools
- PMZ historical metadata
- Mainnet package
- PNG/SVG metadata support
- Proof hashes
- AI Parliament executor
- GitHub/Codespaces sync architecture

## Основні файли
- native_tokens/CYBRA/metadata/token.json
- native_tokens/CYBRA/pools/pools.json
- pmz/pmz_manifest.json
- mainnet/CYBRA/metadata/token.json
- proofs/final_review_hashes.txt

## Статус
CYBRA ecosystem package prepared.
MD

git add proofs posts native_tokens mainnet pmz site 2>/dev/null || true
git commit -m "CYBRA final review package" || true

echo "✅ Final review created"
echo "Post: posts/cybra_final_status.md"
echo "Proof: proofs/final_review_hashes.txt"
