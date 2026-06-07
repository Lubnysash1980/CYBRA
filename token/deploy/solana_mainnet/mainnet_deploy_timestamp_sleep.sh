#!/data/data/com.termux/files/usr/bin/bash
set +e

cd "$HOME/CYBRA" || exit 1

DIR="token/deploy/solana_mainnet"
mkdir -p "$DIR/proofs" "$DIR/reports" "$DIR/logs" "$DIR/approvals"

SLEEP_SECONDS="${1:-60}"
TS="$(date +%Y%m%d_%H%M%S)"
PREPARE_JSON="$DIR/mainnet_prepare_${TS}.json"
REPORT_MD="$DIR/reports/mainnet_prepare_${TS}.md"
PROOF_FILE="$DIR/proofs/mainnet_prepare_${TS}.sha256"

echo "=== CYBRA MAINNET DEPLOY PREPARE ==="
echo "MAINNET MODE: BLOCKED UNTIL OWNER APPROVAL"
echo "Timestamp: $TS"
echo "Sleep before action: $SLEEP_SECONDS seconds"

cat > "$PREPARE_JSON" <<JSON
{
  "status": "PREPARED_NOT_EXECUTED",
  "timestamp": "$TS",
  "network": "mainnet-beta",
  "sleep_seconds": "$SLEEP_SECONDS",
  "mainnet_blocked_until_owner_approval": true,
  "required_phrase": "APPROVE_MAINNET_DEPLOY",
  "real_mainnet_tx_executed": false,
  "automatic_external_tx": false,
  "private_key_required_in_chat": false,
  "seed_phrase_required_in_chat": false,
  "manual_OWNER_approval_required": true
}
JSON

cat > "$REPORT_MD" <<MD
# CYBRA Mainnet Deploy Prepare

Status: PREPARED_NOT_EXECUTED

Timestamp: $TS

Network: mainnet-beta

Mainnet blocked until OWNER approval: true

Required phrase:

\`\`\`
APPROVE_MAINNET_DEPLOY
\`\`\`

Safety:

- real_mainnet_tx_executed: false
- automatic_external_tx: false
- private_key_required_in_chat: false
- seed_phrase_required_in_chat: false
- manual_OWNER_approval_required: true
MD

sha256sum "$PREPARE_JSON" "$REPORT_MD" > "$PROOF_FILE"

sleep "$SLEEP_SECONDS"

echo -n "Type APPROVE_MAINNET_DEPLOY to continue: "
read APPROVAL

if [ "$APPROVAL" != "APPROVE_MAINNET_DEPLOY" ]; then
  CANCEL_JSON="$DIR/mainnet_cancelled_${TS}.json"
  CANCEL_REPORT="$DIR/reports/mainnet_cancelled_${TS}.md"
  CANCEL_PROOF="$DIR/proofs/mainnet_cancelled_${TS}.sha256"

  cat > "$CANCEL_JSON" <<JSON
{
  "status": "CANCELLED",
  "timestamp": "$TS",
  "network": "mainnet-beta",
  "reason": "approval_phrase_not_matched",
  "typed_value_was_not_required_phrase": true,
  "required_phrase": "APPROVE_MAINNET_DEPLOY",
  "real_mainnet_tx_executed": false,
  "automatic_external_tx": false,
  "manual_OWNER_approval_required": true
}
JSON

  cat > "$CANCEL_REPORT" <<MD
# CYBRA Mainnet Deploy Cancelled

Status: CANCELLED

Reason: approval_phrase_not_matched

Required phrase was:

\`\`\`
APPROVE_MAINNET_DEPLOY
\`\`\`

Real mainnet transaction executed: false
MD

  sha256sum "$CANCEL_JSON" "$CANCEL_REPORT" "$PREPARE_JSON" "$REPORT_MD" > "$CANCEL_PROOF"

  echo "Cancelled. Mainnet not executed."
  echo "PREPARE_JSON: $PREPARE_JSON"
  echo "PREPARE_PROOF: $PROOF_FILE"
  echo "CANCEL_JSON: $CANCEL_JSON"
  echo "CANCEL_PROOF: $CANCEL_PROOF"
  exit 0
fi

APPROVED_JSON="$DIR/approvals/mainnet_approved_${TS}.json"
APPROVED_REPORT="$DIR/reports/mainnet_approved_${TS}.md"
APPROVED_PROOF="$DIR/proofs/mainnet_approved_${TS}.sha256"

cat > "$APPROVED_JSON" <<JSON
{
  "status": "OWNER_APPROVED_PREPARED",
  "timestamp": "$TS",
  "network": "mainnet-beta",
  "approval_phrase_matched": true,
  "real_mainnet_tx_executed": false,
  "note": "Approval recorded. Real transaction still requires explicit deploy runner.",
  "automatic_external_tx": false,
  "manual_OWNER_approval_required": true
}
JSON

cat > "$APPROVED_REPORT" <<MD
# CYBRA Mainnet Deploy Approved Prepare

Status: OWNER_APPROVED_PREPARED

Approval phrase matched: true

Real mainnet transaction executed: false

Next step requires explicit deploy runner.
MD

sha256sum "$APPROVED_JSON" "$APPROVED_REPORT" "$PREPARE_JSON" "$REPORT_MD" > "$APPROVED_PROOF"

echo "✅ OWNER approval recorded."
echo "⚠ Real mainnet transaction was NOT executed by this prepare script."
echo "APPROVED_JSON: $APPROVED_JSON"
echo "APPROVED_PROOF: $APPROVED_PROOF"
