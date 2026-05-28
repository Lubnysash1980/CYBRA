#!/data/data/com.termux/files/usr/bin/bash
set -e

mkdir -p legal/real_estate/{requests,evidence,timeline,registry}
mkdir -p legal/real_estate/requests/{hotiianivska_silrada,registry_service,court,police}
mkdir -p posts proofs

for ORG in hotiianivska_silrada registry_service court police; do
  for N in 1 2 3; do

    cat > "legal/real_estate/requests/$ORG/request_$N.md" <<MD
# Запит $N щодо нерухомості до $ORG

Статус: prepared_waiting_fingerprint_approval

Тема:
перевірка нерухомості та незавершеної форми власності, придбаної на заявника.

Об’єкт:
нерухомість / земельна ділянка / будинок / майнові права.

Орган:
Хотянівська сільська рада Київської області та пов’язані органи реєстрації.

## Прошу надати
- статус права власності;
- статус реєстраційних дій;
- наявність записів у реєстрах;
- інформацію щодо незавершеного оформлення;
- кадастрові/реєстраційні дані;
- причини затримки або відмови;
- відповідальних осіб;
- копії рішень або записів.

## Додатки
- договори;
- чеки/оплати;
- листування;
- попередні заяви;
- документи щодо нерухомості;
- інші докази.
MD

  done
done

cat > legal/real_estate/evidence/evidence_registry.md <<'MD'
# Real Estate Evidence Registry

- договори
- оплати
- реєстраційні документи
- кадастрові дані
- листування
- відповіді органів
- фото/скани
- timeline справи
MD

cat > legal/real_estate/timeline/case_timeline.md <<'MD'
# Real Estate Timeline

- придбання нерухомості
- подача документів
- очікування оформлення
- звернення до органів
- відповіді/відсутність відповідей
- escalation
MD

cat > legal/real_estate/registry/ownership_watchdog.json <<'JSON'
{
  "system": "real_estate_ownership_watchdog",
  "target": "Хотянівська сільська рада Київської області",
  "mode": "manual_after_fingerprint_approval",
  "status": "active",
  "logic": {
    "if_no_response": "prepare_next_request",
    "if_registry_missing": "escalate",
    "if_deadline_missed": "court_prepare"
  }
}
JSON

find legal/real_estate -type f -exec sha256sum {} \; > proofs/real_estate_legal.sha256

cat > posts/real_estate_legal_status.md <<'MD'
# Real Estate Legal System

Об’єкт:
нерухомість / незавершена форма власності

Орган:
Хотянівська сільська рада Київської області

Створено:
- 12 legal requests
- evidence registry
- ownership watchdog
- timeline справи
- registry tracking

Статус:
prepared_waiting_fingerprint_approval
MD

git add legal posts proofs real_estate_legal_system.sh
git commit -m "add Hotianivska real estate legal watchdog system" || true

echo "✅ Real estate legal system created"
