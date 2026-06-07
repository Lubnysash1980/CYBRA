# Two Solana Mints + Native Token + Pool IT Task Check

Status: TWO_SOLANA_MINTS_NATIVE_POOL_IT_TASK_CHECK

PASS: 37
FAIL: 0

## Tests

- PASS — task_exists: feeds/solana_two_mints_native_pool_it_task.json
- PASS — status_ok: IT_TASK_TWO_SOLANA_MINTS_NATIVE_TOKEN_POOL_CREATED
- PASS — owner_ok: EPEhVVhY7AXzWqcJeidWNuBqNbGDjJF35JzPVFXEbYxv
- PASS — alex_mint_ok: {'symbol': 'ALEX', 'mint': 'BNhNw6waDiEobccELrZ483aYEqFRzYGwwHB6DLk5VnFr', 'pool_pair': 'ALEX/USDC'}
- PASS — efi_mint_ok: {'symbol': 'EFI', 'mint': 'EfiCgx3svRwZ1voPXsnYdZo35kzyt5Ct7UHLuvnm6fcR', 'pool_pair': 'EFI/USDC'}
- PASS — usdc_mint_ok: {'symbol': 'USDC', 'mint': 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v'}
- PASS — native_kibra_ok: {'symbol': 'KIBRA', 'mint': 'F5zxQyxq8qWdyauN8ArPofkKKVFxbeTAWSd1oeyazfeU', 'proof_type': 'NFT_PROOF_OF_NATIVE_TOKEN'}
- PASS — native_proof_type_ok: {'symbol': 'KIBRA', 'mint': 'F5zxQyxq8qWdyauN8ArPofkKKVFxbeTAWSd1oeyazfeU', 'proof_type': 'NFT_PROOF_OF_NATIVE_TOKEN'}
- PASS — pool_base_tokens_ok: {'base_tokens_ui': 32000, 'quote_usdc_ui': 2000000, 'target_price_usd_per_token': 62.5, 'base_amount_raw': '32000000000000', 'quote_amount_raw': '2000000000000', 'pairs_to_prepare': ['ALEX/USDC', 'EFI/USDC'], 'native_token_proof_to_attach': 'KIBRA NFT-proof metadata'}
- PASS — pool_target_usdc_ok: {'base_tokens_ui': 32000, 'quote_usdc_ui': 2000000, 'target_price_usd_per_token': 62.5, 'base_amount_raw': '32000000000000', 'quote_amount_raw': '2000000000000', 'pairs_to_prepare': ['ALEX/USDC', 'EFI/USDC'], 'native_token_proof_to_attach': 'KIBRA NFT-proof metadata'}
- PASS — pool_price_ok: {'base_tokens_ui': 32000, 'quote_usdc_ui': 2000000, 'target_price_usd_per_token': 62.5, 'base_amount_raw': '32000000000000', 'quote_amount_raw': '2000000000000', 'pairs_to_prepare': ['ALEX/USDC', 'EFI/USDC'], 'native_token_proof_to_attach': 'KIBRA NFT-proof metadata'}
- PASS — base_raw_ok: 32000000000000
- PASS — usdc_raw_ok: 2000000000000
- PASS — alex_usdc_pair_ok: ['ALEX/USDC', 'EFI/USDC']
- PASS — efi_usdc_pair_ok: ['ALEX/USDC', 'EFI/USDC']
- PASS — live_dex_false: {'real_payment_now': False, 'automatic_SWIFT': False, 'automatic_external_tx': False, 'automatic_price_manipulation': False, 'mainnet_deploy_allowed': False, 'real_mainnet_tx_executed': False, 'real_market_confirmed': False, 'live_dex_create': False, 'manual_OWNER_approval_required': True, 'approval_phrase_required_later': 'I_ACCEPT_DEX_POOL_CREATION_RISK'}
- PASS — mainnet_tx_false: {'real_payment_now': False, 'automatic_SWIFT': False, 'automatic_external_tx': False, 'automatic_price_manipulation': False, 'mainnet_deploy_allowed': False, 'real_mainnet_tx_executed': False, 'real_market_confirmed': False, 'live_dex_create': False, 'manual_OWNER_approval_required': True, 'approval_phrase_required_later': 'I_ACCEPT_DEX_POOL_CREATION_RISK'}
- PASS — market_confirmed_false: {'real_payment_now': False, 'automatic_SWIFT': False, 'automatic_external_tx': False, 'automatic_price_manipulation': False, 'mainnet_deploy_allowed': False, 'real_mainnet_tx_executed': False, 'real_market_confirmed': False, 'live_dex_create': False, 'manual_OWNER_approval_required': True, 'approval_phrase_required_later': 'I_ACCEPT_DEX_POOL_CREATION_RISK'}
- PASS — external_tx_false: {'real_payment_now': False, 'automatic_SWIFT': False, 'automatic_external_tx': False, 'automatic_price_manipulation': False, 'mainnet_deploy_allowed': False, 'real_mainnet_tx_executed': False, 'real_market_confirmed': False, 'live_dex_create': False, 'manual_OWNER_approval_required': True, 'approval_phrase_required_later': 'I_ACCEPT_DEX_POOL_CREATION_RISK'}
- PASS — owner_approval_required: {'real_payment_now': False, 'automatic_SWIFT': False, 'automatic_external_tx': False, 'automatic_price_manipulation': False, 'mainnet_deploy_allowed': False, 'real_mainnet_tx_executed': False, 'real_market_confirmed': False, 'live_dex_create': False, 'manual_OWNER_approval_required': True, 'approval_phrase_required_later': 'I_ACCEPT_DEX_POOL_CREATION_RISK'}
- PASS — file_exists_data_it_department_tasks_solana_two_mints_native_pool_task.json: data/it_department/tasks/solana_two_mints_native_pool_task.json
- PASS — file_exists_data_finance_department_tasks_solana_two_mints_native_pool_task.json: data/finance_department/tasks/solana_two_mints_native_pool_task.json
- PASS — file_exists_data_kibra_dex_pool_tasks_solana_two_mints_native_pool_task.json: data/kibra_dex_pool/tasks/solana_two_mints_native_pool_task.json
- PASS — file_exists_data_native_token_nft_proof_tasks_native_token_pool_proof_task.json: data/native_token_nft_proof/tasks/native_token_pool_proof_task.json
- PASS — file_exists_data_solana_two_mints_native_pool_reports_latest_report.json: data/solana_two_mints_native_pool/reports/latest_report.json
- PASS — file_exists_posts_solana_two_mints_native_pool_it_task.md: posts/solana_two_mints_native_pool_it_task.md
- PASS — file_exists_proofs_solana_two_mints_native_pool_it_task.sha256: proofs/solana_two_mints_native_pool_it_task.sha256
- PASS — sha256_verify_ok: feeds/solana_two_mints_native_pool_it_task.json: OK
data/it_department/tasks/solana_two_mints_native_pool_task.json: OK
data/finance_department/tasks/solana_two_mints_native_pool_task.json: OK
data/kibra_dex_pool/tasks/solana_two_mints_native_pool_task.json: OK
data/native_token_nft_proof/tasks/native_token_pool_proof_task.json: OK
data/solana_two_mints_native_pool/reports/latest_report.json: OK
posts/solana_two_mints_native_pool_it_task.md: OK
- PASS — queue_has_cybra_it_department_queue: cybra:it_department:queue=2
- PASS — queue_has_cybra_finance_department_queue: cybra:finance_department:queue=4
- PASS — queue_has_cybra_dex_pool_queue: cybra:dex_pool:queue=2
- PASS — queue_has_cybra_nft_proof_queue: cybra:nft_proof:queue=8
- PASS — queue_has_cybra_native_token_proof_queue: cybra:native_token:proof_queue=8
- PASS — queue_has_cybra_parliament_queue: cybra:parliament:queue=12
- PASS — queue_has_cybra_audit_queue: cybra:audit:queue=12
- PASS — queue_has_cybra_ai_tasks_block_inbox: cybra:ai:tasks:block_inbox=2
- PASS — queue_has_cybra_market_activation_queue: cybra:market_activation:queue=3

## Safety

real_payment_now: false
automatic_external_tx: false
real_mainnet_tx_executed: false
real_market_confirmed: false
live_dex_create: false

## Double SHA

c7a740ac6d9af33d4d266095a76b32d18a110bf112ec4ebf74489064cf5e583c
