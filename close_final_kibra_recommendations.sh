#!/data/data/com.termux/files/usr/bin/bash
set -e

cd "$HOME/CYBRA"

echo "=== 1. FIX / CREATE MISSING COMMITTEES ==="
bash cybra_institution.sh repair || true
bash cybra_institution.sh check || true

echo
echo "=== 2. SHOW FINANCE RISK ITEMS ==="
bash cybra_finance.sh report >/dev/null 2>&1 || true

python3 - <<'PY'
import json
from pathlib import Path

p = Path("feeds/finance_department_report.json")
if not p.exists():
    print("finance report missing")
    raise SystemExit(0)

d = json.loads(p.read_text())
items = d.get("risk_items", [])

print("Finance risk items:", len(items))
for i, x in enumerate(items, 1):
    print()
    print("RISK", i)
    print("topic:", x.get("topic"))
    print("type:", x.get("type"))
    print("status:", x.get("status"))
    print("score:", x.get("score"))
    print("risk_hits:", x.get("risk_hits"))
    print("recommendation:", x.get("recommendation"))
PY

echo
echo "=== 3. CHECK FAILED TASKS ==="
redis-cli LRANGE cybra:parliament:failed 0 20

echo
echo "=== 4. RETEST KIBRA CHAIN DIRECTLY ==="
bash cybra_kibra_chain.sh verify || true
bash cybra_kibra_chain.sh report >/dev/null 2>&1 || true
bash cybra_kibra_chain.sh status || true

echo
echo "=== 5. RETEST KIBRA THROUGH PARLIAMENT ==="
bash cybra_kibra_chain.sh task || true

for i in $(seq 1 20); do
  echo "round=$i queue=$(redis-cli LLEN cybra:parliament:queue)"
  python3 parliament_executor_v6.py || true
  sleep 1
  [ "$(redis-cli LLEN cybra:parliament:queue)" = "0" ] && break
done

echo
echo "=== 6. SEARCH KIBRA RESULTS ==="
cybra results | grep -i "kibra\|кібра\|token_pool\|finance_department" | head -30 || true

echo
echo "=== 7. REFRESH FINAL REVIEW ==="
bash review_kibra_parliament_response.sh || true

echo
echo "=== 8. FINAL STATUS ==="
cybra status || true
bash cybra_owner_orchestrator.sh status || true
bash cybra_kibra_chain.sh status || true

echo
echo "✅ FINAL KIBRA RECOMMENDATION CHECK DONE"
