#!/data/data/com.termux/files/usr/bin/bash
set -e

mkdir -p token/coin token/assets token/deploy/solana_devnet posts proofs

cat > token/coin/cybra_metadata.json <<'JSON'
{
  "name": "CYBRA Coin",
  "symbol": "CYBRA",
  "description": "CYBRA native / SPL-ready coin metadata. Devnet first. Mainnet only after owner approval.",
  "image": "token/assets/cybra.png",
  "chain": "solana_devnet_first",
  "decimals": 9,
  "status": "wallet_visible_prepare"
}
JSON

[ -f token/assets/cybra.png ] || touch token/assets/cybra.png

cat > token/deploy/solana_devnet/deploy_cybra_spl_devnet.sh <<'BASH'
#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "CYBRA SPL Devnet deploy script"
echo "Requires: solana cli + spl-token"
echo "Devnet only. No private keys in logs."

solana config set --url devnet
spl-token create-token
BASH

chmod +x token/deploy/solana_devnet/deploy_cybra_spl_devnet.sh

cat > posts/cybra_coin_completion_status.md <<'MD'
# CYBRA Coin Completion

Status: prepared

Created:
- token/coin/cybra_metadata.json
- token/assets/cybra.png placeholder/check
- token/deploy/solana_devnet/deploy_cybra_spl_devnet.sh

Rules:
- devnet first
- no private keys in logs
- no fake balances
- mainnet only after owner approval
- proof required
MD

sha256sum \
  token/coin/cybra_metadata.json \
  token/assets/cybra.png \
  token/deploy/solana_devnet/deploy_cybra_spl_devnet.sh \
  posts/cybra_coin_completion_status.md \
  > proofs/cybra_coin_completion.sha256

echo "✅ CYBRA coin completion prepared"
