#!/bin/bash
TASK_ID="PREPARE-LIVE-$(date +%Y%m%d_%H%M%S)"
mkdir -p data/cybra_finance/it_department/tasks parliament/inbox

cat > "data/cybra_finance/it_department/tasks/$TASK_ID.json" <<EOF
{
  "task_id": "$TASK_ID",
  "title": "ПІДГОТУВАТИ БОТ ДЛЯ LIVE",
  "current": {"live_orders_enabled": false, "paper_trading": true},
  "required_approvals": ["IT", "CyberParliament", "FinanceAudit", "OWNER"],
  "risk_limits": {"max_position_usdt": 100, "max_daily_usdt": 1000},
  "status": "PENDING_AUDIT"
}
EOF
cp "data/cybra_finance/it_department/tasks/$TASK_ID.json" "parliament/inbox/"
echo "✅ TASK: $TASK_ID | 🔴 LIVE OFF | 📋 PENDING"
