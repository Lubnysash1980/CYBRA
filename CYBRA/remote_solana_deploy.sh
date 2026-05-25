#!/usr/bin/env bash
set -e

echo "=== CYBRA REMOTE SOLANA DEVNET DEPLOY ==="

OWNER_WALLET="${1:-GA9o4aB4sCcZhLG1bs3r9SEnKhj9WqXmvhfSJHdPSSqc}"
SUPPLY="${2:-1000000}"

echo "[1] Install Solana CLI"
sh -c "$(curl -sSfL https://release.anza.xyz/stable/install)"

export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"

echo "[2] Install SPL Token CLI"
cargo install spl-token-cli --locked

export PATH="$HOME/.cargo/bin:$PATH"

echo "[3] Devnet config"
solana config set --url https://api.devnet.solana.com

echo "[4] Create devnet keypair if missing"
mkdir -p ~/.config/solana
if [ ! -f ~/.config/solana/id.json ]; then
  solana-keygen new --no-bip39-passphrase -o ~/.config/solana/id.json
fi

solana config set --keypair ~/.config/solana/id.json

echo "[5] Airdrop"
solana airdrop 2 || true

echo "[6] Create token"
TOKEN=$(spl-token create-token | awk '/Creating token/ {print $3}')
echo "TOKEN=$TOKEN"

echo "[7] Create account"
ACCOUNT=$(spl-token create-account "$TOKEN" | awk '/Creating account/ {print $3}')
echo "ACCOUNT=$ACCOUNT"

echo "[8] Mint supply"
spl-token mint "$TOKEN" "$SUPPLY"

echo "[9] Balance"
spl-token accounts

mkdir -p proofs
cat > proofs/solana_devnet_token_proof.json <<JSON
{
  "network": "devnet",
  "owner_wallet_note": "$OWNER_WALLET",
  "token": "$TOKEN",
  "token_account": "$ACCOUNT",
  "supply": "$SUPPLY",
  "time": "$(date -Iseconds)"
}
JSON

git add proofs remote_solana_deploy.sh 2>/dev/null || true
git commit -m "add Solana devnet token proof" 2>/dev/null || true

echo "✅ DONE"
echo "TOKEN: $TOKEN"
echo "ACCOUNT: $ACCOUNT"
echo "Proof: proofs/solana_devnet_token_proof.json"
