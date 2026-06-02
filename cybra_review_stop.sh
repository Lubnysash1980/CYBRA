#!/data/data/com.termux/files/usr/bin/bash
pkill -f cybra_task_review_worker.py 2>/dev/null || true
echo "✅ CYBRA review worker stopped"
