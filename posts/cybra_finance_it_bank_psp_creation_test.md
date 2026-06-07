# Finance IT Bank/PSP Creation Test

Timestamp: 2026-06-07T11:32:02
Status: **FINANCE_IT_CREATION_TEST_PASS**
Score: **100.0%**
Task ID: `FIN-IT-BANK-PSP-20260607_111623`
Test version: `v3_reproofed`

## Checks
- finance_it_task_created: `True`
- task_copied_to_mgs: `True`
- task_copied_to_oracle: `True`
- real_payment_disabled: `True`
- swift_disabled: `True`
- withdrawals_disabled: `True`
- owner_approval_required: `True`
- do_not_store_secrets_in_git: `True`
- exists:data/cybra_finance/contracts/drafts/bank_contract_checklist.md: `True`
- exists:data/cybra_finance/contracts/drafts/psp_contract_checklist.md: `True`
- exists:data/cybra_finance/contracts/drafts/merchant_onboarding_checklist.md: `True`
- exists:data/cybra_finance/contracts/drafts/kyc_aml_policy_draft.md: `True`
- exists:data/cybra_finance/keys/policy/api_key_vault_policy.md: `True`
- exists:data/cybra_finance/live_gate/withdrawal_limits_draft.json: `True`
- exists:posts/cybra_finance_it_bank_psp_task.md: `True`
- exists:feeds/cybra_finance_it_bank_psp_task.json: `True`
- exists:proofs/cybra_finance_it_bank_psp_task.sha256: `True`
- sha256_proof_ok: `True`
- no_real_secret_markers_in_finance_files: `True`

## Redis queues
- cybra_mgs_all: `0`
- cybra_oracle_tasks: `0`
- ai_block_inbox: `0`
- it_department: `0`
- parliament_inbox: `0`
- cybra_finance_evolution: `0`

## Secret leaks
`[]`

## Safety
- real_payment_now: false
- automatic_SWIFT: false
- automatic_withdrawals: false
- bank_live_mode: false
- psp_live_mode: false
- manual_OWNER_approval_required: true
