#!/data/data/com.termux/files/usr/bin/bash
set -e

mkdir -p logs/workers posts proofs

redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes
sleep 1

cat > cybra_worker_start.sh <<'BASH'
#!/data/data/com.termux/files/usr/bin/bash
cd "$HOME/CYBRA" || exit 1

redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes
sleep 1

nohup python3 parliament_executor_v6.py > logs/workers/executor_v6.log 2>&1 &

echo $! > logs/workers/executor_v6.pid

echo "✅ CYBRA worker started"
echo "PID: $(cat logs/workers/executor_v6.pid)"
BASH

cat > cybra_worker_stop.sh <<'BASH'
#!/data/data/com.termux/files/usr/bin/bash
cd "$HOME/CYBRA" || exit 1

if [ -f logs/workers/executor_v6.pid ]; then
  kill "$(cat logs/workers/executor_v6.pid)" 2>/dev/null || true
  rm -f logs/workers/executor_v6.pid
fi

pkill -f parliament_executor_v6.py 2>/dev/null || true

echo "🛑 CYBRA worker stopped"
BASH

cat > cybra_worker_status.sh <<'BASH'
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
BASH

chmod +x cybra_worker_start.sh cybra_worker_stop.sh cybra_worker_status.sh

cat > posts/cybra_workers_status.md <<'MD'
# CYBRA Workers

Installed:
- cybra_worker_start.sh
- cybra_worker_stop.sh
- cybra_worker_status.sh

Worker:
- parliament_executor_v6.py

Mode:
- background execution
- Redis queue listener
- auto task processing
MD

sha256sum cybra_worker_start.sh cybra_worker_stop.sh cybra_worker_status.sh > proofs/cybra_workers.sha256

git add cybra_worker_start.sh cybra_worker_stop.sh cybra_worker_status.sh posts proofs cybra_workers_autofix.sh
git commit -m "add CYBRA background workers" || true

echo "✅ Workers installed"
