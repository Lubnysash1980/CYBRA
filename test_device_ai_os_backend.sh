#!/data/data/com.termux/files/usr/bin/bash
set -e

cd "$HOME/CYBRA"

node gitcybrahash_double_backend.mjs
sha256sum -c proofs/ai_os_engine.sha256

test -f hash_storage/root_hash.json
test -f feeds/ai_os_engine.json
test -f posts/ai_os_engine_status.md
test -d parliament/tasks

echo "✅ CYBRA AI OS backend test PASSED"
