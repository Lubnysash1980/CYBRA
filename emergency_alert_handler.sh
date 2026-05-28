#!/data/data/com.termux/files/usr/bin/bash
set -e

mkdir -p posts proofs

cat > posts/emergency_alert_status.md <<'MD'
# CYBRA Emergency Alert Test

Topic: Ракетна небезпека

Status: received and routed.

Рекомендація:
- перевірити офіційні джерела повітряної тривоги;
- не панікувати;
- діяти за інструкціями місцевої влади;
- перейти в укриття, якщо тривога підтверджена.
MD

sha256sum posts/emergency_alert_status.md > proofs/emergency_alert_hash.txt

echo "✅ Emergency alert test handled"
