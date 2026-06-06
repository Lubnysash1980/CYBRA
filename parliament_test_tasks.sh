#!/data/data/com.termux/files/usr/bin/bash
set -e

redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes
sleep 1

cybra parliament '{"topic":"PARLIAMENT TEST 1: basic JSON task","type":"test_basic_task","payload":{"check":"json_accept"},"priority":"normal"}'

cybra parliament '{"topic":"PARLIAMENT TEST 2: native token executor","type":"native_token_ecosystem_task","payload":{"check":"native_token"},"priority":"high"}'

cybra parliament '{"topic":"PARLIAMENT TEST 3: PMZ metadata","type":"pmz_historical_metadata_task","payload":{"check":"pmz"},"priority":"high"}'

cybra parliament '{"topic":"PARLIAMENT TEST 4: mining pool","type":"smart_autofix_mining_pool_task","payload":{"check":"mining"},"priority":"critical"}'

cybra parliament '{"topic":"PARLIAMENT TEST 5: emergency alert","type":"emergency_alert_test_task","payload":{"check":"emergency"},"priority":"critical"}'

cybra parliament '{"topic":"PARLIAMENT TEST 6: unknown mapping","type":"unknown_test_task","payload":{"check":"no_mapping"},"priority":"low"}'

cybra parliament '{"topic":"PARLIAMENT TEST 7: executor autofix","type":"cybra_autofix_task","payload":{"check":"autofix"},"priority":"critical"}'

echo "✅ Parliament test tasks submitted"
cybra status
