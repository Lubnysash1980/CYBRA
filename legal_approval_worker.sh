#!/data/data/com.termux/files/usr/bin/bash
set -e

mkdir -p legal/approval_queue legal/submission_posts posts proofs

ID="approval_$(date +%Y%m%d_%H%M%S)"

cat > "legal/approval_queue/$ID.json" <<JSON
{
  "id": "$ID",
  "status": "waiting_owner_confirmation",
  "channels": ["email", "diia_sign", "manual"],
  "target": "legal_requests",
  "message": "Потрібне підтвердження власника для подачі 12 legal requests"
}
JSON

cat > "posts/$ID.md" <<MD
# Потрібне підтвердження

ID: $ID

Система підготувала 12 запитів:
- прокуратура ×3
- ДБР ×3
- суд ×3
- поліція ×3

Оберіть канал підтвердження:

\`\`\`bash
bash legal_confirm_submission.sh $ID email
bash legal_confirm_submission.sh $ID diia_sign
bash legal_confirm_submission.sh $ID manual
\`\`\`

Статус:
waiting_owner_confirmation
MD

sha256sum "legal/approval_queue/$ID.json" "posts/$ID.md" > "proofs/$ID.sha256"

echo "✅ Approval post created: posts/$ID.md"
echo "$ID" > legal/approval_queue/latest_id.txt
