#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA" || exit 1

mkdir -p logs/control_bar data/cybra_control_bar/status posts feeds proofs runtime/redis

if ! redis-cli ping >/dev/null 2>&1; then
  redis-server --daemonize yes \
    --bind 127.0.0.1 \
    --port 6379 \
    --dir "$HOME/CYBRA/runtime/redis" \
    --save "" \
    --appendonly no >/dev/null 2>&1 || true
  sleep 1
fi

python3 scripts/oracle/cybra_oracle_agent.py 2>/dev/null || true

cat > posts/cybra_termux_patch_status.md <<EOF
# CYBRA Android Termux Patch Status

Status: TERMUX_CONTROL_BAR_ACTIVE  
Role: Android menu-bar / task sender / Oracle-GitHub-CodeSpace controller

Safety:
- real_trading_now: false
- live_force_trading_disabled: true
- automatic_external_tx: false
- manual_OWNER_approval_required: true
EOF

sha256sum posts/cybra_termux_patch_status.md > proofs/cybra_termux_patch_status.sha256 2>/dev/null || true

echo "✅ Termux patch active"
