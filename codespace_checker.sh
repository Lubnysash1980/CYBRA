#!/data/data/com.termux/files/usr/bin/bash
set -e

BASE="$HOME/CYBRA"
mkdir -p remote_queue remote_results remote_logs posts proofs

ID="codespace_check_$(date +%Y%m%d_%H%M%S).task"

cat > "remote_queue/$ID" <<'TASK'
echo "CYBRA Codespaces checker OK"
date
pwd
ls
TASK

git add "remote_queue/$ID"
git commit -m "codespace checker task $ID" || true
git push || true

cat > posts/codespace_checker_status.md <<MD
# CYBRA Codespaces Checker

Task sent:
$ID

Now Codespaces listener must:
1. git pull
2. execute remote_queue/$ID
3. write remote_results/$ID.result
4. git push result back

Check later:
cybra-codespace-check-result $ID
MD

echo "$ID" > proofs/last_codespace_check_task.txt

echo "✅ Codespaces check task sent: $ID"
echo "Check after 30-60 seconds:"
echo "  bash codespace_check_result.sh $ID"
