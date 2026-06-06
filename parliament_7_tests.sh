#!/data/data/com.termux/files/usr/bin/bash
set -e

redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes
sleep 1

echo "=== CYBRA Parliament 7 Tests ==="

cybra parliament '{"topic":"TEST 1 Native Token","type":"native_token_ecosystem_task","payload":{"test":1},"priority":"high"}'

cybra parliament '{"topic":"TEST 2 PMZ Registry","type":"pmz_historical_metadata_task","payload":{"test":2},"priority":"high"}'

cybra parliament '{"topic":"TEST 3 Mining Engine","type":"smart_autofix_mining_pool_task","payload":{"test":3},"priority":"critical"}'

cybra parliament '{"topic":"TEST 4 Emergency Alert","type":"emergency_alert_test_task","payload":{"test":4},"priority":"critical"}'

cybra parliament '{"topic":"TEST 5 Self Expanding Engine","type":"self_expanding_execution_engine_task","payload":{"test":5},"priority":"high"}'

cybra parliament '{"topic":"TEST 6 GitHub Backend","type":"github_double_backend_task","payload":{"test":6},"priority":"normal"}'

cybra parliament '{"topic":"TEST 7 Executor AutoHeal","type":"executor_autoheal_task","payload":{"test":7},"priority":"critical"}'

echo "✅ 7 tests submitted"

echo
echo "Run executor:"
echo "python3 ~/CYBRA/parliament_executor_v6.py"
