#!/data/data/com.termux/files/usr/bin/bash
set -e

redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes
sleep 1

echo "=== CYBRA 1000 QUESTION STRESS TEST ==="

for i in $(seq 1 1000); do
  cybra parliament "{\"topic\":\"AI QUESTION $i / 1000 stress\",\"type\":\"test_basic_task\",\"payload\":{\"question_id\":$i,\"complexity\":1000,\"goal\":\"stress test Parliament/executor/retry/audit/hash pipeline\"},\"priority\":\"high\"}"
done

echo "✅ 1000 stress-test questions submitted"

echo
cybra status

echo
echo "Run executor:"
echo "python3 ~/CYBRA/parliament_executor_v6.py"
