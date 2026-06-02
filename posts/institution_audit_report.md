# CYBRA Parliament Institution Audit

Status: generated  
Mode: check  
Double SHA: `827c40ff7fd126af58c0321c39b91c34e5f289be4df412048747883041c9c13a`

## Summary

- Tasks checked: 96
- Task types: 34
- Executor mapping count: 53
- Required organs: 10
- Missing organs: 0
- Task types without mapping: 0
- Mapped handlers missing files: 0
- Task types without committee: 5
- Departments files: 25
- Committees files: 82
- Protection files: 3

## Organs

- ✅ `review` — parliament/review — Перевірка задач перед виконанням
- ✅ `revision` — parliament/revision — Ревізія виконаних і невиконаних задач
- ✅ `analytics` — parliament/analytics — Аналітика результатів роботи
- ✅ `education` — parliament/education — Освіта, інструкції, документація
- ✅ `evo` — parliament/evo — Створення нових комітетів і розвиток
- ✅ `evolution` — parliament/evolution — Фільтр розвитку проти деградації
- ✅ `audit` — parliament/audit — Audit, dedupe, tag logging
- ✅ `protection` — parliament/protection — Захист системи, секретів, Git, runtime
- ✅ `departments` — parliament/departments — Департаменти підтримки платформи
- ✅ `committees` — parliament/committees — Комітети під типи задач


## Statuses

- `executed`: 73
- `unknown`: 11
- `no_executor_mapping`: 8
- `failed`: 2
- `reviewed`: 2

## Task types

- `air_alert_task`: 10
- `monetization_department_task`: 7
- `owner_orchestrator_task`: 7
- `cybra_autofix_task`: 7
- `evolution_guard_task`: 6
- `kibra_token_chain_task`: 4
- `kibra_bridge_pool_task`: 3
- `finance_infrastructure_task`: 3
- `kibra_market_exchange_task`: 3
- `token_pool_ai_task`: 3
- `closed_evolution_selfseal_task`: 3
- `audit_dedupe_test_task`: 3
- `analytics_committee_task`: 3
- `revision_organ_task`: 3
- `smart_autofix_mining_pool_task`: 3
- `evolution_deployment_task`: 2
- `finance_department_task`: 2
- `existing_tasks_activation_task`: 2
- `institution_audit_task`: 2
- `biometric_succession_task`: 2
- `test`: 2
- `native_token_ecosystem_task`: 2
- `pmz_historical_metadata_task`: 2
- `None`: 2
- `ai_until_done_task`: 1
- `native_kibra_evolution_task`: 1
- `hash_module_test_task`: 1
- `evo_committee_task`: 1
- `queue_fix`: 1
- `ai_task`: 1
- `self_expanding_execution_engine_task`: 1
- `executor_autoheal_task`: 1
- `codespaces_keepalive_task`: 1
- `github_double_backend_task`: 1

## Task support matrix

- `ai_task` count=1 mapping=`evo_committee_handler.sh` handler_exists=True committee_exists=True
- `ai_until_done_task` count=1 mapping=`ai_until_done_handler.sh` handler_exists=True committee_exists=False
- `air_alert_task` count=10 mapping=`air_alert_handler.sh` handler_exists=True committee_exists=True
- `analytics_committee_task` count=3 mapping=`analytics_committee_handler.sh` handler_exists=True committee_exists=True
- `audit_dedupe_test_task` count=3 mapping=`audit_dedupe_test_handler.sh` handler_exists=True committee_exists=True
- `biometric_succession_task` count=2 mapping=`biometric_succession_handler.sh` handler_exists=True committee_exists=True
- `closed_evolution_selfseal_task` count=3 mapping=`closed_evolution_selfseal_handler.sh` handler_exists=True committee_exists=True
- `codespaces_keepalive_task` count=1 mapping=`evo_committee_handler.sh` handler_exists=True committee_exists=True
- `cybra_autofix_task` count=7 mapping=`cybra_autofix.sh` handler_exists=True committee_exists=True
- `evo_committee_task` count=1 mapping=`evo_committee_handler.sh` handler_exists=True committee_exists=True
- `evolution_deployment_task` count=2 mapping=`evolution_deployment_handler.sh` handler_exists=True committee_exists=True
- `evolution_guard_task` count=6 mapping=`evolution_guard_handler.sh` handler_exists=True committee_exists=True
- `executor_autoheal_task` count=1 mapping=`evo_committee_handler.sh` handler_exists=True committee_exists=True
- `existing_tasks_activation_task` count=2 mapping=`existing_tasks_activation_handler.sh` handler_exists=True committee_exists=True
- `finance_department_task` count=2 mapping=`finance_department_handler.sh` handler_exists=True committee_exists=True
- `finance_infrastructure_task` count=3 mapping=`finance_infrastructure_handler.sh` handler_exists=True committee_exists=False
- `github_double_backend_task` count=1 mapping=`evo_committee_handler.sh` handler_exists=True committee_exists=True
- `hash_module_test_task` count=1 mapping=`hash_module_test_handler.sh` handler_exists=True committee_exists=True
- `institution_audit_task` count=2 mapping=`institution_audit_handler.sh` handler_exists=True committee_exists=True
- `kibra_bridge_pool_task` count=3 mapping=`kibra_bridge_pool_handler.sh` handler_exists=True committee_exists=False
- `kibra_market_exchange_task` count=3 mapping=`kibra_market_exchange_handler.sh` handler_exists=True committee_exists=False
- `kibra_token_chain_task` count=4 mapping=`kibra_token_chain_handler.sh` handler_exists=True committee_exists=True
- `monetization_department_task` count=7 mapping=`monetization_department_handler.sh` handler_exists=True committee_exists=True
- `native_kibra_evolution_task` count=1 mapping=`native_kibra_evolution_handler.sh` handler_exists=True committee_exists=False
- `native_token_ecosystem_task` count=2 mapping=`create_native_token_ecosystem.sh` handler_exists=True committee_exists=True
- `owner_orchestrator_task` count=7 mapping=`owner_orchestrator_handler.sh` handler_exists=True committee_exists=True
- `pmz_historical_metadata_task` count=2 mapping=`create_pmz_registry.sh` handler_exists=True committee_exists=True
- `queue_fix` count=1 mapping=`evo_committee_handler.sh` handler_exists=True committee_exists=True
- `revision_organ_task` count=3 mapping=`revision_organ_handler.sh` handler_exists=True committee_exists=True
- `self_expanding_execution_engine_task` count=1 mapping=`evo_committee_handler.sh` handler_exists=True committee_exists=True
- `smart_autofix_mining_pool_task` count=3 mapping=`cybra_mining_autofix.sh` handler_exists=True committee_exists=True
- `test` count=2 mapping=`evo_committee_handler.sh` handler_exists=True committee_exists=True
- `token_pool_ai_task` count=3 mapping=`token_pool_ai_handler.sh` handler_exists=True committee_exists=True


## Recommendations

- **development**: Для частини task types немає окремих комітетів. Action: `Запусти repair, щоб створити committee skeleton.`

