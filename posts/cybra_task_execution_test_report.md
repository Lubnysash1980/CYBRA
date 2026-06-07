# CYBRA Task Execution Lite Test Report

Overall status: OK
Mode: lite

## Summary
executed_previously_and_ready: 6
will_execute: 0
handler_missing: 0
missing: 0

## Queues
ai_block_inbox: 1
parliament_queue: 1
parliament_failed: 0
task_blocks: 312

## Task readiness

### menubar_owner_task
Status: EXECUTED_PREVIOUSLY_AND_READY
Handler exists: True
Script exists: True
Report exists: True
Redis mapped handler: none

### it_evolution_task
Status: EXECUTED_PREVIOUSLY_AND_READY
Handler exists: True
Script exists: True
Report exists: True
Redis mapped handler: none

### codespace_runtime_committee_task
Status: EXECUTED_PREVIOUSLY_AND_READY
Handler exists: True
Script exists: True
Report exists: True
Redis mapped handler: none

### frozen_license_committee_task
Status: EXECUTED_PREVIOUSLY_AND_READY
Handler exists: True
Script exists: True
Report exists: True
Redis mapped handler: none

### hash_license_violation_audit_task
Status: EXECUTED_PREVIOUSLY_AND_READY
Handler exists: True
Script exists: True
Report exists: True
Redis mapped handler: none

### evolution_tracker_task
Status: EXECUTED_PREVIOUSLY_AND_READY
Handler exists: True
Script exists: True
Report exists: True
Redis mapped handler: none

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
cb559fc92d1ee089c08ae698cb5642d3f9c4eef855a03950510e664f539ce192