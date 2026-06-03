# CYBRA Task Test Diagnostics

Status: generated  
Double SHA: `86333a960bbc37734738b27bd0ae65a3beb9863920edc7816b1a6f037afc7058`

## Summary

- Checked records: 74
- Executed: 55
- Not executed: 10
- Still missing mapping: 0
- Old no-mapping already fixed now: 8
- Failed/Error: 2
- Review rejected: 2
- Review hold: 0
- Evolution hold: 0
- Evolution rejected: 0
- Executor mapping count: 47

## Queue state

- parliament_queue: 0
- parliament_results: 65
- parliament_failed: 0
- review_incoming: 0
- review_approved: 1
- review_hold: 0
- review_rejected: 2
- evolution_approved: 6
- evolution_hold: 0
- evolution_rejected: 0

## Statuses

- `executed`: 55
- `no_executor_mapping`: 8
- `unknown`: 7
- `failed`: 2
- `reviewed`: 2

## Task types

- `air_alert_task`: 10
- `cybra_autofix_task`: 7
- `evolution_guard_task`: 6
- `monetization_department_task`: 4
- `owner_orchestrator_task`: 3
- `kibra_token_chain_task`: 3
- `closed_evolution_selfseal_task`: 3
- `audit_dedupe_test_task`: 3
- `analytics_committee_task`: 3
- `revision_organ_task`: 3
- `smart_autofix_mining_pool_task`: 3
- `existing_tasks_activation_task`: 2
- `token_pool_ai_task`: 2
- `institution_audit_task`: 2
- `biometric_succession_task`: 2
- `test`: 2
- `native_token_ecosystem_task`: 2
- `pmz_historical_metadata_task`: 2
- `None`: 2
- `evolution_deployment_task`: 1
- `finance_department_task`: 1
- `hash_module_test_task`: 1
- `evo_committee_task`: 1
- `queue_fix`: 1
- `ai_task`: 1
- `self_expanding_execution_engine_task`: 1
- `executor_autoheal_task`: 1
- `codespaces_keepalive_task`: 1
- `github_double_backend_task`: 1

## Scripts / handlers

- `none`: 17
- `air_alert_handler.sh`: 8
- `cybra_autofix.sh`: 4
- `owner_orchestrator_handler.sh`: 3
- `kibra_token_chain_handler.sh`: 3
- `closed_evolution_selfseal_handler.sh`: 3
- `audit_dedupe_test_handler.sh`: 3
- `analytics_committee_handler.sh`: 3
- `revision_organ_handler.sh`: 3
- `['bash', 'cybra_autofix.sh']`: 3
- `['bash', 'cybra_mining_autofix.sh']`: 3
- `existing_tasks_activation_handler.sh`: 2
- `monetization_department_handler.sh`: 2
- `token_pool_ai_handler.sh`: 2
- `institution_audit_handler.sh`: 2
- `evolution_guard_handler.sh`: 2
- `biometric_succession_handler.sh`: 2
- `['bash', 'create_pmz_registry.sh']`: 2
- `evolution_deployment_handler.sh`: 1
- `finance_department_handler.sh`: 1
- `hash_module_test_handler.sh`: 1
- `evo_committee_handler.sh`: 1
- `ai_chat_test_handler.sh`: 1
- `create_native_token_ecosystem.sh`: 1
- `['bash', 'create_native_token_ecosystem.sh']`: 1

## Sources

- `cybra:parliament:results`: 65
- `cybra:evolution:approved`: 6
- `cybra:review:rejected`: 2
- `cybra:review:approved`: 1

## Still missing mapping

- none


## Old no-mapping but fixed now

- `air_alert_task` — Ракетна небезпека → now mapped to `air_alert_handler.sh`
- `queue_fix` — test → now mapped to `evo_committee_handler.sh`
- `ai_task` — AI TEST → now mapped to `evo_committee_handler.sh`
- `test` — CYBRA AI CHAT TEST → now mapped to `evo_committee_handler.sh`
- `self_expanding_execution_engine_task` — CYBRA Self-Expanding Execution Engine → now mapped to `evo_committee_handler.sh`
- `executor_autoheal_task` — CYBRA 5-Level Double-SHA Guardian Recovery → now mapped to `evo_committee_handler.sh`
- `codespaces_keepalive_task` — CYBRA Codespaces Keepalive Support → now mapped to `evo_committee_handler.sh`
- `github_double_backend_task` — CYBRA GitHub Double Backend Proof → now mapped to `evo_committee_handler.sh`


## Recommendations

- **ok**: Частина no_executor_mapping — це стара історія. Зараз mapping уже є. Action: `Не страшно. Старі записи лишити як audit або очистити окремо.`
- **review**: Є задачі, відхилені review-органом. Action: `Подивись: bash cybra_review.sh rejected`


## Latest records

- `executed` / `existing_tasks_activation_task` — CYBRA Existing Tasks Evolution Activation / script: `existing_tasks_activation_handler.sh` / source: `cybra:parliament:results`
- `executed` / `existing_tasks_activation_task` — CYBRA Existing Tasks Evolution Activation / script: `existing_tasks_activation_handler.sh` / source: `cybra:parliament:results`
- `executed` / `evolution_deployment_task` — CYBRA Evolution Deployment Cycle / script: `evolution_deployment_handler.sh` / source: `cybra:parliament:results`
- `executed` / `monetization_department_task` — CYBRA KIBRA Monetization Department / script: `monetization_department_handler.sh` / source: `cybra:parliament:results`
- `executed` / `owner_orchestrator_task` — Block 7 Car Purchase Intent / script: `owner_orchestrator_handler.sh` / source: `cybra:parliament:results`
- `executed` / `monetization_department_task` — CYBRA KIBRA Monetization Evolution / script: `monetization_department_handler.sh` / source: `cybra:parliament:results`
- `executed` / `kibra_token_chain_task` — Build KIBRA Image Token Chain / script: `kibra_token_chain_handler.sh` / source: `cybra:parliament:results`
- `failed` / `kibra_token_chain_task` — Build KIBRA Image Token Chain / script: `kibra_token_chain_handler.sh` / source: `cybra:parliament:results`
- `executed` / `owner_orchestrator_task` — Set OWNER as MAIN_ORCHESTRATOR and resolve finance risk / external anchor / car preflight / script: `owner_orchestrator_handler.sh` / source: `cybra:parliament:results`
- `executed` / `owner_orchestrator_task` — Set OWNER as MAIN_ORCHESTRATOR and resolve finance risk / external anchor / car preflight / script: `owner_orchestrator_handler.sh` / source: `cybra:parliament:results`
- `failed` / `kibra_token_chain_task` — Build KIBRA Image Token Chain / script: `kibra_token_chain_handler.sh` / source: `cybra:parliament:results`
- `executed` / `token_pool_ai_task` — CYBRA Token Pool AI Finance Orchestrator / script: `token_pool_ai_handler.sh` / source: `cybra:parliament:results`
- `executed` / `token_pool_ai_task` — CYBRA Token Pool AI Finance Orchestrator / script: `token_pool_ai_handler.sh` / source: `cybra:parliament:results`
- `executed` / `finance_department_task` — CYBRA Finance Department / script: `finance_department_handler.sh` / source: `cybra:parliament:results`
- `executed` / `institution_audit_task` — CYBRA Parliament Institution Audit / script: `institution_audit_handler.sh` / source: `cybra:parliament:results`

