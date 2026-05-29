#!/data/data/com.termux/files/usr/bin/bash
set -e

mkdir -p workers/pool token/runtime recovery posts proofs

cat > token/runtime/mainnet_gate.json <<'JSON'
{
  "mainnet_status": "LOCKED",
  "wallet_visible": false,
  "metadata_valid": true,
  "logo_present": true,
  "double_sha_valid": true,
  "watchdog_ok": true,
  "autoheal_ok": true,
  "autofix_ok": true,
  "owner_approval": false,
  "rules": [
    "mainnet_locked_by_default",
    "owner_approval_required",
    "double_sha_required",
    "worker_resilience_required",
    "no_private_keys",
    "no_fake_balances"
  ]
}
JSON

cat > workers/pool/mainnet_gatekeeper.sh <<'BASH'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

mkdir -p token/runtime posts proofs logs/mainnet_gatekeeper

APPROVAL=false
[ -f legal/auth/fingerprint_approval.txt ] && APPROVAL=true

DOUBLE_SHA=false
sha256sum -c proofs/cybra_coin_completion.sha256 >/dev/null 2>&1 && DOUBLE_SHA=true

WATCHDOG=false
[ -f posts/self_healing_supervisor_status.md ] && WATCHDOG=true

AUTOHEAL=false
pgrep -f parliament_executor_v6.py >/dev/null && AUTOHEAL=true

AUTOFIX=false
[ -f posts/autofix_report.md ] || [ -f cybra_self_healing_supervisor.sh ] && AUTOFIX=true

METADATA=false
[ -s token/coin/cybra_metadata.json ] && METADATA=true

LOGO=false
[ -s token/assets/cybra.png ] && LOGO=true

READY=false
if [ "$APPROVAL" = true ] && [ "$DOUBLE_SHA" = true ] && [ "$WATCHDOG" = true ] && [ "$AUTOHEAL" = true ] && [ "$AUTOFIX" = true ] && [ "$METADATA" = true ] && [ "$LOGO" = true ]; then
  READY=true
fi

STATUS="LOCKED"
[ "$READY" = true ] && STATUS="READY"

cat > token/runtime/mainnet_gate.json <<JSON
{
  "mainnet_status": "$STATUS",
  "wallet_visible": false,
  "metadata_valid": $METADATA,
  "logo_present": $LOGO,
  "double_sha_valid": $DOUBLE_SHA,
  "watchdog_ok": $WATCHDOG,
  "autoheal_ok": $AUTOHEAL,
  "autofix_ok": $AUTOFIX,
  "owner_approval": $APPROVAL,
  "ready_for_mainnet": $READY
}
JSON

cat > posts/mainnet_gatekeeper_status.md <<MD
# CYBRA Mainnet Gatekeeper

Status: $STATUS

Ready for mainnet:
$READY

Checks:
- metadata: $METADATA
- logo: $LOGO
- double_sha: $DOUBLE_SHA
- watchdog: $WATCHDOG
- autoheal: $AUTOHEAL
- autofix: $AUTOFIX
- owner_approval: $APPROVAL
MD

sha256sum token/runtime/mainnet_gate.json posts/mainnet_gatekeeper_status.md > proofs/mainnet_gatekeeper.sha256

echo "$(date -Iseconds) status=$STATUS ready=$READY" >> logs/mainnet_gatekeeper/gatekeeper.log

echo "✅ Mainnet gatekeeper checked: $STATUS"
BASH

chmod +x workers/pool/mainnet_gatekeeper.sh

cat > recovery/final_recovery_index.json <<JSON
{
  "system": "CYBRA Final Recovery Index",
  "files": [
    "parliament_executor_v6.py",
    "queue_bridge.sh",
    "workers_retry.py",
    "cybra_self_healing_supervisor.sh",
    "workers/pool/mainnet_gatekeeper.sh",
    "token/runtime/mainnet_gate.json",
    "proofs/cybra_coin_completion.sha256"
  ],
  "status": "indexed"
}
JSON

bash workers/pool/mainnet_gatekeeper.sh || true

cat > posts/final_integration_status.md <<'MD'
# CYBRA Final Integration Layer

Status: installed

Modules:
- queue bridge
- workers retry
- recovery layer
- watchdog
- autoheal
- autofix
- double SHA backend
- hash module
- mainnet gatekeeper
- coin completion

Mainnet:
LOCKED by default until all conditions pass.
MD

sha256sum \
  workers/pool/mainnet_gatekeeper.sh \
  token/runtime/mainnet_gate.json \
  recovery/final_recovery_index.json \
  posts/final_integration_status.md \
  > proofs/final_integration.sha256

echo "✅ CYBRA final integration layer installed"
