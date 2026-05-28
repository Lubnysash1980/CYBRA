#!/data/data/com.termux/files/usr/bin/bash
set -e

BASE="$HOME/CYBRA"
mkdir -p "$BASE/pmz" "$BASE/proofs" "$BASE/posts"

cat > "$BASE/pmz/pmz_manifest.json" <<JSON
{
  "system": "CYBRA PMZ",
  "purpose": "historical metadata and proof registry",
  "sources": [
    "https://lubnysash1980.github.io/Alfapay/metadata.json",
    "native_tokens",
    "mainnet",
    "proofs",
    "posts",
    "site"
  ],
  "status": "created"
}
JSON

find "$BASE/native_tokens" "$BASE/mainnet" "$BASE/proofs" "$BASE/posts" "$BASE/site" -type f 2>/dev/null -exec sha256sum {} \; > "$BASE/pmz/proof_hashes.txt"

cat > "$BASE/pmz/history_index.json" <<JSON
{
  "history_layers": [
    "genesis",
    "metadata",
    "proofs",
    "ai_parliament_decisions",
    "status_posts"
  ],
  "proof_file": "pmz/proof_hashes.txt"
}
JSON

cat > "$BASE/posts/pmz_status.md" <<MD
# CYBRA PMZ Status

PMZ historical metadata registry created.

Files:
- pmz/pmz_manifest.json
- pmz/history_index.json
- pmz/proof_hashes.txt
MD

echo "✅ PMZ registry created"
