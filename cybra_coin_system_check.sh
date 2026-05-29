#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "=== WORKER ==="
ps aux | grep parliament_executor_v6.py | grep -v grep || echo "NO_WORKER"

echo
echo "=== REDIS ==="
redis-cli ping || true

echo
echo "=== QUEUES ==="
cybra status || true

echo
echo "=== COIN TASK RESULTS ==="
cybra results | grep "CYBRA Coin Completion" || true

echo
echo "=== COIN FILES ==="
ls -lh token/coin/ 2>/dev/null || true
ls -lh token/assets/ 2>/dev/null || true
ls -lh token/deploy/solana_devnet/ 2>/dev/null || true

echo
echo "=== PROOF CHECK ==="
sha256sum -c proofs/cybra_coin_completion.sha256 || true

echo
echo "=== EXECUTOR MAP ==="
grep -n "cybra_coin_completion_task\|native_token_evolution_task\|github_pages_task\|workers_task" parliament_executor_v6.py || true

echo
echo "=== GIT STATUS ==="
git status --short | head -80
