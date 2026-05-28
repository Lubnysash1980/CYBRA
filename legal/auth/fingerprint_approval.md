# Fingerprint Approval

Status: not_approved

Потрібне ручне підтвердження власника перед відправкою або позначенням запитів як submitted.

## Команда підтвердження

echo "approved $(date -Iseconds)" > legal/auth/fingerprint_approval.txt

bash legal_mark_approved.sh
