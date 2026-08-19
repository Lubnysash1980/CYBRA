#!/data/data/com.termux/files/usr/bin/bash
# CYBRA FLAT ENGINE – керування замовленням квартири

FLAT_ID="${FLAT_ID:-FLAT_2026_001}"
FLAT_DIR="$HOME/CYBRA/flats/order_${FLAT_ID}"
CONFIG="$FLAT_DIR/конфігурація/flat_${FLAT_ID}.conf"
STATE="$FLAT_DIR/виконання/стан/загальний_стан.state"
LOG="$FLAT_DIR/логи/лог_подій.log"

mkdir -p "$(dirname "$LOG")" "$(dirname "$STATE")" "$(dirname "$CONFIG")"

if [ ! -f "$CONFIG" ]; then
    cat > "$CONFIG" <<EOC
=========================================
CYBRA FLAT ORDER
=========================================
НАЗВА_ЗАВДАННЯ=ЗАМОВЛЕННЯ_КВАРТИРИ_${FLAT_ID}
СТАТУС=АКТИВНЕ
ДАТА_СТВОРЕННЯ=$(date +%Y-%m-%d)
ПОКУПЕЦЬ_ПІБ=ГРАБОВСЬКИЙ О.М.
ПОКУПЕЦЬ_ТЕЛЕФОН=+380663181676
ПОКУПЕЦЬ_EMAIL=lubnysash1980@gmail.com
АДРЕСА_КВАРТИРИ=м. Лубни, вул. Залізнична, 65/3
ЗАГАЛЬНА_ПЛОЩА=0
КІЛЬКІСТЬ_КІМНАТ=0
ДОКУМЕНТ_ПРАВО_ВЛАСНОСТІ=НІ
ДОКУМЕНТ_ТЕХПАСПОРТ=НІ
ДОКУМЕНТ_ДОГОВІР_КУПІВЛІ=НІ
ТРИГЕР_ОБ'ЄКТ_ГОТОВИЙ=НІ
ТРИГЕР_ДОКУМЕНТИ_ГОТОВІ=НІ
ТРИГЕР_ОСОБИСТА_ПЕРЕДАЧА=НІ
СТАН=ІНІЦІАЛІЗОВАНО
EOC
    echo "Створено конфігурацію для квартири $FLAT_ID"
fi

if [ ! -f "$STATE" ]; then
    echo "ІНІЦІАЛІЗОВАНО" > "$STATE"
fi

log() {
    echo "[$(date +%Y-%m-%d_%H:%M:%S)] $1" >> "$LOG"
}

get_param() {
    grep "^$1=" "$CONFIG" | head -1 | cut -d'=' -f2- || echo ""
}

set_param() {
    if grep -q "^$1=" "$CONFIG"; then
        sed -i "s/^$1=.*/$1=$2/" "$CONFIG"
    else
        echo "$1=$2" >> "$CONFIG"
    fi
    log "ЗМІНА ПАРАМЕТРА: $1=$2"
}

set_state() {
    echo "$1" > "$STATE"
    log "СТАТУС ЗМІНЕНО: $1"
}

case "$1" in
    status)
        echo "========================================="
        echo " СТАТУС ЗАМОВЛЕННЯ КВАРТИРИ #$FLAT_ID"
        echo "========================================="
        echo "FLAT_ID=$FLAT_ID"
        echo "STATUS=$(cat "$STATE" 2>/dev/null || echo 'НЕ ВИЗНАЧЕНО')"
        grep "^ТРИГЕР_" "$CONFIG" 2>/dev/null
        grep "^ДОКУМЕНТ_" "$CONFIG" 2>/dev/null
        grep "^АДРЕСА_" "$CONFIG" 2>/dev/null
        ;;
    update)
        if [ -z "$2" ]; then
            echo "Використання: $0 update КЛЮЧ=ЗНАЧЕННЯ"
            exit 1
        fi
        KEY=$(echo "$2" | cut -d'=' -f1)
        VALUE=$(echo "$2" | cut -d'=' -f2-)
        set_param "$KEY" "$VALUE"
        echo "Параметр $KEY оновлено на $VALUE"
        ;;
    trigger)
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo "Використання: $0 trigger <НАЗВА_ТРИГЕРА> <ТАК|НІ>"
            exit 1
        fi
        set_param "$2" "$3"
        echo "Тригер $2 встановлено на $3"
        ;;
    *)
        echo "Використання:"
        echo "  $0 status"
        echo "  $0 update КЛЮЧ=ЗНАЧЕННЯ"
        echo "  $0 trigger НАЗВА ТАК/НІ"
        ;;
esac
