#!/bin/bash
ORDER="R⚕️"
BASE="$HOME/CYBRA/orders/order_${ORDER}"
CSV="$BASE/production/suppliers/validation/candidates_real.csv"
PRICE_SCORES="$BASE/control/price_scores.txt"
AUDIT="$BASE/control/logs/master_audit.log"
RFQ_DIR="$BASE/production/suppliers/validation/rfq"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$AUDIT"
}

score_supplier() {
    local cert_score=$1
    local price_score=$2
    local delivery_score=$3
    local warranty_score=$4
    local quality_score=$5
    local references_score=$6
    local years_score=$7

    total=$(( (cert_score * 25 + price_score * 20 + delivery_score * 15 + warranty_score * 15 + quality_score * 15 + references_score * 10 + years_score * 5) / 100 ))
    echo "$total"
}

bash "$BASE/control/price_score_calc.sh" > /dev/null
if [ ! -f "$PRICE_SCORES" ]; then
    echo "❌ Не вдалося розрахувати price_score"
    exit 1
fi

tail -n +2 "$CSV" | while IFS=',' read -r CATEGORY MANUFACTURER MODEL COUNTRY PRICE_USD QTY DELIVERY_DAYS WARRANTY_MONTHS CERT_URL TECH_DOC_URL REF_COUNT CONTACT_EMAIL SOURCE VERIFIED_BY DATE_VERIFIED QUALITY_SCORE YEARS_ON_MARKET; do

    if [ -z "$CATEGORY" ] || [ -z "$MANUFACTURER" ] || [ -z "$MODEL" ] || [ -z "$PRICE_USD" ] || [ -z "$CERT_URL" ] || [ -z "$TECH_DOC_URL" ]; then
        echo "[SKIP] $MANUFACTURER $MODEL — відсутні обов'язкові поля"
        log "VALIDATION_SKIP | $MANUFACTURER $MODEL | MISSING_FIELDS"
        continue
    fi

    SAFE_MANUFACTURER=$(printf '%s' "$MANUFACTURER" | sed 's#[/\\:*?"<>| ]#_#g')
    SAFE_MODEL=$(printf '%s' "$MODEL" | sed 's#[/\\:*?"<>| ]#_#g')
    DOC_FILE="$BASE/production/suppliers/validation/documents/${SAFE_MANUFACTURER}_${SAFE_MODEL}_docs.txt"
    if [ ! -f "$DOC_FILE" ]; then
        echo "[NEXT_SUPPLIER] $MANUFACTURER $MODEL — немає підтверджених документів"
        log "VALIDATION_NO_DOCS | $MANUFACTURER $MODEL | NEXT_SUPPLIER"
        continue
    fi

    PRICE_SCORE=$(grep "^$CATEGORY,$MANUFACTURER,$MODEL," "$PRICE_SCORES" | cut -d',' -f5)
    if [ -z "$PRICE_SCORE" ]; then
        PRICE_SCORE=70
    fi

    # Перевіряємо наявність реальних документів у статусному файлі
    REAL_STATUS_FILE="$BASE/control/real_docs_status.txt"
    if [ -f "$REAL_STATUS_FILE" ]; then
        REAL_DOC_STATUS=$(grep "^$CATEGORY,$MANUFACTURER,$MODEL," "$REAL_STATUS_FILE" | cut -d',' -f4)
        if [ "$REAL_DOC_STATUS" = "VERIFIED" ]; then
            CERT_SCORE=100
        else
            CERT_SCORE=0
        fi
    else
        # Якщо статусний файл відсутній, сертифікаційний бал 0
        CERT_SCORE=0
    fi

    if [ "$DELIVERY_DAYS" -le 7 ]; then DELIVERY_SCORE=100
    elif [ "$DELIVERY_DAYS" -le 14 ]; then DELIVERY_SCORE=85
    elif [ "$DELIVERY_DAYS" -le 30 ]; then DELIVERY_SCORE=70
    elif [ "$DELIVERY_DAYS" -le 60 ]; then DELIVERY_SCORE=50
    else DELIVERY_SCORE=20; fi

    if [ "$WARRANTY_MONTHS" -ge 60 ]; then WARRANTY_SCORE=100
    elif [ "$WARRANTY_MONTHS" -ge 36 ]; then WARRANTY_SCORE=85
    elif [ "$WARRANTY_MONTHS" -ge 24 ]; then WARRANTY_SCORE=70
    elif [ "$WARRANTY_MONTHS" -ge 12 ]; then WARRANTY_SCORE=40
    else WARRANTY_SCORE=10; fi

    QUALITY_SCORE=${QUALITY_SCORE:-70}

    if [ "$REF_COUNT" -ge 5 ]; then REF_SCORE=100
    elif [ "$REF_COUNT" -ge 3 ]; then REF_SCORE=80
    elif [ "$REF_COUNT" -ge 2 ]; then REF_SCORE=60
    else REF_SCORE=20; fi

    if [ "$YEARS_ON_MARKET" -ge 10 ]; then YEARS_SCORE=100
    elif [ "$YEARS_ON_MARKET" -ge 5 ]; then YEARS_SCORE=80
    elif [ "$YEARS_ON_MARKET" -ge 3 ]; then YEARS_SCORE=60
    else YEARS_SCORE=10; fi

    TOTAL=$(score_supplier "$CERT_SCORE" "$PRICE_SCORE" "$DELIVERY_SCORE" "$WARRANTY_SCORE" "$QUALITY_SCORE" "$REF_SCORE" "$YEARS_SCORE")

    if [ "$TOTAL" -ge 85 ]; then
        STATUS="PRIMARY"
        DEST="$BASE/production/suppliers/validation/approved"
    elif [ "$TOTAL" -ge 70 ]; then
        STATUS="CONDITIONAL"
        DEST="$BASE/production/suppliers/validation/conditional"
    else
        STATUS="NEXT_SUPPLIER"
        DEST="$BASE/production/suppliers/validation/rejected"
    fi

    echo "[$STATUS] $MANUFACTURER $MODEL (Score: $TOTAL)"
    log "VALIDATION_RESULT | $MANUFACTURER $MODEL | SCORE=$TOTAL | STATUS=$STATUS"

    echo "$CATEGORY,$MANUFACTURER,$MODEL,$COUNTRY,$PRICE_USD,$QTY,$DELIVERY_DAYS,$WARRANTY_MONTHS,$CONTACT_EMAIL,$SOURCE,$DATE_VERIFIED,$QUALITY_SCORE,$YEARS_ON_MARKET" >> "$DEST/validated.csv"

    if [ "$STATUS" = "PRIMARY" ] || [ "$STATUS" = "CONDITIONAL" ]; then
        RFQ_FILE="$RFQ_DIR/RFQ_${SAFE_MANUFACTURER}_${SAFE_MODEL}.md"
        cat > "$RFQ_FILE" << RFQ_BLOCK
# RFQ — $MANUFACTURER $MODEL

**Замовлення:** R⚕️
**Категорія:** $CATEGORY
**Кількість:** $QTY
**Цільова ціна:** $PRICE_USD USD
**Термін поставки:** $DELIVERY_DAYS днів
**Гарантія:** $WARRANTY_MONTHS міс
**Контакт:** $CONTACT_EMAIL

Будь ласка, підтвердіть комерційну пропозицію протягом 3 банківських днів.
RFQ_BLOCK
        echo "RFQ створено: $RFQ_FILE"
        log "RFQ_GENERATED | $MANUFACTURER $MODEL | STATUS=$STATUS"
    fi
done

echo "=== ВАЛІДАЦІЮ ЗАВЕРШЕНО ==="
log "SUPPLIER_ENGINE_COMPLETE | REAL_DATA_PROCESSED"
