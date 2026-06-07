#!/usr/bin/env bash
set +e
cd "$HOME/CYBRA" || exit 1

echo "=== CREATE COIN APPROVAL TASK ==="

mkdir -p \
  data/cybra_coin/approval/tasks \
  data/cybra_coin/approval/reports \
  data/cybra_coin/approval/checklists \
  data/cybra_mgs/tasks \
  data/cybra_oracle/tasks \
  data/cybra_finance/it_department/tasks \
  parliament/committees/coin_approval_committee/tasks \
  posts feeds proofs logs/coin runtime/redis

if command -v redis-cli >/dev/null 2>&1; then
  if ! redis-cli ping >/dev/null 2>&1; then
    redis-server --daemonize yes \
      --bind 127.0.0.1 \
      --port 6379 \
      --dir "$HOME/CYBRA/runtime/redis" \
      --save "" \
      --appendonly no >/dev/null 2>&1 || true
    sleep 1
  fi
fi

TS="$(date +%Y%m%d_%H%M%S)"
TASK_ID="COIN-APPROVAL-${TS}"

cat > "data/cybra_coin/approval/tasks/${TASK_ID}.json" <<EOF
{
  "task_id": "$TASK_ID",
  "timestamp": "$(date -Iseconds 2>/dev/null || date)",
  "department": "CYBRA_COIN_APPROVAL_DEPARTMENT",
  "title": "Доробити монету до approval",
  "priority": "HIGH",
  "status": "QUEUED_FOR_APPROVAL_PREPARATION",
  "objective": "Підготувати монету CYBRA/KIBRA/AF до повного approval-пакета: технічна перевірка, tokenomics, metadata, governance, audit, legal/finance gate, OWNER approval, Cyber Parliament approval.",
  "coin_scope": {
    "coin_family": "CYBRA_KIBRA_AF",
    "network_modes": ["sandbox", "testnet", "mainnet_ready_gate"],
    "mainnet_live_now": false,
    "approval_required_before_live": true
  },
  "routes": [
    "coin_approval_committee",
    "finance_it_department",
    "cybra_mgs_all",
    "cybra_oracle_tasks",
    "ai_block_inbox",
    "it_department",
    "parliament_inbox",
    "cybra_finance_evolution"
  ],
  "committees": [
    "coin_approval_committee",
    "finance_risk_committee",
    "finance_it_committee",
    "mgs_integration",
    "mgs_analytics",
    "cyber_parliament_approval",
    "oracle_runner_committee",
    "codespace_worker_committee"
  ],
  "required_work": [
    "перевірити mint / metadata / decimals / supply",
    "перевірити GitHub Pages metadata.json і logo.png",
    "створити approval checklist",
    "створити tokenomics draft",
    "створити risk disclosure draft",
    "створити OWNER approval ticket",
    "створити Cyber Parliament vote draft",
    "створити audit/proof checklist",
    "створити mainnet readiness gate",
    "перевірити freeze/update authority policy",
    "перевірити multisig/update authority",
    "перевірити Solscan/CMC listing readiness",
    "перевірити finance live gate перед будь-якими реальними платежами"
  ],
  "deliverables": [
    "data/cybra_coin/approval/checklists/coin_approval_checklist.md",
    "data/cybra_coin/approval/checklists/tokenomics_approval_draft.md",
    "data/cybra_coin/approval/checklists/owner_approval_ticket.md",
    "data/cybra_coin/approval/checklists/cyber_parliament_vote_draft.md",
    "data/cybra_coin/approval/checklists/mainnet_readiness_gate.md",
    "posts/cybra_coin_approval_task.md",
    "feeds/cybra_coin_approval_task.json",
    "proofs/cybra_coin_approval_task.sha256"
  ],
  "safety": {
    "real_payment_now": false,
    "real_trading_now": false,
    "live_orders_enabled": false,
    "automatic_external_tx": false,
    "automatic_withdrawals": false,
    "automatic_SWIFT": false,
    "automatic_mainnet_mint": false,
    "automatic_liquidity_creation": false,
    "automatic_listing_submission": false,
    "bank_live_mode": false,
    "psp_live_mode": false,
    "manual_OWNER_approval_required": true,
    "cyber_parliament_approval_required": true,
    "mainnet_deploy_allowed": false,
    "approval_gate_required": true,
    "do_not_store_secrets_in_git": true
  }
}
EOF

cp "data/cybra_coin/approval/tasks/${TASK_ID}.json" "data/cybra_mgs/tasks/${TASK_ID}.json"
cp "data/cybra_coin/approval/tasks/${TASK_ID}.json" "data/cybra_oracle/tasks/${TASK_ID}.json"
cp "data/cybra_coin/approval/tasks/${TASK_ID}.json" "data/cybra_finance/it_department/tasks/${TASK_ID}.json"
cp "data/cybra_coin/approval/tasks/${TASK_ID}.json" "parliament/committees/coin_approval_committee/tasks/${TASK_ID}.json"

cat > data/cybra_coin/approval/checklists/coin_approval_checklist.md <<'EOF'
# CYBRA/KIBRA Coin Approval Checklist

Status: QUEUED_FOR_REVIEW

## Technical
- Mint address verified
- Decimals verified
- Supply verified
- Metadata URI verified
- Logo URI verified
- Update authority policy verified
- Freeze authority policy verified
- Multisig policy checked

