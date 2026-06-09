#!/usr/bin/env bash
set -e

echo "▶ LIVE GATE FINAL CHECKPOINT"

# live status check
cyberbot status | grep -E "live_order_gate|live_orders_enabled|real_trading_now|allow_live_orders|manual_OWNER_approval_required"

# live checkpoint data
cat > data/cyberbot/actions/live_gate_final_checkpoint.json <<'EOF'
{
  "status": "LIVE_GATE_FINAL_CHECKPOINT",
  "live_orders_enabled": false,
  "real_trading_now": false,
  "allow_live_orders": false,
  "live_order_gate": "REQUESTED_AUDIT_AND_OWNER_APPROVAL_REQUIRED",
  "who_can_enable_live_orders": "OWNER_ONLY_AFTER_IT_PARLIAMENT_FINANCE_AUDIT",
  "required_before_live": [
    "IT audit",
    "CyberParliament review",
    "Finance/Risk audit",
    "API permissions check",
    "withdrawals disabled on exchange API",
    "paper/testnet logs checked",
    "separate manual OWNER approval"
  ]
}
EOF

# live task
TASK_ID="LIVE-GATE-$(date +%Y%m%d_%H%M%S)"
mkdir -p data/cybra_finance/it_department/tasks parliament/inbox

cat > "data/cybra_finance/it_department/tasks/$TASK_ID.json" <<EOF
{
  "task_id": "$TASK_ID",
  "status": "LIVE_GATE_TASK",
  "title": "LIVE: Cyberbot gate checkpoint",
  "body": "live_orders_enabled=false, real_trading_now=false. Audit required before any live enable.",
  "routes": {
    "it_department": true,
    "cyber_parliament": true,
    "finance_audit": true
  }
}
EOF

cp "data/cybra_finance/it_department/tasks/$TASK_ID.json" "parliament/inbox/$TASK_ID.json"

# live redis push
for q in it_department parliament_inbox cybra:audit:finance; do
  redis-cli LPUSH "$q" "$(cat parliament/inbox/$TASK_ID.json)" 2>/dev/null || true
done

# live proofs
sha256sum \
  data/cyberbot/actions/live_gate_final_checkpoint.json \
  "data/cybra_finance/it_department/tasks/$TASK_ID.json" \
  "parliament/inbox/$TASK_ID.json" \
  > proofs/live_gate.sha256

sha256sum -c proofs/live_gate.sha256

# live git
git add -f \
  data/cyberbot/actions/live_gate_final_checkpoint.json \
  data/cybra_finance/it_department/tasks \
  parliament/inbox \
  proofs/live_gate.sha256

git commit -m "live: gate checkpoint — orders OFF" || echo "live: no changes"
git pull --rebase --autostash origin main 2>/dev/null || true
git push origin main 2>/dev/null || true

echo ""
echo "═══════════════════════════════"
echo "✅ LIVE GATE CHECKPOINT"
echo "🔴 LIVE ORDERS: OFF"
echo "📋 TASK: IT + PARLIAMENT + AUDIT"
echo "═══════════════════════════════"
