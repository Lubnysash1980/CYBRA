#!/data/data/com.termux/files/usr/bin/bash
cd "$HOME/CYBRA" || exit 1

echo "=== WORKER ==="
ps aux | grep parliament_executor_v6.py | grep -v grep || echo "not running"

echo
echo "=== REDIS ==="
redis-cli ping 2>/dev/null || echo "redis not running"

echo
echo "=== QUEUES ==="
cybra status

echo
echo "=== LOG ==="
tail -20 logs/workers/executor_v6.log 2>/dev/null || true