## Finance / Legal
- No real payments enabled
- No withdrawals enabled
- No SWIFT enabled
- No live trading enabled
- Finance live gate required
- OWNER approval required
- Cyber Parliament approval required

## Public readiness
- Solscan label readiness
- CoinMarketCap listing readiness
- GitHub Pages metadata readiness
- Tokenomics draft prepared
- Risk disclosure prepared
EOF

cat > data/cybra_coin/approval/checklists/tokenomics_approval_draft.md <<'EOF'
# Tokenomics Approval Draft

Status: DRAFT

Coin family: CYBRA / KIBRA / AF

Approval requirements:
- Define internal supply
- Define public supply, if any
- Define owner/platform allocation
- Define miners/community allocation
- Define reserve/risk pool
- Define liquidity policy
- Define no-market-manipulation rule
- Define price only by real market proof
EOF

cat > data/cybra_coin/approval/checklists/owner_approval_ticket.md <<EOF
# OWNER Approval Ticket

Task ID: $TASK_ID

Status: WAITING_OWNER_REVIEW

Approval requested for:
- Complete coin approval package
- Technical audit preparation
- Tokenomics draft
- Parliament vote draft
- Mainnet readiness gate

Not approved automatically:
- Mainnet deployment
- Real payments
- Withdrawals
- SWIFT
- Live trading
- Liquidity creation
EOF

cat > data/cybra_coin/approval/checklists/cyber_parliament_vote_draft.md <<EOF
# Cyber Parliament Vote Draft

Task ID: $TASK_ID

Vote subject:
Approve preparation of CYBRA/KIBRA/AF coin approval package.

Vote does not enable:
- real_payment_now
- automatic_external_tx
- live_orders_enabled
- automatic_mainnet_mint
- automatic_liquidity_creation

Required:
- OWNER approval
- audit proof
- finance gate
- mainnet readiness gate
EOF

cat > data/cybra_coin/approval/checklists/mainnet_readiness_gate.md <<'EOF'
# Mainnet Readiness Gate

Status: LOCKED

Mainnet allowed: false

Required before unlock:
- OWNER approval
- Cyber Parliament approval
- audit/proof report
- metadata verification
- authority verification
- finance live gate review
- legal/PSP/bank status review, if payments are connected
EOF

cat > feeds/cybra_coin_approval_task.json <<EOF
{
  "task_id": "$TASK_ID",
  "status": "QUEUED_FOR_APPROVAL_PREPARATION",
  "title": "Доробити монету до approval",
  "mainnet_deploy_allowed": false,
  "manual_OWNER_approval_required": true,
  "cyber_parliament_approval_required": true,
  "automatic_external_tx": false,
  "automatic_liquidity_creation": false
}
EOF

cat > posts/cybra_coin_approval_task.md <<EOF
# CYBRA Coin Approval Task

Task ID: \`$TASK_ID\`

Status: **QUEUED_FOR_APPROVAL_PREPARATION**

## Завдання

Доробити монету до approval:

1. Technical verification.
2. Metadata verification.
3. Tokenomics draft.
4. OWNER approval ticket.
5. Cyber Parliament vote draft.
6. Mainnet readiness gate.
7. Audit/proof checklist.
8. Solscan/CMC readiness.
9. Finance live gate review.

## Safety

- real_payment_now: false
- real_trading_now: false
- automatic_external_tx: false
- automatic_withdrawals: false
- automatic_SWIFT: false
- automatic_mainnet_mint: false
- automatic_liquidity_creation: false
- manual_OWNER_approval_required: true
- cyber_parliament_approval_required: true
- mainnet_deploy_allowed: false
EOF

for q in cybra_mgs_all cybra_oracle_tasks ai_block_inbox it_department parliament_inbox cybra_finance_evolution cybra_coin_approval; do
  if command -v redis-cli >/dev/null 2>&1; then
    redis-cli LPUSH "$q" "$(cat data/cybra_coin/approval/tasks/${TASK_ID}.json)" >/dev/null 2>&1 || true
  fi
done

sha256sum \
  "data/cybra_coin/approval/tasks/${TASK_ID}.json" \
  "data/cybra_mgs/tasks/${TASK_ID}.json" \
  "data/cybra_oracle/tasks/${TASK_ID}.json" \
  "data/cybra_finance/it_department/tasks/${TASK_ID}.json" \
  "parliament/committees/coin_approval_committee/tasks/${TASK_ID}.json" \
  data/cybra_coin/approval/checklists/coin_approval_checklist.md \
  data/cybra_coin/approval/checklists/tokenomics_approval_draft.md \
  data/cybra_coin/approval/checklists/owner_approval_ticket.md \
  data/cybra_coin/approval/checklists/cyber_parliament_vote_draft.md \
  data/cybra_coin/approval/checklists/mainnet_readiness_gate.md \
  posts/cybra_coin_approval_task.md \
  feeds/cybra_coin_approval_task.json \
  > proofs/cybra_coin_approval_task.sha256

echo
echo "✅ COIN APPROVAL TASK CREATED"
echo "TASK_ID=$TASK_ID"
echo
echo "Check:"
echo "  cat posts/cybra_coin_approval_task.md"
echo "  sha256sum -c proofs/cybra_coin_approval_task.sha256"
