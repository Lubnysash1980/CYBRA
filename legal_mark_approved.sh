#!/data/data/com.termux/files/usr/bin/bash
set -e

if [ ! -f legal/auth/fingerprint_approval.txt ]; then
  echo "❌ Немає fingerprint/manual approval"
  exit 1
fi

find legal/requests \
  -name "request_*.md" \
  -type f \
  -exec sed -i \
  's/prepared_waiting_fingerprint_approval/approved_ready_for_manual_submission/g' {} \;

sha256sum \
  legal/requests/*/*.md \
  legal/watchdog/response_control.json \
  legal/auth/fingerprint_approval.txt \
  > proofs/legal_3x_requests_approved.sha256

echo "✅ Requests approved by owner fingerprint/manual confirmation"
