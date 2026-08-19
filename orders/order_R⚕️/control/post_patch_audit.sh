#!/bin/bash
ORDER="R⚕️"
BASE="$HOME/CYBRA/orders/order_${ORDER}"
PASS=0
WARN=0
FAIL=0

ok()   { echo "[ OK ] $1"; PASS=$((PASS+1)); }
warn() { echo "[WARN] $1"; WARN=$((WARN+1)); }
fail() { echo "[FAIL] $1"; FAIL=$((FAIL+1)); }

echo "========================================"
echo " CYBRA R⚕️ — POST-PATCH AUDIT"
echo " TIME: $(date '+%Y-%m-%d %H:%M:%S %z')"
echo "========================================"

echo "--- CONTROL ---"
for f in \
  "$BASE/control/logs/order_execution.log" \
  "$BASE/control/logs/master_audit.log" \
  "$BASE/control/check_status.sh" \
  "$BASE/control/monitor.sh" \
  "$BASE/control/alerts.sh"
do
    [ -f "$f" ] && ok "$(basename "$f") існує" || fail "$(basename "$f") відсутній"
done

echo "--- PRODUCTION ---"
for d in \
  "$BASE/production" \
  "$BASE/production/equipment" \
  "$BASE/production/materials" \
  "$BASE/production/suppliers" \
  "$BASE/production/quality_control"
do
    [ -d "$d" ] && ok "$(basename "$d") існує" || fail "$(basename "$d") відсутня"
done

echo "--- ERROR SCAN ---"
ERRORS=0
for LOGFILE in "$BASE/control/logs/order_execution.log" "$BASE/control/logs/master_audit.log"; do
    if [ -f "$LOGFILE" ]; then
        COUNT=$(grep -Eci 'FAIL|ERROR|CRITICAL' "$LOGFILE" 2>/dev/null || true)
        [[ "$COUNT" =~ ^[0-9]+$ ]] && ERRORS=$((ERRORS + COUNT))
    fi
done
echo "ERROR_COUNT=$ERRORS"
[ "$ERRORS" -eq 0 ] && ok "Критичних помилок у журналах не знайдено" || fail "У журналах знайдено $ERRORS помилок"

echo "--- SCRIPT CHECK ---"
for script in "$BASE/control/check_status.sh" "$BASE/control/monitor.sh" "$BASE/control/alerts.sh"; do
    [ -f "$script" ] && [ -x "$script" ] && ok "$(basename "$script") executable" || warn "$(basename "$script") не має chmod +x"
done

echo "--- SUMMARY ---"
echo "PASS=$PASS"
echo "WARN=$WARN"
echo "FAIL=$FAIL"
[ "$FAIL" -eq 0 ] && echo "AUDIT_RESULT=PASS" || echo "AUDIT_RESULT=FAIL"
echo "========================================"
