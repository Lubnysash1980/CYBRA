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
