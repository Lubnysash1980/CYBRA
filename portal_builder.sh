#!/data/data/com.termux/files/usr/bin/bash
set -e

mkdir -p web/pages web/assets site posts proofs

cat > web/index.html <<'HTML'
<!doctype html>
<html lang="uk">
<head>
  <meta charset="utf-8">
  <title>CYBRA Portal</title>
  <link rel="stylesheet" href="assets/style.css">
</head>
<body>
  <h1>CYBRA Web3 Portal</h1>
  <nav>
    <a href="pages/token.html">Token</a>
    <a href="pages/proofs.html">Proofs</a>
    <a href="pages/watchdog.html">Watchdog</a>
    <a href="pages/dao.html">DAO</a>
    <a href="pages/legal.html">Legal</a>
  </nav>
  <section>
    <p>Status: active</p>
    <p>No secrets on frontend.</p>
  </section>
</body>
</html>
HTML

for P in token proofs watchdog dao legal; do
cat > web/pages/$P.html <<HTML
<!doctype html>
<html lang="uk">
<head>
  <meta charset="utf-8">
  <title>CYBRA $P</title>
  <link rel="stylesheet" href="../assets/style.css">
</head>
<body>
  <h1>CYBRA $P</h1>
  <a href="../index.html">Back</a>
  <p>Status page for $P.</p>
</body>
</html>
HTML
done

cat > web/assets/style.css <<'CSS'
body { background:#070711; color:#e8f0ff; font-family:Arial,sans-serif; padding:32px; }
a { color:#64d8ff; margin-right:16px; }
section { margin-top:24px; padding:16px; border:1px solid #333; border-radius:12px; }
CSS

cat > web/assets/app.js <<'JS'
console.log("CYBRA portal loaded");
JS

cat > site/CNAME.example <<'TXT'
example.com
TXT

cat > posts/portal_web3_status.md <<'MD'
# CYBRA Portal Web3 Status

Status: built

Features:
- GitHub Pages ready
- Cloudflare ready
- custom domain placeholder
- wallet connect placeholder
- watchdog UI placeholder
- proofs explorer placeholder
- DAO voting UI placeholder
- no secrets on frontend
MD

find web site posts/portal_web3_status.md -type f -exec sha256sum {} \; > proofs/portal_web3.sha256

git add web site posts/portal_web3_status.md proofs/portal_web3.sha256 portal_builder.sh
git commit -m "build CYBRA Web3 portal" || true

echo "✅ CYBRA portal built"
