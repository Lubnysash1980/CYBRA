#!/data/data/com.termux/files/usr/bin/bash
set -e

mkdir -p token/watchdog token/autofix posts proofs logs/mainnet_guardian

STATUS_FILE="token/watchdog/mainnet_conditions.json"

OWNER_APPROVAL="false"
DOUBLE_SHA_OK="false"
WORKERS_OK="false"
WATCHDOG_OK="false"
VAULT_OK="false"
PROOFS_OK="false"
LEGAL_OK="false"
AUTOFIX_OK="false"

[ -f legal/auth/fingerprint_approval.txt ] && OWNER_APPROVAL="true"

sha256sum -c proofs/native_token_evolution.sha256 >/dev/null 2>&1 && DOUBLE_SHA_OK="true"

pgrep -f parliament_executor_v6.py >/dev/null && WORKERS_OK="true"

[ -f posts/legal_watchdog_v2_status.md ] && WATCHDOG_OK="true"

[ -f posts/token_vault_status.md ] && VAULT_OK="true"

sha256sum -c proofs/solana_mainnet_timestamp_sleep.sha256 >/dev/null 2>&1 && PROOFS_OK="true"

grep -q "Submitted: 12" posts/legal_watchdog_v2_status.md 2>/dev/null && LEGAL_OK="true"

[ -f posts/autofix_report.md ] && AUTOFIX_OK="true"

READY="false"

if \
 [ "$OWNER_APPROVAL" = "true" ] && \
 [ "$DOUBLE_SHA_OK" = "true" ] && \
 [ "$WORKERS_OK" = "true" ] && \
 [ "$WATCHDOG_OK" = "true" ] && \
 [ "$VAULT_OK" = "true" ] && \
 [ "$PROOFS_OK" = "true" ] && \
 [ "$LEGAL_OK" = "true" ] && \
 [ "$AUTOFIX_OK" = "true" ]; then
 READY="true"
fi

cat > "$STATUS_FILE" <<JSON
{
  "owner_approval": "$OWNER_APPROVAL",
  "double_sha_ok": "$DOUBLE_SHA_OK",
  "workers_ok": "$WORKERS_OK",
  "watchdog_ok": "$WATCHDOG_OK",
  "vault_ok": "$VAULT_OK",
  "proofs_ok": "$PROOFS_OK",
  "legal_ok": "$LEGAL_OK",
  "autofix_ok": "$AUTOFIX_OK",
  "mainnet_ready": "$READY"
}
JSON

cat > posts/mainnet_guardian_status.md <<MD
# CYBRA Mainnet Guardian

Owner approval: $OWNER_APPROVAL
Double SHA: $DOUBLE_SHA_OK
Workers: $WORKERS_OK
Watchdog: $WATCHDOG_OK
Vault: $VAULT_OK
Proofs: $PROOFS_OK
Legal pipeline: $LEGAL_OK
Autofix: $AUTOFIX_OK

MAINNET READY:
$READY
MD

sha256sum "$STATUS_FILE" posts/mainnet_guardian_status.md > proofs/mainnet_guardian.sha256

if [ "$READY" = "true" ]; then
  echo "$(date -Iseconds) MAINNET_READY=true" >> logs/mainnet_guardian/watchdog.log

  cat > token/autofix/mainnet_autostart.signal <<EOF
MAINNET_READY=true
TIMESTAMP=$(date -Iseconds)
EOF

  echo "✅ ALL CONDITIONS PASSED"
  echo "Mainnet autostart signal created"

else
  echo "$(date -Iseconds) MAINNET_READY=false" >> logs/mainnet_guardian/watchdog.log
  echo "⚠️ Conditions not complete"
fi

