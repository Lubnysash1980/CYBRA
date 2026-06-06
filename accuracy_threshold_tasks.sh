#!/data/data/com.termux/files/usr/bin/bash
set -e

redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes
sleep 1

for level in 10 25 50 75 100 150 200; do
  cybra parliament "{\"topic\":\"ACCURACY THRESHOLD TEST level $level\",\"type\":\"test_basic_task\",\"payload\":{\"accuracy_level\":$level,\"goal\":\"визначити поріг точності Parliament/executor при складності $level\"},\"priority\":\"high\"}"
done

cybra parliament '{"topic":"Accuracy Threshold Analyzer","type":"cybra_autofix_task","payload":{"goal":"проаналізувати результати accuracy threshold tests, визначити поріг точності, failed/no_mapping/retry/errors"},"priority":"critical"}'

echo "✅ Accuracy threshold tasks submitted"
cybra status
