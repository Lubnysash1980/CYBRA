#!/data/data/com.termux/files/usr/bin/bash
set -e

cd "$HOME/CYBRA"

mkdir -p logs/resilience posts proofs feeds

redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes
sleep 1

RUNNING=$(pgrep -f parliament_executor_v6.py | wc -l)
MIN=3
STANDBY=2

if [ "$RUNNING" -lt "$MIN" ]; then
  NEED=$((MIN - RUNNING))
  for i in $(seq 1 "$NEED"); do
    nohup python3 parliament_executor_v6.py >> logs/resilience/worker_pool.log 2>&1 &
    echo "$(date -Iseconds) spawned_worker pid=$!" >> logs/resilience/worker_spawn.log
  done
fi

FAILED=$(redis-cli llen cybra:parliament:failed 2>/dev/null || echo 0)
RESULTS=$(redis-cli llen cybra:parliament:results 2>/dev/null || echo 1)

python3 - "$FAILED" "$RESULTS" <<'PY'
import sys, json, time
from pathlib import Path

failed = int(sys.argv[1])
results = max(int(sys.argv[2]), 1)
rate = failed / results * 100

status = {
    "time": time.time(),
    "failed": failed,
    "results": results,
    "failure_rate_percent": rate,
    "threshold_percent": 3,
    "action": "none"
}

if rate >= 3:
    status["action"] = "replace_workers_and_create_autofix"

Path("feeds/worker_resilience_status.json").write_text(
    json.dumps(status, ensure_ascii=False, indent=2),
    encoding="utf-8"
)

print(json.dumps(status, ensure_ascii=False, indent=2))
PY

ACTION=$(python3 - <<'PY'
import json
from pathlib import Path
p = Path("feeds/worker_resilience_status.json")
print(json.loads(p.read_text()).get("action"))
PY
)

if [ "$ACTION" = "replace_workers_and_create_autofix" ]; then
  pkill -f parliament_executor_v6.py 2>/dev/null || true
  sleep 1

  for i in 1 2 3 4 5; do
    nohup python3 parliament_executor_v6.py >> logs/resilience/worker_pool.log 2>&1 &
    echo "$(date -Iseconds) replacement_worker pid=$!" >> logs/resilience/worker_spawn.log
  done

  cybra parliament '{"topic":"Worker Failure Rate Autofix","type":"cybra_autofix_task","payload":{"goal":"repair worker pool after failure rate >= 3 percent"},"priority":"critical"}'
fi

cat > posts/worker_resilience_status.md <<MD
# CYBRA Worker Resilience

Running workers:
$(pgrep -f parliament_executor_v6.py | wc -l)

Failed queue:
$FAILED

Results:
$RESULTS

Status feed:
feeds/worker_resilience_status.json
MD

sha256sum posts/worker_resilience_status.md feeds/worker_resilience_status.json workers/pool/worker_resilience_policy.json > proofs/worker_resilience.sha256

echo "✅ Worker resilience checked"
