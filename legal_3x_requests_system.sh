#!/data/data/com.termux/files/usr/bin/bash
set -e

mkdir -p legal/requests/{prosecutor,dbr,court,police}
mkdir -p legal/watchdog
mkdir -p legal/auth
mkdir -p posts
mkdir -p proofs

for ORG in prosecutor dbr court police; do
  for N in 1 2 3; do

    cat > "legal/requests/$ORG/request_$N.md" <<MD
# Запит $N до $ORG

Статус: prepared_waiting_fingerprint_approval

Прошу надати інформацію щодо стану розгляду звернення/заяви, пов’язаної з ненаданням інформації щодо транспортного засобу, його оформлення, видачі, реєстраційних дій, договорів, оплат та відповідальних осіб.

## Прошу надати
- номер реєстрації звернення;
- відповідальну посадову особу/підрозділ;
- поточний статус розгляду;
- строки відповіді;
- перелік необхідних додаткових документів;
- підстави бездіяльності або затримки, якщо такі є.

## Додатки
- копії оплат;
- договори/рахунки;
- листування;
- попередні заяви;
- відповіді або відсутність відповіді;
- інші докази.
MD

  done
done

cat > legal/watchdog/response_control.json <<'JSON'
{
  "system": "legal_response_watchdog",
  "submission_mode": "manual_after_fingerprint_approval",
  "organs": {
    "prosecutor": {
      "requests": 3,
      "status": "waiting_approval"
    },
    "dbr": {
      "requests": 3,
      "status": "waiting_approval"
    },
    "court": {
      "requests": 3,
      "status": "waiting_approval"
    },
    "police": {
      "requests": 3,
      "status": "waiting_approval"
    }
  },
  "logic": {
    "if_no_response": "prepare_next_request",
    "if_response_received": "archive_and_analyze",
    "if_deadline_missed": "escalate",
    "before_send": "require_fingerprint_confirmation"
  }
}
JSON

cat > legal/auth/fingerprint_approval.md <<'MD'
# Fingerprint Approval

Status: not_approved

Потрібне ручне підтвердження власника перед відправкою або позначенням запитів як submitted.

## Команда підтвердження

echo "approved $(date -Iseconds)" > legal/auth/fingerprint_approval.txt

bash legal_mark_approved.sh
MD

cat > legal_mark_approved.sh <<'APPROVE'
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
APPROVE

chmod +x legal_mark_approved.sh

find legal/requests legal/watchdog legal/auth \
  -type f \
  -exec sha256sum {} \; \
  > proofs/legal_3x_requests.sha256

cat > posts/legal_3x_requests_status.md <<'MD'
# Legal 3x Requests System

Створено:
- 3 запити до прокуратури
- 3 запити до ДБР
- 3 запити до суду
- 3 запити до поліції
- watchdog контролю відповіді
- fingerprint/manual approval gate

Статус:
prepared_waiting_fingerprint_approval
MD

git add legal posts proofs \
  legal_3x_requests_system.sh \
  legal_mark_approved.sh

git commit -m \
"add legal 3x requests with fingerprint approval gate" || true

echo "✅ Legal 3x requests system created with approval gate"
