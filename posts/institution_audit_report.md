# CYBRA Parliament Institution Audit

Status: generated  
Mode: repair  
Double SHA: `c04c1ba56ac10e9b95bd185bd3d56665804e7bdce0f02542a8f64df2b441b521`

## Summary

- Tasks checked: 56
- Task types: 20
- Executor mapping count: 40
- Required organs: 10
- Missing organs: 1
- Task types without mapping: 0
- Mapped handlers missing files: 0
- Task types without committee: 19
- Departments files: 16
- Committees files: 62
- Protection files: 2

## Organs

- ✅ `review` — parliament/review — Перевірка задач перед виконанням
- ✅ `revision` — parliament/revision — Ревізія виконаних і невиконаних задач
- ✅ `analytics` — parliament/analytics — Аналітика результатів роботи
- ❌ `education` — parliament/education — Освіта, інструкції, документація
- ✅ `evo` — parliament/evo — Створення нових комітетів і розвиток
- ✅ `evolution` — parliament/evolution — Фільтр розвитку проти деградації
- ✅ `audit` — parliament/audit — Audit, dedupe, tag logging
- ✅ `protection` — parliament/protection — Захист системи, секретів, Git, runtime
- ✅ `departments` — parliament/departments — Департаменти підтримки платформи
- ✅ `committees` — parliament/committees — Комітети під типи задач


## Statuses

- `executed`: 38
- `no_executor_mapping`: 9
- `unknown`: 7
- `reviewed`: 2

## Task types

- `air_alert_task`: 10
- `cybra_autofix_task`: 7
- `evolution_guard_task`: 6
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

## Task support matrix

- `ai_task` count=1 mapping=`evo_committee_handler.sh` handler_exists=True committee_exists=False
- `air_alert_task` count=10 mapping=`air_alert_handler.sh` handler_exists=True committee_exists=False
- `analytics_committee_task` count=3 mapping=`analytics_committee_handler.sh` handler_exists=True committee_exists=False
- `audit_dedupe_test_task` count=3 mapping=`audit_dedupe_test_handler.sh` handler_exists=True committee_exists=False
- `biometric_succession_task` count=2 mapping=`biometric_succession_handler.sh` handler_exists=True committee_exists=False
- `closed_evolution_selfseal_task` count=3 mapping=`closed_evolution_selfseal_handler.sh` handler_exists=True committee_exists=False
- `codespaces_keepalive_task` count=1 mapping=`evo_committee_handler.sh` handler_exists=True committee_exists=False
- `cybra_autofix_task` count=7 mapping=`cybra_autofix.sh` handler_exists=True committee_exists=False
- `evo_committee_task` count=1 mapping=`evo_committee_handler.sh` handler_exists=True committee_exists=False
- `evolution_guard_task` count=6 mapping=`evolution_guard_handler.sh` handler_exists=True committee_exists=False
- `executor_autoheal_task` count=1 mapping=`evo_committee_handler.sh` handler_exists=True committee_exists=False
- `github_double_backend_task` count=1 mapping=`evo_committee_handler.sh` handler_exists=True committee_exists=False
- `native_token_ecosystem_task` count=2 mapping=`create_native_token_ecosystem.sh` handler_exists=True committee_exists=False
- `pmz_historical_metadata_task` count=2 mapping=`create_pmz_registry.sh` handler_exists=True committee_exists=False
- `queue_fix` count=1 mapping=`evo_committee_handler.sh` handler_exists=True committee_exists=False
- `revision_organ_task` count=3 mapping=`revision_organ_handler.sh` handler_exists=True committee_exists=False
- `self_expanding_execution_engine_task` count=2 mapping=`evo_committee_handler.sh` handler_exists=True committee_exists=False
- `smart_autofix_mining_pool_task` count=3 mapping=`cybra_mining_autofix.sh` handler_exists=True committee_exists=False
- `test` count=2 mapping=`evo_committee_handler.sh` handler_exists=True committee_exists=False


## Recommendations

- **critical**: Не всі базові органи Кіберапарламенту існують. Action: `Запусти repair: bash cybra_institution.sh repair`
- **development**: Для частини task types немає окремих комітетів. Action: `Запусти repair, щоб створити committee skeleton.`

