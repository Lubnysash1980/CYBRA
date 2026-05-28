#!/data/data/com.termux/files/usr/bin/bash
set -e

cd "$HOME/CYBRA"

mkdir -p logs/resilience posts proofs feeds

redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes
sleep 1

MIN=3

RUNNING=$(ps aux | grep "python3 parliament_executor_v6.py" | grep -v grep | wc -l)

if [ "$RUNNING" -lt "$MIN" ]; then
  NEED=$((MIN - RUNNING))
  for i in $(seq 1 "$NEED"); do
    nohup python3 parliament_executor_v6.py >> logs/resilience/worker_pool.log 2>&1 &
    echo "$(date -Iseconds) spawned_worker pid=$!" >> logs/resilience/worker_spawn.log
    sleep 1
  done
fi

sleep 2

RUNNING_AFTER=$(ps aux | grep "python3 parliament_executor_v6.py" | grep -v grep | wc -l)

FAILED=$(redis-cli llen cybra:parliament:failed 2>/dev/null || echo 0)
RESULTS=$(redis-cli llen cybra:parliament:results 2>/dev/null || echo 1)

python3 - "$FAILED" "$RESULTS" "$RUNNING_AFTER" <<'PY'
import sys, json, time
from pathlib import Path

failed = int(sys.argv[1])
results = max(int(sys.argv[2]), 1)
running = int(sys.argv[3])
rate = failed / results * 100

status = {
    "time": time.time(),
    "running_workers": running,
    "failed": failed,
    "results": results,
    "failure_rate_percent": rate,
    "threshold_percent": 3,
    "action": "none"
}

if running < 3:
    status["action"] = "worker_spawn_attempted_but_insufficient"

if rate >= 3:
    status["action"] = "replace_workers_and_create_autofix"

Path("feeds/worker_resilience_status.json").write_text(
    json.dumps(status, ensure_ascii=False, indent=2),
    encoding="utf-8"
)

print(json.dumps(status, ensure_ascii=False, indent=2))
PY

cat > posts/worker_resilience_status.md <<MD
# CYBRA Worker Resilience

Running workers:
$RUNNING_AFTER

Failed queue:
$FAILED

Results:
$RESULTS

Status feed:
feeds/worker_resilience_status.json
MD

sha256sum posts/worker_resilience_status.md feeds/worker_resilience_status.json workers/pool/worker_resilience_policy.json > proofs/worker_resilience.sha256

echo "✅ Worker resilience checked"
