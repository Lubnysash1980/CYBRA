# CYBRA Impossible / Unfinished Task Analysis

Generated: Wed May 27 00:29:46 EEST 2026

## Queues
- submissions: 0
- retry: 0
- failed: 1
- results: 1153
- audit: 1151

## Unfinished
```

```

## Retry
```

```

## Failed
```
{"topic": "CYBRA Self-Expanding Execution Engine", "type": "self_expanding_execution_engine_task", "status": "no_executor_mapping", "double_sha": "1acd9e2986856526abe474c9315dcce4c821b8c8521b0db38e09fa33c958e476", "retries": 3}
```

## Complexity classification
- 0 queue / 0 retry / 0 failed = низька складність, все виконано.
- є queue = очікує executor.
- є retry = середня/висока складність, потрібен повтор.
- є failed = висока складність або немає handler/mapping/script.
- no_executor_mapping = треба створити handler.
- script_not_found = треба створити скрипт або hash-restore.
- execution_failed = треба autofix/debug.

## Decision
Якщо failed/retry > 0 — запускати executor_quality_autofix.sh.
