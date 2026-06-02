# CYBRA Existing Tasks Evolution Activation

Status: generated  
Mode: report  
Score: **98/100**  
Double SHA: `adce4070070ec04b9b28cdec2ce17ae81b549cbfa4d2dfe1185ef1fb0d45e083`

## Redis

- Queue: 0
- Results: 64
- Failed: 0
- Failed archive: 3
- Mapping count: 47

## Summary

- Records checked: 73
- Task types: 29
- Missing mapping: 0
- Missing handler: 0
- Failed validation: 0
- Missing committee: 1

## Support matrix

- `None` count=2 mapping=`None` handler_exists=False validation=False committee=False
- `ai_task` count=1 mapping=`evo_committee_handler.sh` handler_exists=True validation=True committee=True
- `air_alert_task` count=10 mapping=`air_alert_handler.sh` handler_exists=True validation=True committee=True
- `analytics_committee_task` count=3 mapping=`analytics_committee_handler.sh` handler_exists=True validation=True committee=True
- `audit_dedupe_test_task` count=3 mapping=`audit_dedupe_test_handler.sh` handler_exists=True validation=True committee=True
- `biometric_succession_task` count=2 mapping=`biometric_succession_handler.sh` handler_exists=True validation=True committee=True
- `closed_evolution_selfseal_task` count=3 mapping=`closed_evolution_selfseal_handler.sh` handler_exists=True validation=True committee=True
- `codespaces_keepalive_task` count=1 mapping=`evo_committee_handler.sh` handler_exists=True validation=True committee=True
- `cybra_autofix_task` count=7 mapping=`cybra_autofix.sh` handler_exists=True validation=True committee=True
- `evo_committee_task` count=1 mapping=`evo_committee_handler.sh` handler_exists=True validation=True committee=True
- `evolution_deployment_task` count=1 mapping=`evolution_deployment_handler.sh` handler_exists=True validation=True committee=True
- `evolution_guard_task` count=6 mapping=`evolution_guard_handler.sh` handler_exists=True validation=True committee=True
- `executor_autoheal_task` count=1 mapping=`evo_committee_handler.sh` handler_exists=True validation=True committee=True
- `existing_tasks_activation_task` count=1 mapping=`existing_tasks_activation_handler.sh` handler_exists=True validation=True committee=False
- `finance_department_task` count=1 mapping=`finance_department_handler.sh` handler_exists=True validation=True committee=True
- `github_double_backend_task` count=1 mapping=`evo_committee_handler.sh` handler_exists=True validation=True committee=True
- `hash_module_test_task` count=1 mapping=`hash_module_test_handler.sh` handler_exists=True validation=True committee=True
- `institution_audit_task` count=2 mapping=`institution_audit_handler.sh` handler_exists=True validation=True committee=True
- `kibra_token_chain_task` count=3 mapping=`kibra_token_chain_handler.sh` handler_exists=True validation=True committee=True
- `monetization_department_task` count=4 mapping=`monetization_department_handler.sh` handler_exists=True validation=True committee=True
- `native_token_ecosystem_task` count=2 mapping=`create_native_token_ecosystem.sh` handler_exists=True validation=True committee=True
- `owner_orchestrator_task` count=3 mapping=`owner_orchestrator_handler.sh` handler_exists=True validation=True committee=True
- `pmz_historical_metadata_task` count=2 mapping=`create_pmz_registry.sh` handler_exists=True validation=True committee=True
- `queue_fix` count=1 mapping=`evo_committee_handler.sh` handler_exists=True validation=True committee=True
- `revision_organ_task` count=3 mapping=`revision_organ_handler.sh` handler_exists=True validation=True committee=True
- `self_expanding_execution_engine_task` count=1 mapping=`evo_committee_handler.sh` handler_exists=True validation=True committee=True
- `smart_autofix_mining_pool_task` count=3 mapping=`cybra_mining_autofix.sh` handler_exists=True validation=True committee=True
- `test` count=2 mapping=`evo_committee_handler.sh` handler_exists=True validation=True committee=True
- `token_pool_ai_task` count=2 mapping=`token_pool_ai_handler.sh` handler_exists=True validation=True committee=True


## Recommendations

- **repair**: Some existing tasks still need mapping/handler/committee repair. Action: `Run: bash cybra_existing_tasks.sh repair`

