#!/data/data/com.termux/files/usr/bin/bash
redis-cli ping
echo "REVIEW_INCOMING: $(redis-cli LLEN cybra:review:incoming)"
echo "REVIEW_APPROVED: $(redis-cli LLEN cybra:review:approved)"
echo "REVIEW_HOLD: $(redis-cli LLEN cybra:review:hold)"
echo "REVIEW_REJECTED: $(redis-cli LLEN cybra:review:rejected)"
echo "REVIEW_AUDIT: $(redis-cli LLEN cybra:review:audit)"
echo "EXECUTION_QUEUE: $(redis-cli LLEN cybra:parliament:queue)"
pgrep -af cybra_task_review_worker.py || echo "NO_REVIEW_WORKER"
