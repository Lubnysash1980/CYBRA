#!/data/data/com.termux/files/usr/bin/bash
set -e

ID="$1"
CHANNEL="$2"

if [ -z "$ID" ] || [ -z "$CHANNEL" ]; then
  echo "Usage: bash legal_confirm_submission.sh APPROVAL_ID email|diia_sign|manual"
  exit 1
fi

case "$CHANNEL" in
  email|diia_sign|manual) ;;
  *)
    echo "❌ Unknown channel: $CHANNEL"
    exit 1
    ;;
esac

mkdir -p legal/submission_posts posts proofs

echo "approved $(date -Iseconds) channel=$CHANNEL id=$ID" > "legal/submission_posts/$ID.confirmation.txt"

cat > "posts/${ID}_confirmed.md" <<MD
# Submission Confirmed

ID: $ID  
Channel: $CHANNEL  
Status: approved_ready_to_submit  
Time: $(date -Iseconds)

Next:
- prepare final sending package
- mark requests as submitted after real submission
- start response watchdog
MD

sha256sum "legal/submission_posts/$ID.confirmation.txt" "posts/${ID}_confirmed.md" > "proofs/${ID}_confirmed.sha256"

echo "✅ Confirmed: $ID via $CHANNEL"
