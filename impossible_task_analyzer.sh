#!/data/data/com.termux/files/usr/bin/bash
set -e

redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes
sleep 1

mkdir -p posts proofs

cat > posts/impossible_task_analysis.md <<EOF
# CYBRA Impossible / Unfinished Task Analysis

Generated: $(date)

## Queues
- submissions: $(redis-cli llen cybra:parliament:submissions)
- retry: $(redis-cli llen cybra:parliament:retry)
- failed: $(redis-cli llen cybra:parliament:failed)
- results: $(redis-cli llen cybra:parliament:results)
- audit: $(redis-cli llen cybra:audit)

## Unfinished
\`\`\`
$(redis-cli --raw lrange cybra:parliament:submissions 0 20)
\`\`\`

## Retry
\`\`\`
$(redis-cli --raw lrange cybra:parliament:retry 0 20)
\`\`\`

## Failed
\`\`\`
$(redis-cli --raw lrange cybra:parliament:failed 0 20)
\`\`\`

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
EOF

sha256sum posts/impossible_task_analysis.md > proofs/impossible_task_analysis.sha256

cat posts/impossible_task_analysis.md
