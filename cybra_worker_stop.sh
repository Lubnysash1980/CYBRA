#!/data/data/com.termux/files/usr/bin/bash
cd "$HOME/CYBRA" || exit 1

if [ -f logs/workers/executor_v6.pid ]; then
  kill "$(cat logs/workers/executor_v6.pid)" 2>/dev/null || true
  rm -f logs/workers/executor_v6.pid
fi

pkill -f parliament_executor_v6.py 2>/dev/null || true

echo "🛑 CYBRA worker stopped"
