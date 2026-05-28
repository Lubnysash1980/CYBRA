#!/data/data/com.termux/files/usr/bin/bash
cd "$HOME/CYBRA" || exit 1

redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes
sleep 1

nohup python3 parliament_executor_v6.py > logs/workers/executor_v6.log 2>&1 &

echo $! > logs/workers/executor_v6.pid

echo "✅ CYBRA worker started"
echo "PID: $(cat logs/workers/executor_v6.pid)"
