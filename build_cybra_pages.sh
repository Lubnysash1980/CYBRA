#!/data/data/com.termux/files/usr/bin/bash
set -e

mkdir -p docs

cat > docs/index.html <<'HTML'
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>CYBRA Native Coin</title>
</head>
<body>
  <h1>CYBRA Native Coin</h1>
  <p>Model: native chain, no mint account</p>
  <p>Owner wallet: FesrWxqM67HrjFqsCoCHsUkRocZZBgWeg4P3T4b9FD9Y</p>
  <p>Supply: 1000000</p>

  <h2>Files</h2>
  <ul>
    <li><a href="../native_tokens/CYBRA/metadata/token.json">Native metadata</a></li>
    <li><a href="../mainnet/CYBRA/metadata/token.json">Mainnet metadata</a></li>
    <li><a href="../pmz/pmz_manifest.json">PMZ manifest</a></li>
  </ul>
</body>
</html>
HTML

cp native_tokens/CYBRA/metadata/token.json docs/native_token.json 2>/dev/null || true
cp mainnet/CYBRA/metadata/token.json docs/mainnet_token.json 2>/dev/null || true
cp pmz/pmz_manifest.json docs/pmz_manifest.json 2>/dev/null || true

find docs -type f -exec sha256sum {} \; > proofs/github_pages_hashes.txt

git add docs proofs
git commit -m "add CYBRA GitHub Pages site" || true

echo "✅ GitHub Pages files created in docs/"
