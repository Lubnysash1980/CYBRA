#!/data/data/com.termux/files/usr/bin/bash
set -e

mkdir -p token/deploy/solana_devnet posts proofs remote_queue

cat > token/deploy/solana_devnet/README_NEXT.md <<'MD'
# CYBRA Coin Next Step

Goal:
Deploy CYBRA token on Solana Devnet.

Required:
- solana CLI
- spl-token CLI
- devnet wallet with SOL faucet
- owner approval

Expected output:
- mint address
- token account
- metadata update
- proof hash
MD

cat > remote_queue/cybra_coin_devnet_deploy.task <<'TASK'
cd /workspaces/CYBRA 2>/dev/null || cd ~/CYBRA
solana config set --url devnet
solana --version
spl-token --version
bash token/deploy/solana_devnet/deploy_cybra_spl_devnet.sh
TASK

cat > posts/cybra_coin_next_step_status.md <<'MD'
# CYBRA Coin Next Step

Status: queued_for_codespaces_devnet

Next:
- run task in Codespaces
- get mint address
- write mint to token/coin/cybra_metadata.json
- verify wallet visibility
MD

sha256sum token/deploy/solana_devnet/README_NEXT.md remote_queue/cybra_coin_devnet_deploy.task posts/cybra_coin_next_step_status.md > proofs/cybra_coin_next_step.sha256

echo "✅ CYBRA coin next step prepared"
