#!/data/data/com.termux/files/usr/bin/bash
set -e

mkdir -p docs/assets feeds posts proofs

MINT=$(grep -RhoE '[1-9A-HJ-NP-Za-km-z]{32,44}' posts token/registry proofs 2>/dev/null | head -1 || echo "pending")

cat > feeds/token_dashboard.json <<JSON
{
  "project": "CYBRA",
  "token": "CYBRA",
  "network": "Solana Devnet",
  "mint_address": "$MINT",
  "wallet": "Phantom-ready",
  "mainnet": "LOCKED",
  "double_sha": "enabled",
  "watchdog": "enabled",
  "autoheal": "enabled",
  "autofix": "enabled"
}
JSON

cat > docs/index.html <<'HTML'
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>CYBRA Token Dashboard</title>
<style>
body{background:#050510;color:#fff;font-family:Arial;padding:40px}
.card{border:1px solid #333;border-radius:16px;padding:20px;margin:12px 0;background:#111827}
code{color:#7dd3fc}
</style>
</head>
<body>
<h1>CYBRA Token Dashboard</h1>
<div class="card">
<p><b>Token:</b> CYBRA</p>
<p><b>Network:</b> Solana Devnet</p>
<p><b>Mint:</b> <code id="mint">loading...</code></p>
<p><b>Wallet:</b> Phantom-ready</p>
<p><b>Mainnet:</b> LOCKED</p>
</div>
<div class="card">
<p>Watchdog: enabled</p>
<p>AutoHeal: enabled</p>
<p>AutoFix: enabled</p>
<p>Double-SHA Backend: enabled</p>
</div>
<script>
fetch('./../feeds/token_dashboard.json').then(r=>r.json()).then(d=>{
 document.getElementById('mint').textContent=d.mint_address || 'pending';
}).catch(()=>{document.getElementById('mint').textContent='pending';});
</script>
</body>
</html>
HTML

touch docs/.nojekyll

cat > posts/token_dashboard_status.md <<MD
# CYBRA Token Dashboard

Status: created

Mint:
$MINT

Site:
docs/index.html

Feed:
feeds/token_dashboard.json
MD

sha256sum docs/index.html feeds/token_dashboard.json posts/token_dashboard_status.md > proofs/token_dashboard.sha256

echo "✅ CYBRA token dashboard created"
