#!/data/data/com.termux/files/usr/bin/bash
set -e

cd "$HOME/CYBRA"

echo "=== CLOSE KIBRA PARLIAMENT OPEN POINTS ==="

redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes
sleep 1

python3 - <<'PY' >/dev/null 2>&1 || python3 -m pip install redis
import redis
PY

echo
echo "=== 1. QUEUE KEYS CHECK ==="
python3 - <<'PY'
import redis, json
r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

keys = [
    "cybra:parliament:queue",
    "parliament_queue",
    "cybra:queue",
    "cybra:review:incoming",
    "cybra:evolution:hold",
    "cybra:evolution:rejected"
]

for k in keys:
    try:
        t = r.type(k)
        if t == "list":
            print(f"{k}: {r.llen(k)}")
        elif t == "none":
            print(f"{k}: 0")
        else:
            print(f"{k}: type={t}")
    except Exception as e:
        print(f"{k}: error {e}")

print()
print("cybra:parliament:queue preview:")
for raw in r.lrange("cybra:parliament:queue", 0, 10):
    try:
        obj = json.loads(raw)
        print("-", obj.get("type"), "|", obj.get("topic"))
    except Exception:
        print("-", raw[:160])
PY

echo
echo "=== 2. DRAIN OFFICIAL PARLIAMENT QUEUE ==="
for i in $(seq 1 30); do
  Q="$(redis-cli LLEN cybra:parliament:queue)"
  echo "round=$i queue=$Q"

  if [ "$Q" = "0" ]; then
    break
  fi

  python3 parliament_executor_v6.py || true
  sleep 1
done

cybra worker-start || true
sleep 8

echo
echo "=== 3. REFRESH MODULE REPORTS ==="
bash cybra_kibra_chain.sh verify || true
bash cybra_kibra_chain.sh report >/dev/null 2>&1 || true
bash cybra_finance.sh report >/dev/null 2>&1 || true
bash cybra_hash_test.sh run >/dev/null 2>&1 || true
bash cybra_institution.sh check >/dev/null 2>&1 || true
bash cybra_task_test_diagnostics.sh report >/dev/null 2>&1 || true

echo
echo "=== 4. KIBRA RESULTS SEARCH ==="
python3 - <<'PY'
import redis, json
r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

found = []
for raw in r.lrange("cybra:parliament:results", 0, 300):
    try:
        obj = json.loads(raw)
    except Exception:
        continue

    text = json.dumps(obj, ensure_ascii=False).lower()
    if (
        "kibra" in text
        or "кібра" in text
        or "token_pool_ai" in text
        or obj.get("type") in ["kibra_token_chain_task", "token_pool_ai_task", "finance_department_task"]
    ):
        found.append(obj)

print("KIBRA-related results:", len(found))
for x in found[:20]:
    print("-", x.get("status"), "|", x.get("type"), "|", x.get("topic"), "| script:", x.get("script"))
PY

echo
echo "=== 5. FINANCE RISK ITEMS ==="
python3 - <<'PY'
import json
from pathlib import Path

p = Path("feeds/finance_department_report.json")
if not p.exists():
    print("finance report missing")
    raise SystemExit(0)

d = json.loads(p.read_text())
items = d.get("risk_items", [])

print("Risk items:", len(items))
for x in items[:20]:
    print()
    print("topic:", x.get("topic"))
    print("type:", x.get("type"))
    print("status:", x.get("status"))
    print("score:", x.get("score"))
    print("risk_hits:", x.get("risk_hits"))
    print("recommendation:", x.get("recommendation"))
PY

echo
echo "=== 6. ANCHOR QUEUE PREVIEW ==="
bash cybra_kibra_chain.sh anchor-queue | head -20 || true

echo
echo "=== 7. FINAL STATUS ==="
cybra status || true
bash cybra_kibra_chain.sh status || true
bash cybra_institution.sh status || true

echo
echo "=== 8. FINAL REVIEW REBUILD ==="
bash review_kibra_parliament_response.sh || true

echo
echo "✅ CLOSED KIBRA PARLIAMENT OPEN POINTS CHECK FINISHED"
