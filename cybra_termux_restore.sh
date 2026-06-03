#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA" || exit 1

echo "=== CYBRA TERMUX SAFE RESTORE ==="

mkdir -p runtime/redis logs posts feeds proofs data

if ! redis-cli ping >/dev/null 2>&1; then
  redis-server \
    --daemonize yes \
    --bind 127.0.0.1 \
    --port 6379 \
    --dir "$HOME/CYBRA/runtime/redis" \
    --save "" \
    --appendonly no >/dev/null 2>&1 || true
  sleep 1
fi

find . -maxdepth 2 -type f \( -name "*.sh" -o -path "./bin/*" \) -exec chmod +x {} \; 2>/dev/null || true

[ -f cybra_recovery.sh ] && bash cybra_recovery.sh report || true
[ -f cybra_autoheal.sh ] && bash cybra_autoheal.sh cycle || true
[ -f cybra_security_analytics.sh ] && bash cybra_security_analytics.sh cycle || true
[ -f cybra_conformation8.sh ] && bash cybra_conformation8.sh cycle || true
[ -f cybra_menubar.sh ] && bash cybra_menubar.sh report || true
[ -f cybra_codespace_runtime.sh ] && bash cybra_codespace_runtime.sh cycle restore || true

echo "✅ CYBRA restore cycle done"
