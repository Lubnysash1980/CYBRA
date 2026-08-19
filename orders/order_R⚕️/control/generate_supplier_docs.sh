#!/bin/bash
ORDER="R⚕️"
BASE="$HOME/CYBRA/orders/order_${ORDER}"
CSV="$BASE/production/suppliers/validation/candidates_real.csv"
DOCS_DIR="$BASE/production/suppliers/validation/documents"

mkdir -p "$DOCS_DIR"

sanitize() {
    printf '%s' "$1" | sed 's#[/\\:*?"<>| ]#_#g'
}

tail -n +2 "$CSV" | while IFS=',' read -r CATEGORY MANUFACTURER MODEL COUNTRY PRICE_USD QTY DELIVERY_DAYS WARRANTY_MONTHS CERT_URL TECH_DOC_URL REF_COUNT CONTACT_EMAIL SOURCE VERIFIED_BY DATE_VERIFIED QUALITY_SCORE YEARS_ON_MARKET; do
    SAFE_MANUFACTURER=$(sanitize "$MANUFACTURER")
    SAFE_MODEL=$(sanitize "$MODEL")
    DOC_FILE="$DOCS_DIR/${SAFE_MANUFACTURER}_${SAFE_MODEL}_docs.txt"
    cat > "$DOC_FILE" <<DOC
Підтверджуючі документи для ${MANUFACTURER} ${MODEL}
Категорія: ${CATEGORY}
Країна: ${COUNTRY}
Сертифікати: ${CERT_URL}
Технічна документація: ${TECH_DOC_URL}
Кількість референцій: ${REF_COUNT}
Контакт: ${CONTACT_EMAIL}
Дата перевірки: ${DATE_VERIFIED}
Перевірено: ${VERIFIED_BY}
Примітка: реальні посилання на відкриті джерела, потребують офіційного підтвердження.
DOC
    echo "[ OK ] ${SAFE_MANUFACTURER}_${SAFE_MODEL}_docs.txt"
done
echo "Файлів у каталозі: $(ls -1 "$DOCS_DIR" | wc -l)"
