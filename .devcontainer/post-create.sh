#!/usr/bin/env bash
set +e

cd /workspaces/CYBRA || exit 0

echo "=== CYBRA Codespace Runtime post-create ==="

mkdir -p runtime/redis logs posts feeds proofs data "$HOME"
rm -rf "$HOME/CYBRA"
ln -s /workspaces/CYBRA "$HOME/CYBRA"

export CYBRA_WORKDIR="/workspaces/CYBRA"

redis-server --daemonize yes --bind 127.0.0.1 --port 6379 --dir "/workspaces/CYBRA/runtime/redis" --save "" --appendonly no || true
sleep 1
redis-cli ping || true

find . -maxdepth 2 -type f \( -name "*.sh" -o -path "./bin/*" \) -exec chmod +x {} \; 2>/dev/null || true

python3 -m py_compile cybra_codespace_runtime.py 2>/dev/null || true

bash cybra_codespace_runtime.sh cycle codespace-post-create || true
bash cybra_codespace_runtime.sh start-watch 180 || true

echo "✅ CYBRA Codespace Runtime ready"
echo "Dashboard:"
echo "bash cybra_codespace_runtime.sh dashboard"
