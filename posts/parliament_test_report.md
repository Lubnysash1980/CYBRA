# CYBRA Parliament Test Report

Audit latest:
aca10e1579814ab74d2674dbf332f18fa2c3cf97b6f411f9d7e82de2700a9033
aec7f3e171219d6301760a6d2d189d83dcbad5bd91ac2b7ff7e7e3acfe665550
4a7c46b428627143da94ef6068bbd3af44d9b213a30f432698f883f9c6d611e0
1ef62dc08d75ec337f4dcfce4b03df3e27e4bc0160a60bd09adb295c29d4ce16
e14045fd7b7b8960faba6dd309784639f1114994ae735974217956b8a06f6d25
03d98cd18574f7e916898ff44cd2e82edcd99da693d9352191f3a90cfe1e7e18
3160064db2b297dd5d71f4d2da30284cc8adbfce35a060b27fad9e8090a7e6ac
9e345d7459d73237dad87453e567230dd61d224ed927a5e8c28989e1fe6e96c2
8c79dacb812998decb2c902c36bb42402131971fdfb9a9cac7db64c5c0c5d48c
5f1c85e21ff85ebfccd79153297cf087d896f78a93a3dfd3b026b78e94e1c098
51cbf626952e9e793cb401fb803a8b0fb3cf0b60bf32260b47deeddb467a0e7b
3428bac77b9a15e21d811724ab09d181354cea0ba7ffce0fb29afe9e2d93ce84
3f8d9040a3c880ed17438de51a687b1aee67f8d1918bd225959604ae5ce0e716
c068a06dbe8a39dde41287854e6c133773cc87723dc2949f80b906f5ff74f54a
c068a06dbe8a39dde41287854e6c133773cc87723dc2949f80b906f5ff74f54a
716317df25a592057b5fd36e9a4225eb5d98910304acc68f9f92f79f7a4a1f64
d944556b86b2a6c1ce152ab40032f226fc6aee43020f5ee17643763ee0702e0f
b2051875b93fa12ce3c69f6cab1c5d3ea2df95c8131463ae25210d76dd0064ee
b2051875b93fa12ce3c69f6cab1c5d3ea2df95c8131463ae25210d76dd0064ee
d944556b86b2a6c1ce152ab40032f226fc6aee43020f5ee17643763ee0702e0f

Results:
{"topic": "PARLIAMENT TEST 7: executor autofix", "type": "cybra_autofix_task", "status": "executed", "script": "cybra_autofix.sh", "double_sha": "e2092fcb7d444d609bcdb821b581dfec18d596dff1bcd6c8d2f53338cb1b0441", "retries": 0, "execution": {"ok": true, "returncode": 0, "stdout": "=== CYBRA AUTOFIX START ===\n[main dd26f8b3a] CYBRA autofix executor and PMZ registry\n 2 files changed, 52 insertions(+), 8 deletions(-)\n✅ CYBRA AUTOFIX DONE\nReport: posts/autofix_report.md\n", "stderr": ""}, "time": 1779828964.2192852}
{"topic": "PARLIAMENT TEST 6: unknown mapping", "type": "unknown_test_task", "status": "no_executor_mapping", "double_sha": "c1aa3bb799fc5ee3066721236d42f3b4e65506e3ae56e17203d2f38671d9515f", "message": "No script mapping yet"}
{"topic": "PARLIAMENT TEST 5: emergency alert", "type": "emergency_alert_test_task", "status": "executed", "script": "emergency_alert_handler.sh", "double_sha": "efc4386d63cc96a9e381d9f9b9cd99692a51a3cd942a27b5cec8ac9ebe3480d4", "retries": 0, "execution": {"ok": true, "returncode": 0, "stdout": "✅ Emergency alert test handled\n", "stderr": ""}, "time": 1779828963.4511054}
{"topic": "PARLIAMENT TEST 4: mining pool", "type": "smart_autofix_mining_pool_task", "status": "executed", "script": "cybra_mining_autofix.sh", "double_sha": "7a22f6cdf9ff720d77d62d2a73537e183e14059a878e9b7c9046e39cfbccb914", "retries": 0, "execution": {"ok": true, "returncode": 0, "stdout": "✅ MINED BLOCK 5\nb423a7423d8b9c0e761c3033b39247fd7afc0ea76d032f9869f37370241d37e1\n[main 1d08f0dfb] CYBRA smart mining autofix block\n 4 files changed, 109 insertions(+), 3 deletions(-)\n✅ Mining autofix executed\n", "stderr": ""}, "time": 1779828963.3870254}
{"topic": "PARLIAMENT TEST 3: PMZ metadata", "type": "pmz_historical_metadata_task", "status": "executed", "script": "create_pmz_registry.sh", "double_sha": "fce3b6d570987dbc732d2726a1a48ea995fbf9b810e1216210f6d11bf93e2eab", "retries": 0, "execution": {"ok": true, "returncode": 0, "stdout": "✅ PMZ registry created\n", "stderr": ""}, "time": 1779828962.538461}
{"topic": "PARLIAMENT TEST 2: native token executor", "type": "native_token_ecosystem_task", "status": "executed", "script": "create_native_token_ecosystem.sh", "double_sha": "fab9f5bafc4d4af5c59df71bc4e98b63297949f00140cb1e77c11d900b1e3b8e", "retries": 0, "execution": {"ok": true, "returncode": 0, "stdout": "[main 92975738c] create CYBRA native token ecosystem\n 2 files changed, 47 insertions(+), 1 deletion(-)\n✅ CYBRA native token ecosystem created\n", "stderr": ""}, "time": 1779828961.6014297}
{"topic": "PARLIAMENT TEST 1: basic JSON task", "type": "test_basic_task", "status": "no_executor_mapping", "double_sha": "cc0f6279f38ab182286f8db6762a56b5a7d9c63d1932c333f24376c314e3f75f", "message": "No script mapping yet"}
