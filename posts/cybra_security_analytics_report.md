# CYBRA Security Analytics Report

Status: security_scan_completed
Risk level: MEDIUM
Risk score: 29

## Parliament
queue: 0
results: 14
failed: 0
ai_block_inbox: 0
task_block_mempool: 0
pool_mining_blocks: 8
task_blocks_mined: 8

## Balance
main_blocks: 10
task_blocks: 52
estimated_kibra_default_reward_100: 6200
reported_total_mined_kibra: 5800
reported_available_kibra: 5800

## Missing
- payment requisites: payer legal/display name
- payment requisites: tax_id_or_edrpou
- payment requisites: real bank IBAN or PSP provider
- market proof: real pool/orderbook/provider proof
- market proof: provider_name
- market proof: proof_source/proof_reference
- market proof: provider_review_passed=true
- market proof: owner_approval=true

## Warnings
- Sensitive-looking files exist: ai_network/repos/cybro/cigkkuj/.env, ai_network/repos/cybr/cigkkuj/.env, ai_network/repos/c/cigkkuj/.env, .ssh/id_ed25519, recovery_unpack/restore_20260602_154741/CYBRA/.ssh/id_ed25519

## Critical
None

## Market
gate_exists: True
collector_exists: True
real_market_confirmed: False
price_usd_per_kibra: 0
collector_status: no_valid_market_proof
collector_valid: False

## Payment requisites
exists: True
ready: False
bank_ready: False
psp_ready: False
missing: ['payer legal/display name', 'tax_id_or_edrpou', 'real bank IBAN or PSP provider']

## Safety
private_keys_collected: False
seed_phrase_collected: False
automatic_real_payment: False
automatic_SWIFT: False
automatic_external_tx: False
real_sell_now: False
manual_OWNER_approval_required: True

## Double SHA
74adb6642bd46f83d9d4a8a973a2d95968fff06fd501cba5404949a1d9a552ec