#!/usr/bin/env bash
set +e

cd /workspaces/CYBRA || exit 0

echo "=== CYBRA Codespaces post-create ==="

mkdir -p "$HOME/CYBRA" runtime/redis logs posts feeds proofs data
rm -rf "$HOME/CYBRA"
ln -s /workspaces/CYBRA "$HOME/CYBRA"

redis-server --daemonize yes --bind 127.0.0.1 --port 6379 --dir "$HOME/CYBRA/runtime/redis" --save "" --appendonly no || true
sleep 1
redis-cli ping || true

find . -maxdepth 2 -type f \( -name "*.sh" -o -path "./bin/*" \) -exec chmod +x {} \; 2>/dev/null || true

python3 -m py_compile cybra_github_autonomy.py 2>/dev/null || true

bash github_autonomous_cycle.sh codespaces || true

echo "✅ CYBRA Codespaces ready"
echo "Run dashboard if needed:"
echo "bash cybra_dashboard.sh start 8099 127.0.0.1"
