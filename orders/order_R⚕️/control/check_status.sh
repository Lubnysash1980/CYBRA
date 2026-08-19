#!/bin/bash
ORDER="R⚕️"
BASE="$HOME/CYBRA/orders/order_${ORDER}"
echo "=== СТАТУС ЗАМОВЛЕННЯ $ORDER ==="
echo "Час перевірки: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""
if [ -f "$BASE/control/logs/order_execution.log" ]; then
    echo "--- Execution Log (останні 5 записів) ---"
    tail -5 "$BASE/control/logs/order_execution.log"
else
    echo "❌ Execution log відсутній"
fi
echo ""
if [ -f "$BASE/control/logs/master_audit.log" ]; then
    echo "--- Master Audit (останні 5 подій) ---"
    tail -5 "$BASE/control/logs/master_audit.log"
else
    echo "❌ Master audit відсутній"
fi
