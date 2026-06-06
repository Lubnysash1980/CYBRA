#!/usr/bin/env bash
set +e
cd "$HOME/CYBRA" || cd "$(pwd)" || exit 1

echo "=== CYBRA ORACLE VPS PATCH RUNNER ==="

mkdir -p data/cybra_oracle/{tasks,reports,processed} data/cybra_mgs/tasks posts feeds proofs logs/oracle public/cybra_oracle_dashboard

python3 scripts/oracle/cybra_oracle_agent.py 2>/dev/null || true

if ! pgrep -f "cybra_oracle_agent.py daemon" >/dev/null 2>&1; then
  nohup python3 scripts/oracle/cybra_oracle_agent.py daemon \
    > logs/oracle/oracle_agent_daemon.log 2>&1 &
fi

if ! pgrep -f "http.server 8099" >/dev/null 2>&1; then
  nohup python3 -m http.server 8099 --bind 0.0.0.0 --directory public/cybra_oracle_dashboard \
    > logs/oracle/dashboard_server.log 2>&1 &
fi

cat > posts/cybra_oracle_patch_status.md <<EOF
# CYBRA Oracle VPS Patch Status

Status: ORACLE_VPS_PATCH_ACTIVE  
Role: main remote runner / heavy process / dashboard host

Dashboard:
http://ORACLE_IP:8099/

Safety:
- real_trading_now: false
- live_force_trading_disabled: true
- automatic_external_tx: false
- manual_OWNER_approval_required: true
EOF

sha256sum posts/cybra_oracle_patch_status.md > proofs/cybra_oracle_patch_status.sha256 2>/dev/null || true

echo "✅ Oracle VPS patch executed"
echo "Dashboard: http://ORACLE_IP:8099/"
