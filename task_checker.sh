#!/data/data/com.termux/files/usr/bin/bash
set -e

BASE="$HOME/CYBRA"
mkdir -p posts proofs

cat > posts/task_checker_status.md <<MD
# CYBRA Task Checker

Generated: $(date)

## Queues
- submissions: $(redis-cli llen cybra:parliament:submissions)
- results: $(redis-cli llen cybra:parliament:results)
- failed: $(redis-cli llen cybra:parliament:failed)
- retry: $(redis-cli llen cybra:parliament:retry)
- audit: $(redis-cli llen cybra:audit)

## Last results
\`\`\`
$(redis-cli --raw lrange cybra:parliament:results 0 10)
\`\`\`

## Failed
\`\`\`
$(redis-cli --raw lrange cybra:parliament:failed 0 10)
\`\`\`

## Retry
\`\`\`
$(redis-cli --raw lrange cybra:parliament:retry 0 10)
\`\`\`
MD

sha256sum posts/task_checker_status.md > proofs/task_checker_hash.txt

echo "✅ Task checker created"
echo "Report: posts/task_checker_status.md"
echo "Proof: proofs/task_checker_hash.txt"
