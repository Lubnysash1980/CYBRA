#!/data/data/com.termux/files/usr/bin/bash
set -e

mkdir -p legal/autofix posts proofs

FOUND=0

for F in legal/requests/*/*.md; do

  if grep -q "approved_ready_for_manual_submission" "$F"; then

    FOUND=1

    echo "[WAITING_SEND] $F" >> legal/autofix/pending_requests.log

  fi

done

COUNT=$(cat legal/autofix/pending_requests.log 2>/dev/null | wc -l)

cat > posts/legal_submission_autofix_status.md <<MD
# Legal Submission Autofix

Pending manual submissions:
$COUNT

Logic:
- detect approved but unsent requests
- prepare reminder
- preserve hashes
- wait for owner confirmation
MD

sha256sum \
  posts/legal_submission_autofix_status.md \
  legal/autofix/pending_requests.log \
  > proofs/legal_submission_autofix.sha256

if [ "$FOUND" = "1" ]; then
  echo "⚠️ Pending submissions detected"
else
  echo "✅ No pending submissions"
fi
