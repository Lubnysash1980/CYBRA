#!/data/data/com.termux/files/usr/bin/bash
set -e

BASE="$HOME/CYBRA"
mkdir -p "$BASE/remote_queue"

ID="task_codespace_keepalive_$(date +%Y%m%d_%H%M%S).task"

cat > "$BASE/remote_queue/$ID" <<'TASK'
echo "=== CYBRA Codespaces keepalive ==="
date
git status
bash cybra_test_pipeline.sh 2>/dev/null || true
TASK

git add "remote_queue/$ID"
git commit -m "Codespaces keepalive task $ID" || true
git push || true

echo "✅ Codespaces keepalive task queued: $ID"
