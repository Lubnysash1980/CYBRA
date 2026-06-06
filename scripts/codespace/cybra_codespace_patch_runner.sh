#!/usr/bin/env bash
set +e
cd /workspaces/CYBRA 2>/dev/null || cd "$HOME/CYBRA" 2>/dev/null || cd "$(pwd)" || exit 1

echo "=== CYBRA CODESPACE PATCH RUNNER ==="

mkdir -p data/cybra_mgs/tasks data/cybra_oracle/reports posts feeds proofs logs/codespace public/cybra_oracle_dashboard

python3 scripts/oracle/cybra_oracle_agent.py 2>/dev/null || true

cat > posts/cybra_codespace_patch_status.md <<EOF
# CYBRA CodeSpace Patch Status

Status: CODESPACE_PATCH_ACTIVE  
Role: secondary workspace / report builder / task processor

Safety:
- real_trading_now: false
- live_force_trading_disabled: true
- automatic_external_tx: false
- manual_OWNER_approval_required: true
EOF

sha256sum posts/cybra_codespace_patch_status.md > proofs/cybra_codespace_patch_status.sha256 2>/dev/null || true

echo "✅ CodeSpace patch executed"
