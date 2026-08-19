#!/bin/bash

ORDER="R⚕️"
BASE="$HOME/CYBRA/orders/order_${ORDER}"
CSV="$BASE/production/suppliers/validation/candidates_real.csv"
DOCS_DIR="$BASE/production/suppliers/validation/documents"
STATUS_FILE="$BASE/control/real_docs_status.txt"
AUDIT="$BASE/control/logs/master_audit.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$AUDIT"
}

echo "=== ПЕРЕВІРКА РЕАЛЬНИХ ДОКУМЕНТІВ ==="
echo "Час: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

> "$STATUS_FILE"

TOTAL=0
FOUND=0
MISSING=0

while IFS=',' read -r CATEGORY MANUFACTURER MODEL COUNTRY PRICE_USD QTY DELIVERY_DAYS WARRANTY_MONTHS CERT_URL TECH_DOC_URL REF_COUNT CONTACT_EMAIL SOURCE VERIFIED_BY DATE_VERIFIED QUALITY_SCORE YEARS_ON_MARKET; do

    TOTAL=$((TOTAL+1))

    SAFE_MANUFACTURER=$(printf '%s' "$MANUFACTURER" | sed 's#[/\\:*?"<>|]#_#g')
    SAFE_MODEL=$(printf '%s' "$MODEL" | sed 's#[/\\:*?"<>|]#_#g')

    REAL_FILES=$(find "$DOCS_DIR" -maxdepth 1 -type f \
        \( -iname "${SAFE_MANUFACTURER}_${SAFE_MODEL}*.pdf" \
        -o -iname "${SAFE_MANUFACTURER}_${SAFE_MODEL}*.jpg" \
        -o -iname "${SAFE_MANUFACTURER}_${SAFE_MODEL}*.png" \
        -o -iname "${SAFE_MANUFACTURER}_${SAFE_MODEL}*.doc" \
        -o -iname "${SAFE_MANUFACTURER}_${SAFE_MODEL}*.docx" \
        -o -iname "${SAFE_MANUFACTURER}_${SAFE_MODEL}*.xls" \
        -o -iname "${SAFE_MANUFACTURER}_${SAFE_MODEL}*.xlsx" \
        -o -iname "${SAFE_MANUFACTURER}_${SAFE_MODEL}*.sig" \
        -o -iname "${SAFE_MANUFACTURER}_${SAFE_MODEL}*.p7s" \) 2>/dev/null)

    if [ -n "$REAL_FILES" ]; then
        echo "[РЕАЛЬНІ ДОКУМЕНТИ] $MANUFACTURER $MODEL → знайдено $(echo "$REAL_FILES" | wc -l) файл(ів)"
        echo "$CATEGORY,$MANUFACTURER,$MODEL,VERIFIED" >> "$STATUS_FILE"
        FOUND=$((FOUND+1))
        log "REAL_DOC_VERIFIED | $MANUFACTURER $MODEL | FOUND_REAL_DOCS"
    else
        echo "[ЧЕКАЄМО] $MANUFACTURER $MODEL — реальних документів немає"
        echo "$CATEGORY,$MANUFACTURER,$MODEL,MISSING" >> "$STATUS_FILE"
        MISSING=$((MISSING+1))
        log "REAL_DOC_MISSING | $MANUFACTURER $MODEL | AWAITING_REAL_DOCUMENTS"
    fi

done < <(tail -n +2 "$CSV")

echo ""
echo "=== РЕЗУЛЬТАТ ПЕРЕВІРКИ ==="
echo "Всього кандидатів: $TOTAL"
echo "Знайдено реальних документів: $FOUND"
echo "Відсутні реальні документи: $MISSING"
echo ""

if [ "$MISSING" -gt 0 ]; then
    echo "СТАТУС: AWAITING_REAL_DOCUMENTS"
else
    echo "СТАТУС: ALL_REAL_DOCUMENTS_VERIFIED"
fi
