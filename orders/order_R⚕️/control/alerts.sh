#!/bin/bash
ORDER="R⚕️"
BASE="$HOME/CYBRA/orders/order_${ORDER}"
check_deadline() {
    local deadline_file="$BASE/control/deadlines.txt"
    [ -f "$deadline_file" ] && while IFS= read -r line; do
        [[ $line == *"DEADLINE"* ]] && echo "🚨 УВАГА: $line"
    done < "$deadline_file"
}
check_status() {
    local last_status=$(grep "STATUS=" "$BASE/control/logs/order_execution.log" 2>/dev/null | tail -1)
    echo "📌 Поточний статус: $last_status"
}
check_deadline
check_status
