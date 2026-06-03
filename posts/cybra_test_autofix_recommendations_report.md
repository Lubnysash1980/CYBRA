# CYBRA Test + Autofix + Recommendations Report

Status: generated

## Current state
main_blocks: 10
task_blocks: 179
estimated_kibra_default_reward_100: 18900
parliament_queue: 0
parliament_results: 35
parliament_failed: 0
ai_block_inbox: 0
task_block_mempool: 0
pool_mining_blocks: 29
payment_ready: False
bank_ready: False
psp_ready: False
real_market_confirmed: False
price_usd_per_kibra: 0
autorecovery_report_exists: True

## Parliament recommendations
- **growth** / `promotion`: Просувати KIBRA через utility: AI credits, proof services, bridge packages, developer marketplace, pool mining. Action: `bash cybra_mint_promo.sh report`
- **growth** / `next_blocks`: Наступні AI-завдання не відправляти напряму: переводити у task-blocks і давати пулам на майнинг. Action: `bash cybra_ai_blocks.sh until-done`

## Audit-system recommendations
- Заповнити реальний канал оплати: bank IBAN або PSP provider.
- Не підтверджувати ціну KIBRA без real pool/orderbook/provider/reserve proof.
- Переглянути logs/test_autofix і виправити error/fail рядки.

## Security Analytics
### Missing
- payment requisites: real bank IBAN or PSP provider
- market proof: real pool/orderbook/provider proof
- market proof: provider_name
- market proof: proof_source/proof_reference
- market proof: provider_review_passed=true
- market proof: owner_approval=true

### Warnings
- Sensitive-looking files exist: ai_network/repos/cybro/cigkkuj/.env, ai_network/repos/cybr/cigkkuj/.env, ai_network/repos/c/cigkkuj/.env, .ssh/id_ed25519, recovery_unpack/restore_20260602_154741/CYBRA/.ssh/id_ed25519

### Critical
None

## Conformation8 issues
- MEDIUM / payment_requisites_not_ready: Payment requisites are not ready: legal name / tax ID / IBAN / PSP missing.
- MEDIUM / market_price_not_confirmed: Real KIBRA market price is not confirmed.

## Log-system
errors: 26
warnings: 11

### Log recommendations
- Є error/fail у логах: перевірити останні hits у звіті.
- Є warnings/missing у логах: перевірити, чи це не відсутні опційні модулі.

### Last log hits
- warning / logs/cybra_security_analytics/watch.log: MISSING: 8
- error / logs/cybra_security_analytics/watch.log: PARLIAMENT_FAILED: 0
- warning / logs/cybra_security_analytics/watch.log: MISSING: 8
- error / logs/cybra_security_analytics/watch.log: PARLIAMENT_FAILED: 0
- warning / logs/cybra_security_analytics/watch.log: MISSING: 8
- error / logs/cybra_security_analytics/watch.log: PARLIAMENT_FAILED: 0
- warning / logs/cybra_security_analytics/watch.log: MISSING: 8
- error / logs/kibra_closed_sha_pool_bridge/watch.log: PARLIAMENT_FAILED: 0
- error / logs/kibra_closed_sha_pool_bridge/watch.log: PARLIAMENT_FAILED: 0
- error / logs/kibra_closed_sha_pool_bridge/watch.log: PARLIAMENT_FAILED: 0
- error / logs/kibra_closed_sha_pool_bridge/watch.log: PARLIAMENT_FAILED: 0
- error / logs/supervisor/loop.log:     "failed": {
- error / logs/supervisor/loop.log:     "detect failures",
- error / logs/supervisor/loop.log:     "failed": {
- error / logs/supervisor/loop.log:     "detect failures",
- error / logs/system_test/cybra_system_test_20260603_154033.log:     "parliament_failed": 0,
- warning / logs/system_test/cybra_system_test_20260603_154033.log: WARN=0
- error / logs/system_test/cybra_system_test_20260603_154033.log: FAIL=0
- error / logs/test_autofix/cybra_test_autofix_20260603_185807.log: - Failed: **0**
- error / logs/test_autofix/cybra_test_autofix_20260603_185807.log: PARLIAMENT_FAILED: 0

## Safety
private_keys_collected: False
seed_phrase_collected: False
automatic_real_payment: False
automatic_SWIFT: False
automatic_external_tx: False
real_sell_now: False
manual_OWNER_approval_required: True

## Double SHA
f782f0403fd5cf03995ed7d65d50e14daf5b8eee4c5847843ad92397fd8f1452