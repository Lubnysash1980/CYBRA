# CYBRA Task Execution Lite Test Report

Overall status: OK
Mode: lite

## Summary
executed_previously_and_ready: 6
will_execute: 0
handler_missing: 0
missing: 0

## Queues
ai_block_inbox: 0
parliament_queue: 0
parliament_failed: 0
task_blocks: 297

## Task readiness

### menubar_owner_task
Status: EXECUTED_PREVIOUSLY_AND_READY
Handler exists: True
Script exists: True
Report exists: True
Redis mapped handler: cybra_menubar_handler.sh

### it_evolution_task
Status: EXECUTED_PREVIOUSLY_AND_READY
Handler exists: True
Script exists: True
Report exists: True
Redis mapped handler: cybra_it_evolution_handler.sh

### codespace_runtime_committee_task
Status: EXECUTED_PREVIOUSLY_AND_READY
Handler exists: True
Script exists: True
Report exists: True
Redis mapped handler: cybra_codespace_runtime_handler.sh

### frozen_license_committee_task
Status: EXECUTED_PREVIOUSLY_AND_READY
Handler exists: True
Script exists: True
Report exists: True
Redis mapped handler: cybra_frozen_committee_handler.sh

### hash_license_violation_audit_task
Status: EXECUTED_PREVIOUSLY_AND_READY
Handler exists: True
Script exists: True
Report exists: True
Redis mapped handler: hash_license_guard_handler.sh

### evolution_tracker_task
Status: EXECUTED_PREVIOUSLY_AND_READY
Handler exists: True
Script exists: True
Report exists: True
Redis mapped handler: cybra_evolution_handler.sh

## Meaning
- EXECUTED_PREVIOUSLY_AND_READY: report exists, script exists, handler exists.
- WILL_EXECUTE: script/handler exists, report will be created on cycle.
- SCRIPT_EXISTS_BUT_HANDLER_MISSING: script exists, but executor mapping/handler missing.
- MISSING: script/module missing.

## Safety
heavy_cycles_auto_run: False
real_payment_now: False
automatic_SWIFT: False
automatic_external_tx: False
private_key_required: False
seed_phrase_required: False
manual_OWNER_approval_required: True

## Double SHA
6bb128cff1cdf11fc8bb71e6e9785d2f57cd68bea17269e3ae3dd575074c9a2f