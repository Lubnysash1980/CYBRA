#!/usr/bin/env bash
set +e
cd "$HOME/CYBRA" || cd "$(pwd)" || exit 1

mkdir -p logs/oracle public/cybra_oracle_dashboard data/cybra_oracle/reports data/cybra_mgs/tasks

echo "=== CYBRA ORACLE VPS START ==="

python3 scripts/oracle/cybra_oracle_agent.py || true

if ! pgrep -f "http.server 8099" >/dev/null 2>&1; then
  nohup python3 -m http.server 8099 --bind 0.0.0.0 --directory public/cybra_oracle_dashboard \
    > logs/oracle/dashboard_server.log 2>&1 &
  echo "✅ Dashboard server started on :8099"
else
  echo "✅ Dashboard server already running"
fi

if ! pgrep -f "cybra_oracle_agent.py daemon" >/dev/null 2>&1; then
  nohup python3 scripts/oracle/cybra_oracle_agent.py daemon \
    > logs/oracle/oracle_agent_daemon.log 2>&1 &
  echo "✅ Oracle agent daemon started"
else
  echo "✅ Oracle agent daemon already running"
fi

echo "Open: http://YOUR_ORACLE_IP:8099/"
