#!/data/data/com.termux/files/usr/bin/bash
set -e

BASE="$HOME/CYBRA"

mkdir -p "$BASE/docs" "$BASE/proofs" "$BASE/posts"

echo "=== CYBRA PAGES AUTOFIX ==="

# required files
[ -f "$BASE/native_tokens/CYBRA/metadata/token.json" ] || echo '{"status":"missing native metadata"}' > "$BASE/docs/native_token.json"
[ -f "$BASE/mainnet/CYBRA/metadata/token.json" ] || echo '{"status":"missing mainnet metadata"}' > "$BASE/docs/mainnet_token.json"
[ -f "$BASE/pmz/pmz_manifest.json" ] || echo '{"status":"missing pmz"}' > "$BASE/docs/pmz_manifest.json"

cp "$BASE/native_tokens/CYBRA/metadata/token.json" "$BASE/docs/native_token.json" 2>/dev/null || true
cp "$BASE/mainnet/CYBRA/metadata/token.json" "$BASE/docs/mainnet_token.json" 2>/dev/null || true
cp "$BASE/pmz/pmz_manifest.json" "$BASE/docs/pmz_manifest.json" 2>/dev/null || true

cat > "$BASE/docs/index.html" <<'HTML'
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>CYBRA Native Coin</title>
</head>
<body>
  <h1>CYBRA Native Coin</h1>
  <p>Native chain, no mint account.</p>
  <p>Owner wallet: <code>FesrWxqM67HrjFqsCoCHsUkRocZZBgWeg4P3T4b9FD9Y</code></p>
  <p>Supply: 1000000</p>

  <h2>Metadata</h2>
  <ul>
    <li><a href="native_token.json">Native Token Metadata</a></li>
    <li><a href="mainnet_token.json">Mainnet Package Metadata</a></li>
    <li><a href="pmz_manifest.json">PMZ Manifest</a></li>
  </ul>
</body>
</html>
HTML

find "$BASE/docs" -type f -exec sha256sum {} \; > "$BASE/proofs/pages_hashes.txt"

cat > "$BASE/posts/pages_autofix_status.md" <<MD
# CYBRA Pages Autofix

GitHub Pages package checked and repaired.

Files:
- docs/index.html
- docs/native_token.json
- docs/mainnet_token.json
- docs/pmz_manifest.json
- proofs/pages_hashes.txt
MD

git add docs proofs posts
git commit -m "autofix CYBRA GitHub Pages package" || true

echo "✅ Pages autofix done"
echo "Now run: git push"
