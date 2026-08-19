#!/bin/bash

ORDER="R⚕️"
BASE="$HOME/CYBRA/orders/order_${ORDER}"
CSV="$BASE/production/suppliers/validation/candidates_real.csv"
RFI_DIR="$BASE/production/suppliers/validation/rfi"

mkdir -p "$RFI_DIR"

sanitize() {
    printf '%s' "$1" | sed 's#[/\\:*?"<>| ]#_#g'
}

tail -n +2 "$CSV" | while IFS=',' read -r CATEGORY MANUFACTURER MODEL COUNTRY PRICE_USD QTY DELIVERY_DAYS WARRANTY_MONTHS CERT_URL TECH_DOC_URL REF_COUNT CONTACT_EMAIL SOURCE VERIFIED_BY DATE_VERIFIED QUALITY_SCORE YEARS_ON_MARKET; do

    SAFE_MANUFACTURER=$(sanitize "$MANUFACTURER")
    SAFE_MODEL=$(sanitize "$MODEL")
    RFI_FILE="$RFI_DIR/RFI_${SAFE_MANUFACTURER}_${SAFE_MODEL}.md"

    cat > "$RFI_FILE" <<EOF
# Запит інформації (RFI) — ${MANUFACTURER} ${MODEL}

**Замовлення:** R⚕️  
**Категорія:** ${CATEGORY}  
**Країна виробника:** ${COUNTRY}  
**Дата запиту:** $(date '+%Y-%m-%d')  
**Термін відповіді:** 3 банківські дні  

---

## Шановний постачальнику,

Просимо надати наступну інформацію та документи для участі в тендері на постачання обладнання для проєкту R⚕️:

### 1. Правові документи
- [ ] Свідоцтво про реєстрацію компанії
- [ ] Дистриб'юторський договір або сертифікат офіційного представника
- [ ] Сертифікат ISO 9001 (або ISO 13485 для медичного обладнання)

### 2. Технічна документація
- [ ] Технічний паспорт виробу
- [ ] Специфікації та креслення (якщо застосовно)
- [ ] Протоколи випробувань

### 3. Комерційна пропозиція
- [ ] Ціна за одиницю (у USD або EUR)
- [ ] Термін поставки
- [ ] Умови оплати
- [ ] Гарантійні зобов'язання (мінімум 24 місяці)

### 4. Референції
- [ ] Мінімум 2 підтверджені референції від попередніх клієнтів
- [ ] Рекомендаційні листи

### 5. Додатково
- [ ] Сертифікат походження товару
- [ ] Інформація про наявність сервісного центру в Україні або ЄС

---

## Контакти для надсилання документів

**Email:** procurement@cybra.local  
**Тема листа:** RFI R⚕️ ${MANUFACTURER} ${MODEL}

Будь ласка, надішліть документи у форматі PDF або іншому електронному вигляді.

**Важливо:** ненадання повного пакету документів протягом зазначеного терміну може призвести до виключення з процесу закупівлі.

З повагою,  
CYBRA Procurement  
Дата: $(date '+%Y-%m-%d')
EOF

    echo "[ OK ] RFI створено: $(basename "$RFI_FILE")"
done

echo "Готово. Створено $(ls -1 "$RFI_DIR" | wc -l) RFI-файлів."
