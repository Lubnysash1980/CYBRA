#!/bin/bash
ORDER="R⚕️"
BASE="$HOME/CYBRA/orders/order_${ORDER}"
echo "=== МОНІТОРИНГ R⚕️ ==="
echo "Час: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""
DEADLINE_FILE="$BASE/control/deadlines.txt"
[ -f "$DEADLINE_FILE" ] && { echo "📅 Активні дедлайни:"; cat "$DEADLINE_FILE"; } || echo "⚠️ Файл дедлайнів відсутній"
echo ""
echo "📊 Статистика етапів:"
grep "EVENT=" "$BASE/control/logs/order_execution.log" 2>/dev/null | sort | uniq -c
echo ""
echo "🕐 Останні 3 події:"
tail -3 "$BASE/control/logs/master_audit.log" 2>/dev/null
