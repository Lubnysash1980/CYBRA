#!/data/data/com.termux/files/usr/bin/bash
set -e

mkdir -p legal/requests/{prosecutor,dbr,court,police} legal/watchdog posts proofs

for ORG in prosecutor dbr court police; do
  for N in 1 2 3; do
    cat > legal/requests/$ORG/request_$N.md <<MD
# Запит $N до $ORG

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
  "organs": {
    "prosecutor": {"requests": 3, "status": "waiting"},
    "dbr": {"requests": 3, "status": "waiting"},
    "court": {"requests": 3, "status": "waiting"},
    "police": {"requests": 3, "status": "waiting"}
  },
  "logic": {
    "if_no_response": "prepare_next_request",
    "if_response_received": "archive_and_analyze",
    "if_deadline_missed": "escalate"
  }
}
JSON

find legal/requests legal/watchdog -type f -exec sha256sum {} \; > proofs/legal_3x_requests.sha256

cat > posts/legal_3x_requests_status.md <<'MD'
# Legal 3x Requests System

Створено:
- 3 запити до прокуратури
- 3 запити до ДБР
- 3 запити до суду
- 3 запити до поліції
- watchdog контролю відповіді
MD

git add legal posts proofs legal_3x_requests_system.sh
git commit -m "add legal 3x requests watchdog system" || true

echo "✅ Legal 3x requests system created"
