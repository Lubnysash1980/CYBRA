#!/data/data/com.termux/files/usr/bin/bash
cd "$HOME/CYBRA" || exit 0
mkdir -p logs/control_bar runtime/redis

if ! redis-cli ping >/dev/null 2>&1; then
  redis-server --daemonize yes \
    --bind 127.0.0.1 \
    --port 6379 \
    --dir "$HOME/CYBRA/runtime/redis" \
    --save "" \
    --appendonly no >/dev/null 2>&1 || true
  sleep 1
fi

bash scripts/termux/cybra_termux_patch_runner.sh > logs/control_bar/termux_boot_patch.log 2>&1 || true
python3 scripts/oracle/cybra_oracle_agent.py > logs/control_bar/termux_boot_status.log 2>&1 || true
