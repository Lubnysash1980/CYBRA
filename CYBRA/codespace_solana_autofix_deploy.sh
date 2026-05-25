#!/usr/bin/env bash
set -e

echo "======================================"
echo "CYBRA SOLANA AUTOFIX DEPLOY"
echo "======================================"

NETWORK="${1:-devnet}"
OWNER_WALLET="${2:-FesrWxqM67HrjFqsCoCHsUkRocZZBgWeg4P3T4b9FD9Y}"
SUPPLY="${3:-1000000}"
DECIMALS="${4:-9}"

BASE="$(pwd)"
mkdir -p proofs solana keys logs token_files

if [ "$NETWORK" = "mainnet" ]; then
  RPC_URL="https://api.mainnet-beta.solana.com"
  PROOF_FILE="proofs/solana_mainnet_token_proof.json"
else
  RPC_URL="https://api.devnet.solana.com"
  PROOF_FILE="proofs/solana_devnet_token_proof.json"
fi

echo "[1] Install base packages"
sudo apt-get update -y
sudo apt-get install -y curl build-essential pkg-config libssl-dev git jq

echo "[2] Install Rust if missing"
if ! command -v cargo >/dev/null 2>&1; then
  curl https://sh.rustup.rs -sSf | sh -s -- -y
  source "$HOME/.cargo/env"
else
  source "$HOME/.cargo/env" 2>/dev/null || true
fi

echo "[3] Install Solana CLI if missing"
if ! command -v solana >/dev/null 2>&1; then
  sh -c "$(curl -sSfL https://release.anza.xyz/stable/install)"
  export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
fi

export PATH="$HOME/.local/share/solana/install/active_release/bin:$HOME/.cargo/bin:$PATH"

echo 'export PATH="$HOME/.local/share/solana/install/active_release/bin:$HOME/.cargo/bin:$PATH"' >> ~/.bashrc

echo "[4] Install spl-token if missing"
if ! command -v spl-token >/dev/null 2>&1; then
  cargo install spl-token-cli --locked || cargo install spl-token-cli
fi

echo "[5] Configure network: $NETWORK"
solana config set --url "$RPC_URL"

echo "[6] Create keypair if missing"
KEYPAIR="$HOME/.config/solana/id.json"
mkdir -p "$HOME/.config/solana"

if [ ! -f "$KEYPAIR" ]; then
  solana-keygen new --no-bip39-passphrase -o "$KEYPAIR"
fi

solana config set --keypair "$KEYPAIR"

DEPLOYER_ADDRESS="$(solana address)"
BALANCE="$(solana balance || true)"

echo "Deployer: $DEPLOYER_ADDRESS"
echo "Balance: $BALANCE"

if [ "$NETWORK" = "devnet" ]; then
  echo "[7] Devnet airdrop if needed"
  solana airdrop 2 || true
else
  echo "[7] Mainnet mode"
  echo "Mainnet requires real SOL on deployer address:"
  echo "$DEPLOYER_ADDRESS"
  echo "If balance is 0, send SOL first, then rerun this script."
fi

echo "[8] Create SPL token"
TOKEN_ADDRESS="$(spl-token create-token --decimals "$DECIMALS" | awk '/Creating token/ {print $3}')"

if [ -z "$TOKEN_ADDRESS" ]; then
  echo "Could not parse token address"
  exit 1
fi

echo "$TOKEN_ADDRESS" > token_files/token_address.txt

echo "[9] Create token account for deployer"
DEPLOYER_TOKEN_ACCOUNT="$(spl-token create-account "$TOKEN_ADDRESS" | awk '/Creating account/ {print $3}')"
echo "$DEPLOYER_TOKEN_ACCOUNT" > token_files/deployer_token_account.txt

echo "[10] Mint supply to deployer token account"
spl-token mint "$TOKEN_ADDRESS" "$SUPPLY"

echo "[11] Try transfer to owner wallet"
echo "This requires recipient associated token account support."
set +e
TRANSFER_OUTPUT="$(spl-token transfer "$TOKEN_ADDRESS" "$SUPPLY" "$OWNER_WALLET" --fund-recipient 2>&1)"
TRANSFER_CODE=$?
set -e

echo "$TRANSFER_OUTPUT" | tee logs/transfer_output.log

if [ "$TRANSFER_CODE" -ne 0 ]; then
  echo "Transfer did not complete automatically."
  echo "Tokens remain on deployer token account."
  TRANSFER_STATUS="manual_review_required"
else
  TRANSFER_STATUS="transferred_to_owner_wallet"
fi

echo "[12] Save token accounts"
spl-token accounts > token_files/spl_token_accounts.txt || true

echo "[13] Create proof file"
cat > "$PROOF_FILE" <<JSON
{
  "system": "CYBRA",
  "network": "$NETWORK",
  "rpc_url": "$RPC_URL",
  "owner_wallet": "$OWNER_WALLET",
  "deployer_address": "$DEPLOYER_ADDRESS",
  "token_address": "$TOKEN_ADDRESS",
  "deployer_token_account": "$DEPLOYER_TOKEN_ACCOUNT",
  "supply": "$SUPPLY",
  "decimals": "$DECIMALS",
  "transfer_status": "$TRANSFER_STATUS",
  "proof_time": "$(date -Iseconds)",
  "files": {
    "token_address": "token_files/token_address.txt",
    "deployer_token_account": "token_files/deployer_token_account.txt",
    "accounts": "token_files/spl_token_accounts.txt",
    "transfer_log": "logs/transfer_output.log"
  }
}
JSON

echo "[14] Git proof snapshot"
git add proofs token_files logs codespace_solana_autofix_deploy.sh 2>/dev/null || true
git commit -m "CYBRA Solana $NETWORK token proof" 2>/dev/null || true

echo "======================================"
echo "DONE"
echo "Network: $NETWORK"
echo "Token: $TOKEN_ADDRESS"
echo "Owner wallet: $OWNER_WALLET"
echo "Proof: $PROOF_FILE"
echo "Transfer status: $TRANSFER_STATUS"
echo "======================================"
