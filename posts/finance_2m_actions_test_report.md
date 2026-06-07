# Finance 2M Actions Test Report

Status: FINANCE_2M_ACTIONS_TEST_REPORT
Timestamp: 2026-06-08T02:03:25+0300

## Summary

PASS: 38
WARN: 0
FAIL: 0

## Tests

- PASS — task_json_exists: feeds/finance_target_2m_usd_task.json
- PASS — dispatch_json_exists: feeds/finance_target_2m_usd_dispatch_report.json
- PASS — post_exists: posts/finance_target_2m_usd_task.md
- PASS — tokens_32000: {'base_tokens_ui': 32000, 'target_usd_total': 2000000, 'target_price_usd_per_token': 62.5, 'formula': '2,000,000 USD / 32,000 tokens = 62.5 USD/token'}
- PASS — target_usd_2000000: {'base_tokens_ui': 32000, 'target_usd_total': 2000000, 'target_price_usd_per_token': 62.5, 'formula': '2,000,000 USD / 32,000 tokens = 62.5 USD/token'}
- PASS — price_62_5: {'base_tokens_ui': 32000, 'target_usd_total': 2000000, 'target_price_usd_per_token': 62.5, 'formula': '2,000,000 USD / 32,000 tokens = 62.5 USD/token'}
- PASS — base_raw_correct: 32000000000000
- PASS — usdc_raw_correct: 2000000000000
- PASS — real_market_false: {'real_payment_now': False, 'automatic_SWIFT': False, 'automatic_external_tx': False, 'automatic_price_manipulation': False, 'mainnet_deploy_allowed': False, 'real_mainnet_tx_executed': False, 'manual_OWNER_approval_required': True, 'price_must_be_evidence_based': True, 'target_price_is_not_market_price': True, 'real_market_confirmed': False}
- PASS — real_payment_false: {'real_payment_now': False, 'automatic_SWIFT': False, 'automatic_external_tx': False, 'automatic_price_manipulation': False, 'mainnet_deploy_allowed': False, 'real_mainnet_tx_executed': False, 'manual_OWNER_approval_required': True, 'price_must_be_evidence_based': True, 'target_price_is_not_market_price': True, 'real_market_confirmed': False}
- PASS — external_tx_false: {'real_payment_now': False, 'automatic_SWIFT': False, 'automatic_external_tx': False, 'automatic_price_manipulation': False, 'mainnet_deploy_allowed': False, 'real_mainnet_tx_executed': False, 'manual_OWNER_approval_required': True, 'price_must_be_evidence_based': True, 'target_price_is_not_market_price': True, 'real_market_confirmed': False}
- PASS — mainnet_tx_not_executed: {'real_payment_now': False, 'automatic_SWIFT': False, 'automatic_external_tx': False, 'automatic_price_manipulation': False, 'mainnet_deploy_allowed': False, 'real_mainnet_tx_executed': False, 'manual_OWNER_approval_required': True, 'price_must_be_evidence_based': True, 'target_price_is_not_market_price': True, 'real_market_confirmed': False}
- PASS — target_not_market_price: {'real_payment_now': False, 'automatic_SWIFT': False, 'automatic_external_tx': False, 'automatic_price_manipulation': False, 'mainnet_deploy_allowed': False, 'real_mainnet_tx_executed': False, 'manual_OWNER_approval_required': True, 'price_must_be_evidence_based': True, 'target_price_is_not_market_price': True, 'real_market_confirmed': False}
- PASS — owner_wallet_correct: owner=EPEhVVhY7AXzWqcJeidWNuBqNbGDjJF35JzPVFXEbYxv expected=EPEhVVhY7AXzWqcJeidWNuBqNbGDjJF35JzPVFXEbYxv
- PASS — it_queue_declared: ['cybra:it_department:queue', 'cybra:finance_department:queue', 'cybra:parliament:queue', 'cybra:ai:tasks:block_inbox', 'cybra:kibra:market_proof:queue', 'cybra:dex_pool:queue', 'cybra:audit:queue']
- PASS — finance_queue_declared: ['cybra:it_department:queue', 'cybra:finance_department:queue', 'cybra:parliament:queue', 'cybra:ai:tasks:block_inbox', 'cybra:kibra:market_proof:queue', 'cybra:dex_pool:queue', 'cybra:audit:queue']
- PASS — parliament_queue_declared: ['cybra:it_department:queue', 'cybra:finance_department:queue', 'cybra:parliament:queue', 'cybra:ai:tasks:block_inbox', 'cybra:kibra:market_proof:queue', 'cybra:dex_pool:queue', 'cybra:audit:queue']
- PASS — dex_queue_declared: ['cybra:it_department:queue', 'cybra:finance_department:queue', 'cybra:parliament:queue', 'cybra:ai:tasks:block_inbox', 'cybra:kibra:market_proof:queue', 'cybra:dex_pool:queue', 'cybra:audit:queue']
- PASS — audit_queue_declared: ['cybra:it_department:queue', 'cybra:finance_department:queue', 'cybra:parliament:queue', 'cybra:ai:tasks:block_inbox', 'cybra:kibra:market_proof:queue', 'cybra:dex_pool:queue', 'cybra:audit:queue']
- PASS — post_has_62_5: markdown target price
- PASS — post_has_not_market_proof_warning: warning exists
- PASS — finance_sha256_ok: feeds/finance_target_2m_usd_task.json: OK
feeds/finance_target_2m_usd_dispatch_report.json: OK
data/finance_target_2m/tasks/latest_task.json: OK
data/finance_target_2m/reports/latest_report.json: OK
posts/finance_target_2m_usd_task.md: OK
- PASS — queue_len_cybra:it_department:queue: cybra:it_department:queue=1; if 0, executor may have already consumed it
- PASS — queue_len_cybra:finance_department:queue: cybra:finance_department:queue=1; if 0, executor may have already consumed it
- PASS — queue_len_cybra:parliament:queue: cybra:parliament:queue=2; if 0, executor may have already consumed it
- PASS — queue_len_cybra:ai:tasks:block_inbox: cybra:ai:tasks:block_inbox=1; if 0, executor may have already consumed it
- PASS — queue_len_cybra:kibra:market_proof:queue: cybra:kibra:market_proof:queue=1; if 0, executor may have already consumed it
- PASS — queue_len_cybra:dex_pool:queue: cybra:dex_pool:queue=1; if 0, executor may have already consumed it
- PASS — queue_len_cybra:audit:queue: cybra:audit:queue=2; if 0, executor may have already consumed it
- PASS — target_env_exists: data/kibra_dex_pool/private/.env.finance_target_2m
- PASS — target_env_live_disabled: target env
- PASS — target_env_market_false: target env
- PASS — target_env_2m_usdc_raw: USDC raw
- PASS — live_env_not_enabled: main .env must not be live
- PASS — dex_approval_not_enabled: approval must not be active
- PASS — dex_pool_not_created: created=False status=KIBRA_DEX_POOL_SAFE_PLAN
- PASS — blockchain_anchor_tx_not_sent: no anchor tx file
- PASS — dex_plan_command_runs: _per_token": 62.5,
  "rpc_verified": false,
  "owner_base_balance_ui": null,
  "owner_quote_balance_ui": null,
  "warnings": [
    "rpc_not_verified_plan_uses_local_decimals"
  ],
  "created": false,
  "live_dex_create": false,
  "safety": {
    "real_payment_now": false,
    "automatic_SWIFT": false,
    "automatic_external_tx": false,
    "automatic_price_manipulation": false,
    "mainnet_deploy_allowed": false,
    "manual_OWNER_approval_required": true,
    "plan_only_no_transaction": true
  },
  "rpc_error": "curl: (60) SSL: certificate subject name 'sinkhole.cert.gov.ua' does not match target hostname 'api.mainnet-beta.solana.com'\nMore details here: https://curl.se/docs/sslcerts.html\n\ncurl failed to verify the legitimacy of the server and therefore could not\nestablish a secure connection to it. To learn more about this situation and\nhow to fix it, please visit the webpage mentioned above.",
  "double_sha": "bb1db2014e4648c87cfa87368bc0f9dce691b76c547819c682cb796b73b15fa0"
}

## Redis queues

- cybra:it_department:queue: 1
- cybra:finance_department:queue: 1
- cybra:parliament:queue: 2
- cybra:ai:tasks:block_inbox: 1
- cybra:kibra:market_proof:queue: 1
- cybra:dex_pool:queue: 1
- cybra:audit:queue: 2

## Safety

real_payment_now: false
automatic_external_tx: false
real_mainnet_tx_executed: false
live_dex_create_tested: false

## Double SHA
51d451e590190edf6954467f50cc7c2ecd1e066d65d01d20d1eb495b6bd2b38c