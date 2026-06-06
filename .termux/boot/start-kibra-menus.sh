#!/data/data/com.termux/files/usr/bin/bash
cd "$HOME/CYBRA" || exit 0
mkdir -p logs/kibra_menu runtime/redis

if ! redis-cli ping >/dev/null 2>&1; then
  redis-server --daemonize yes \
    --bind 127.0.0.1 \
    --port 6379 \
    --dir "$HOME/CYBRA/runtime/redis" \
    --save "" \
    --appendonly no >/dev/null 2>&1 || true
  sleep 1
fi

echo "$(date -Iseconds) KIBRA menus boot OK" >> logs/kibra_menu/boot.log
