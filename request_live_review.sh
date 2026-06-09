#!/usr/bin/env bash
set -e

TASK_ID="LIVE-ENABLE-REQUEST-$(date +%Y%m%d_%H%M%S)"

cat > "data/cybra_finance/it_department/tasks/$TASK_ID.json" <<EOF
{
  "task_id": "$TASK_ID",
  "type": "LIVE_ENABLE_REQUEST",
  "status": "PENDING_IT_PARLIAMENT_AUDIT",
  "request": "Запит на розгляд можливості ввімкнення live-ордерів",
  "current_gate": "REQUESTED_AUDIT_AND_OWNER_APPROVAL_REQUIRED",
  "required_approvals": [
    "IT audit",
    "CyberParliament review", 
    "Finance/Risk audit",
    "OWNER final approval"
  ],
  "live_orders_enabled": false,
  "recommendation": "Спочатку завершити всі 7 кроків з live_gate_final_checkpoint.json",
  "created_by": "Termux"
}
EOF

cp "data/cybra_finance/it_department/tasks/$TASK_ID.json" "parliament/inbox/"

echo "✅ LIVE-ENABLE REQUEST створено"
echo "📋 Task: $TASK_ID"
echo "🔴 Live досі вимкнено"
echo ""
echo "Перевірка:"
cat "data/cybra_finance/it_department/tasks/$TASK_ID.json" | jq .
