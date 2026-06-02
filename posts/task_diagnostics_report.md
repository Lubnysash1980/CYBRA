# CYBRA Task Test Diagnostics

Status: generated  
Double SHA: `feb662ae2de2f19913eea3de7305c0672a52421bce6569391adba8fa62931b5b`

## Summary

- Checked records: 54
- Executed: 38
- Not executed: 9
- Still missing mapping: 0
- Old no-mapping already fixed now: 9
- Failed/Error: 0
- Review rejected: 2
- Review hold: 0
- Evolution hold: 0
- Evolution rejected: 0
- Executor mapping count: 38

## Queue state

- parliament_queue: 2
- parliament_results: 46
- parliament_failed: 1
- review_incoming: 0
- review_approved: 1
- review_hold: 0
- review_rejected: 2
- evolution_approved: 4
- evolution_hold: 0
- evolution_rejected: 0

## Statuses

- `executed`: 38
- `no_executor_mapping`: 9
- `unknown`: 5
- `reviewed`: 2

## Task types

- `air_alert_task`: 10
- `cybra_autofix_task`: 7
- `evolution_guard_task`: 4
- `closed_evolution_selfseal_task`: 3
- `audit_dedupe_test_task`: 3
- `analytics_committee_task`: 3
- `revision_organ_task`: 3
- `smart_autofix_mining_pool_task`: 3
- `biometric_succession_task`: 2
- `test`: 2
- `native_token_ecosystem_task`: 2
- `self_expanding_execution_engine_task`: 2
- `pmz_historical_metadata_task`: 2
- `None`: 2
- `evo_committee_task`: 1
- `queue_fix`: 1
- `ai_task`: 1
- `executor_autoheal_task`: 1
- `codespaces_keepalive_task`: 1
- `github_double_backend_task`: 1

## Scripts / handlers

- `none`: 16
- `air_alert_handler.sh`: 8
- `cybra_autofix.sh`: 4
- `closed_evolution_selfseal_handler.sh`: 3
- `audit_dedupe_test_handler.sh`: 3
- `analytics_committee_handler.sh`: 3
- `revision_organ_handler.sh`: 3
- `['bash', 'cybra_autofix.sh']`: 3
- `['bash', 'cybra_mining_autofix.sh']`: 3
- `biometric_succession_handler.sh`: 2
- `['bash', 'create_pmz_registry.sh']`: 2
- `evo_committee_handler.sh`: 1
- `ai_chat_test_handler.sh`: 1
- `create_native_token_ecosystem.sh`: 1
- `['bash', 'create_native_token_ecosystem.sh']`: 1

## Sources

- `cybra:parliament:results`: 46
- `cybra:evolution:approved`: 4
- `cybra:review:rejected`: 2
- `cybra:parliament:failed`: 1
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
- `self_expanding_execution_engine_task` — CYBRA Self-Expanding Execution Engine → now mapped to `evo_committee_handler.sh`


## Recommendations

- **important**: У черзі виконання є задачі. Action: `Запусти: cybra worker-start && sleep 5 && cybra status`
- **ok**: Частина no_executor_mapping — це стара історія. Зараз mapping уже є. Action: `Не страшно. Старі записи лишити як audit або очистити окремо.`
- **review**: Є задачі, відхилені review-органом. Action: `Подивись: bash cybra_review.sh rejected`


## Latest records

- `executed` / `closed_evolution_selfseal_task` — CYBRA Parliament Internal Closed Self-Seal / script: `closed_evolution_selfseal_handler.sh` / source: `cybra:parliament:results`
- `executed` / `biometric_succession_task` — CYBRA Biometric Succession Guard / script: `biometric_succession_handler.sh` / source: `cybra:parliament:results`
- `executed` / `closed_evolution_selfseal_task` — CYBRA Closed Evolution Self-Seal / script: `closed_evolution_selfseal_handler.sh` / source: `cybra:parliament:results`
- `executed` / `audit_dedupe_test_task` — Audit Dedupe Test / script: `audit_dedupe_test_handler.sh` / source: `cybra:parliament:results`
- `executed` / `audit_dedupe_test_task` — Audit Dedupe Test / script: `audit_dedupe_test_handler.sh` / source: `cybra:parliament:results`
- `executed` / `evo_committee_task` — CYBRA EVO Committee Creation / script: `evo_committee_handler.sh` / source: `cybra:parliament:results`
- `executed` / `biometric_succession_task` — CYBRA Test: Succession Guard / script: `biometric_succession_handler.sh` / source: `cybra:parliament:results`
- `executed` / `closed_evolution_selfseal_task` — CYBRA Test: Closed Self-Seal / script: `closed_evolution_selfseal_handler.sh` / source: `cybra:parliament:results`
- `executed` / `audit_dedupe_test_task` — CYBRA Test: Audit Dedupe / script: `audit_dedupe_test_handler.sh` / source: `cybra:parliament:results`
- `executed` / `analytics_committee_task` — CYBRA Test: Analytics Committee / script: `analytics_committee_handler.sh` / source: `cybra:parliament:results`
- `executed` / `revision_organ_task` — CYBRA Test: Revision Organ / script: `revision_organ_handler.sh` / source: `cybra:parliament:results`
- `executed` / `air_alert_task` — CYBRA Test: Air Alert Handler / script: `air_alert_handler.sh` / source: `cybra:parliament:results`
- `executed` / `revision_organ_task` — CYBRA Parliament Revision Organ / script: `revision_organ_handler.sh` / source: `cybra:parliament:results`
- `executed` / `revision_organ_task` — CYBRA Parliament Revision Organ / script: `revision_organ_handler.sh` / source: `cybra:parliament:results`
- `executed` / `analytics_committee_task` — CYBRA Parliament Analytics Committee / script: `analytics_committee_handler.sh` / source: `cybra:parliament:results`

