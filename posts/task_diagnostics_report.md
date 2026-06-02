# CYBRA Task Test Diagnostics

Status: generated  
Double SHA: `507a6245ff0a35a481df239cdd231be700ac222370888916e06c002db9a4dd2d`

## Summary

- Checked records: 38
- Executed: 26
- Not executed: 9
- Still missing mapping: 0
- Old no-mapping already fixed now: 9
- Failed/Error: 0
- Review rejected: 2
- Review hold: 0
- Evolution hold: 0
- Evolution rejected: 0
- Executor mapping count: 37

## Queue state

- parliament_queue: 6
- parliament_results: 34
- parliament_failed: 1
- review_incoming: 0
- review_approved: 1
- review_hold: 0
- review_rejected: 2
- evolution_approved: 0
- evolution_hold: 0
- evolution_rejected: 0

## Statuses

- `executed`: 26
- `no_executor_mapping`: 9
- `reviewed`: 2
- `unknown`: 1

## Task types

- `air_alert_task`: 9
- `cybra_autofix_task`: 7
- `smart_autofix_mining_pool_task`: 3
- `revision_organ_task`: 2
- `analytics_committee_task`: 2
- `test`: 2
- `native_token_ecosystem_task`: 2
- `self_expanding_execution_engine_task`: 2
- `pmz_historical_metadata_task`: 2
- `None`: 2
- `queue_fix`: 1
- `ai_task`: 1
- `executor_autoheal_task`: 1
- `codespaces_keepalive_task`: 1
- `github_double_backend_task`: 1

## Scripts / handlers

- `none`: 12
- `air_alert_handler.sh`: 7
- `cybra_autofix.sh`: 4
- `['bash', 'cybra_autofix.sh']`: 3
- `['bash', 'cybra_mining_autofix.sh']`: 3
- `revision_organ_handler.sh`: 2
- `analytics_committee_handler.sh`: 2
- `['bash', 'create_pmz_registry.sh']`: 2
- `ai_chat_test_handler.sh`: 1
- `create_native_token_ecosystem.sh`: 1
- `['bash', 'create_native_token_ecosystem.sh']`: 1

## Sources

- `cybra:parliament:results`: 34
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

- `executed` / `revision_organ_task` — CYBRA Parliament Revision Organ / script: `revision_organ_handler.sh` / source: `cybra:parliament:results`
- `executed` / `revision_organ_task` — CYBRA Parliament Revision Organ / script: `revision_organ_handler.sh` / source: `cybra:parliament:results`
- `executed` / `analytics_committee_task` — CYBRA Parliament Analytics Committee / script: `analytics_committee_handler.sh` / source: `cybra:parliament:results`
- `executed` / `analytics_committee_task` — CYBRA Parliament Analytics Committee / script: `analytics_committee_handler.sh` / source: `cybra:parliament:results`
- `executed` / `air_alert_task` — Ракетна небезпека Redis Mapping Test / script: `air_alert_handler.sh` / source: `cybra:parliament:results`
- `executed` / `air_alert_task` — Ракетна небезпека / script: `air_alert_handler.sh` / source: `cybra:parliament:results`
- `executed` / `air_alert_task` — Ракетна небезпека через орган перевірки / script: `air_alert_handler.sh` / source: `cybra:parliament:results`
- `executed` / `air_alert_task` — Ракетна небезпека / script: `air_alert_handler.sh` / source: `cybra:parliament:results`
- `executed` / `air_alert_task` — Ракетна небезпека / script: `air_alert_handler.sh` / source: `cybra:parliament:results`
- `executed` / `air_alert_task` — Ракетна небезпека / script: `air_alert_handler.sh` / source: `cybra:parliament:results`
- `executed` / `air_alert_task` — Ракетна небезпека / script: `air_alert_handler.sh` / source: `cybra:parliament:results`
- `no_executor_mapping` / `air_alert_task` — Ракетна небезпека / script: `None` / source: `cybra:parliament:results`
- `executed` / `cybra_autofix_task` — Ракетна небезпека / script: `cybra_autofix.sh` / source: `cybra:parliament:results`
- `no_executor_mapping` / `queue_fix` — test / script: `None` / source: `cybra:parliament:results`
- `executed` / `cybra_autofix_task` — Air Alert Monitoring / script: `cybra_autofix.sh` / source: `cybra:parliament:results`

