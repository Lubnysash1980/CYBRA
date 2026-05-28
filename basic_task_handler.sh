#!/data/data/com.termux/files/usr/bin/bash
set -e

mkdir -p posts proofs

cat > posts/basic_task_status.md <<MD
# Basic Task Handler

Status: executed

Time:
$(date -Iseconds)
MD

sha256sum posts/basic_task_status.md > proofs/basic_task_status.sha256

echo "✅ Basic task handled"
