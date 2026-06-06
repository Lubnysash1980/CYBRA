#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA" || exit 1
mkdir -p logs/mihailka runtime/redis

if ! redis-cli ping >/dev/null 2>&1; then
  redis-server --daemonize yes \
    --bind 127.0.0.1 \
    --port 6379 \
    --dir "$HOME/CYBRA/runtime/redis" \
    --save "" \
    --appendonly no >/dev/null 2>&1 || true
fi

bash scripts/termux/cybra_termux_patch_runner.sh > logs/mihailka/mihailka_patch.log 2>&1 || true
python3 scripts/oracle/cybra_oracle_agent.py > logs/mihailka/mihailka_status.log 2>&1 || true

echo "✅ Mihailka local autostart done"
echo "Run menu: cybra-bar"
