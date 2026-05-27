#!/data/data/com.termux/files/usr/bin/bash
set -e

mkdir -p posts proofs token/deployment_plan

cat > token/deployment_plan/solana_devnet_plan.md <<'MD'
# CYBRA Wallet Visible Token Plan

## Target
Solana Devnet first

## Required steps

1. Install Solana CLI
2. Create wallet keypair
3. Create SPL token mint
4. Create metadata URI
5. Upload logo + metadata
6. Create associated token account
7. Mint initial supply
8. Verify in wallet
9. Test transfers
10. Audit proofs
11. Owner approval before mainnet

## Security
- no mainnet deployment without owner approval
- no fake balances
- audit required
- proof chain required
MD

cat > posts/wallet_visible_token_plan.md <<'MD'
# CYBRA Wallet Visible Token Deployment

Status: planning_ready

Chain:
Solana Devnet

Goal:
Create real wallet-visible SPL token.

Outputs:
- mint address
- token account
- metadata URI
- wallet visibility
- proof audit

Mainnet:
NOT enabled without owner approval.
MD

sha256sum \
  token/deployment_plan/solana_devnet_plan.md \
  posts/wallet_visible_token_plan.md \
  > proofs/wallet_visible_token_plan.sha256

git add token/deployment_plan posts/wallet_visible_token_plan.md proofs/wallet_visible_token_plan.sha256 wallet_visible_token_plan.sh
git commit -m "add wallet visible token deployment plan" || true

echo "✅ Wallet visible token plan created"
