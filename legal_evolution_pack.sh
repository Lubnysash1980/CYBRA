#!/data/data/com.termux/files/usr/bin/bash
set -e

mkdir -p legal/{timeline,evidence,documents,court,dbr,watchdog} posts proofs

cat > legal/timeline/case_timeline.md <<'MD'
# Timeline справи

- Дата заяви до ДБР: ___
- Номер заяви/ЄО/реєстрації: ___
- Суть: ненадання інформації щодо авто / видачі / оформлення
- Поточний статус: відповідь не отримано
- Наступний крок: follow-up запит до ДБР
MD

cat > legal/evidence/evidence_graph.json <<'JSON'
{
  "case": "auto_registry_check",
  "nodes": [
    "person",
    "company_auto_capital",
    "vehicle_unknown",
    "payment_docs",
    "contracts",
    "dbr_statement",
    "mvs_registry",
    "dealer_response"
  ],
  "edges": []
}
JSON

cat > legal/dbr/dbr_followup_request.md <<'MD'
# Повторний запит до ДБР

Прошу повідомити стан розгляду раніше поданої заяви щодо ненадання інформації, можливої затримки оформлення/видачі транспортного засобу та інших пов’язаних обставин.

Прошу надати:
- номер реєстрації звернення;
- відповідального підрозділу/посадову особу;
- статус розгляду;
- строки відповіді;
- перелік додаткових документів, якщо потрібні.
MD

cat > legal/watchdog/deadline_watchdog.json <<'JSON'
{
  "enabled": true,
  "check": "manual_or_scheduled",
  "target": "DBR follow-up response",
  "status": "waiting"
}
JSON

cat > legal/documents/export_manifest.json <<'JSON'
{
  "documents": [
    "legal/timeline/case_timeline.md",
    "legal/evidence/evidence_graph.json",
    "legal/dbr/dbr_followup_request.md",
    "legal/watchdog/deadline_watchdog.json"
  ],
  "status": "prepared"
}
JSON

cat > legal/court/court_package_manifest.md <<'MD'
# Court Package Manifest

Пакет доказів:
- timeline справи;
- доказовий граф;
- запит до ДБР;
- чек-лист доказів;
- документи оплат/договори/VIN, якщо наявні.
MD

find legal -type f -exec sha256sum {} \; > proofs/legal_evolution_pack.sha256

cat > posts/legal_evolution_status.md <<'MD'
# Legal Evolution Pack

Створено:
- timeline справи
- evidence graph
- DBR follow-up task
- deadline watchdog
- document export manifest
- court package manifest
MD

git add legal posts proofs legal_evolution_pack.sh
git commit -m "add legal evolution pack" || true

echo "✅ Legal evolution pack created"
