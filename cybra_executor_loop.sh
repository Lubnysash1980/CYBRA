#!/data/data/com.termux/files/usr/bin/bash
set -e

cd "$HOME/CYBRA"
mkdir -p logs

echo "=== CYBRA EXECUTOR LOOP STARTED ==="

while true; do
  python3 parliament_executor_v6.py >> logs/parliament_v6.log 2>&1 || true
  sleep 3
done
