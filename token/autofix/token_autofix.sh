#!/data/data/com.termux/files/usr/bin/bash
set -e

cd "$HOME/CYBRA"

mkdir -p token/assets token/coin token/deploy/solana_devnet posts proofs

[ -f token/coin/cybra_metadata.json ] || cat > token/coin/cybra_metadata
cat >> cybra_chain_environment_autofix.sh <<'EOF'
.json <<'JSON'
{
  "name": "CYBRA Coin",
  "symbol": "CYBRA",
  "description": "CYBRA SPL-ready coin metadata. Devnet first. Mainnet only after owner approval.",
  "image": "token/assets/cybra.png",
  "chain": "solana_devnet_first",
  "decimals": 9,
  "status": "wallet_visible_prepare"
}
JSON

if [ ! -s token/assets/cybra.png ]; then
  printf 'CYBRA PNG PLACEHOLDER\n' > token/assets/cybra.png
fi

[ -f token/deploy/solana_devnet/deploy_cybra_spl_devnet.sh ] || cat > token/deploy/solana_devnet/deploy_cybra_spl_devnet.sh <<'SH'
#!/data/data/com.termux/files/usr/bin/bash
set -e
echo "CYBRA Devnet deploy placeholder"
echo "Requires: solana CLI + spl-token"
echo "Devnet only. No private keys in logs."
SH

chmod +x token/deploy/solana_devnet/deploy_cybra_spl_devnet.sh

echo "✅ token autofix completed"
