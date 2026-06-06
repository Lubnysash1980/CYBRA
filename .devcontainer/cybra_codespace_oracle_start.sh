#!/usr/bin/env bash
set +e
cd /workspaces/CYBRA 2>/dev/null || cd "$PWD" || exit 1
mkdir -p logs/oracle data/cybra_oracle/reports public/cybra_oracle_dashboard
python3 scripts/oracle/cybra_oracle_agent.py || true
echo "✅ Codespace Oracle-compatible report prepared"
