#!/data/data/com.termux/files/usr/bin/bash
set -e

MODE="${1:-devnet}"
case "$MODE" in test|devnet|mainnet) ;; *) echo "Use: test|devnet|mainnet"; exit 1;; esac

mkdir -p token/runtime token/wallet token/registry token/devnet web docs posts proofs feeds

# RPC/API template — секрети НЕ комітити
cat > token/runtime/rpc.env.template <<'ENV'
SOLANA_RPC_URL=
HELIUS_API_KEY=
QUICKNODE_API_KEY=
PHANTOM_WALLET_ADDRESS=
OWNER_WALLET_ADDRESS=
ENV

[ -f token/runtime/rpc.env ] || cp token/runtime/rpc.env.template token/runtime/rpc.env

cat > token/wallet/wallet_visibility.json <<JSON
{
  "mode": "$MODE",
  "wallet": "phantom",
  "wallet_visible": false,
  "requires": ["mint_address", "metadata_uri", "logo_uri", "owner_wallet"],
  "status": "waiting_devnet_mint"
}
JSON

cat > token/registry/token_registry.json <<JSON
{
  "symbol": "CYBRA",
  "name": "CYBRA Coin",
  "mode": "$MODE",
  "chain": "solana",
  "network": "$MODE",
  "mint_address": "",
  "metadata_uri": "",
  "logo_uri": "token/assets/cybra.png",
  "decimals": 9,
  "status": "preflight_ready"
}
JSON

cat > token/devnet/devnet_preflight_check.sh <<'BASH'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

echo "=== CYBRA DEVNET PREFLIGHT ==="
test -f token/coin/cybra_metadata.json && echo "metadata OK" || echo "metadata MISSING"
test -s token/assets/cybra.png && echo "logo OK" || echo "logo MISSING"
test -f token/runtime/rpc.env && echo "rpc.env OK" || echo "rpc.env MISSING"
test -f token/wallet/wallet_visibility.json && echo "wallet visibility OK" || echo "wallet visibility MISSING"
test -f token/registry/token_registry.json && echo "token registry OK" || echo "token registry MISSING"
command -v solana >/dev/null 2>&1 && solana --version || echo "NO_SOLANA_CLI"
command -v spl-token >/dev/null 2>&1 && spl-token --version || echo "NO_SPL_TOKEN_CLI"
BASH
chmod +x token/devnet/devnet_preflight_check.sh

# сайт, якщо не створився
mkdir -p docs
cat > docs/index.html <<'HTML'
<!doctype html>
<html>
<head><meta charset="utf-8"><title>CYBRA</title></head>
<body style="font-family:Arial;background:#050510;color:white;padding:40px">
<h1>CYBRA Portal</h1>
<p>Status: launch preflight active.</p>
<ul>
<li>Token: CYBRA</li>
<li>Network: test/devnet/mainnet switcher</li>
<li>Wallet: Phantom-ready</li>
<li>Mode: controlled by CYBRA preflight</li>
</ul>
</body>
</html>
HTML
touch docs/.nojekyll

cat > feeds/launch_preflight_status.json <<JSON
{
  "mode": "$MODE",
  "token_registry": true,
  "wallet_visibility": true,
  "rpc_template": true,
  "devnet_preflight": true,
  "site_docs": true,
  "phantom_ready_placeholder": true,
  "api_key_required": true,
  "status": "preflight_ready"
}
JSON

cat > posts/cybra_launch_preflight_status.md <<MD
# CYBRA Launch Preflight AutoFix

Mode: $MODE

Created:
- token/runtime/rpc.env.template
- token/runtime/rpc.env
- token/wallet/wallet_visibility.json
- token/registry/token_registry.json
- token/devnet/devnet_preflight_check.sh
- docs/index.html
- feeds/launch_preflight_status.json

Status:
preflight_ready

Next:
1. Insert API/RPC key into token/runtime/rpc.env
2. Insert Phantom/owner wallet address
3. Run devnet preflight
4. Deploy devnet mint
5. Write mint address into token registry
MD

sha256sum \
 token/runtime/rpc.env.template \
 token/wallet/wallet_visibility.json \
 token/registry/token_registry.json \
 token/devnet/devnet_preflight_check.sh \
 docs/index.html \
 feeds/launch_preflight_status.json \
 posts/cybra_launch_preflight_status.md \
 > proofs/cybra_launch_preflight.sha256

echo "✅ CYBRA launch preflight/autofix ready: $MODE"
