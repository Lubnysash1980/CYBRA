#!/data/data/com.termux/files/usr/bin/bash
cd "$HOME/CYBRA"
mkdir -p logs/review
redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes
pkill -f cybra_task_review_worker.py 2>/dev/null || true
nohup python3 cybra_task_review_worker.py > logs/review/review_worker.log 2>&1 &
sleep 1
echo "✅ CYBRA review worker started"
