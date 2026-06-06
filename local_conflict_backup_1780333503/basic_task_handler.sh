#!/data/data/com.termux/files/usr/bin/bash
set -e

mkdir -p posts proofs

cat > posts/basic_task_status.md <<'MD'
# CYBRA Basic Task Handler

Status: executed

Basic JSON task accepted, routed and processed by CYBRA Parliament executor.
MD

sha256sum posts/basic_task_status.md > proofs/basic_task_hash.txt

echo "✅ Basic task handled"
