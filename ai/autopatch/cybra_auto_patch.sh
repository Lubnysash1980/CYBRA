#!/data/data/com.termux/files/usr/bin/bash

ROOT="$HOME/CYBRA"
ORDER="${1:-us_auto_restore_5000_001}"
BASE="$ROOT/orders/order_${ORDER}"

STATE="$BASE/control/runtime/order_control.state"
LOG="$BASE/control/logs/order_control.log"
TASKS="$BASE/control/runtime/autopatch.tasks"
PLAN="$BASE/control/runtime/autopatch.plan"

PASS=0
WARN=0
FAIL=0

ok()   { echo "[ OK ] $1"; PASS=$((PASS+1)); }
warn() { echo "[WARN] $1"; WARN=$((WARN+1)); }
fail() { echo "[FAIL] $1"; FAIL=$((FAIL+1)); }

get() {
    grep "^$1=" "$STATE" 2>/dev/null | tail -1 | cut -d= -f2-
}

log() {
    mkdir -p "$(dirname "$LOG")"
    printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$LOG"
}

task() {
    echo "[TASK] $1"
    echo "$1" >> "$TASKS"
}

echo "========================================"
echo " CYBRA AI AUTOPATCH"
echo " ORDER #$ORDER"
echo "========================================"
echo

if [ ! -f "$STATE" ]; then
    fail "Файл стану замовлення відсутній"
    exit 1
fi

: > "$TASKS"

echo "--- КОНТРОЛЬНИЙ РЕЖИМ ---"

echo "STATUS=$(get STATUS)"
echo "MODE=$(get MODE)"
echo "TARGET_VEHICLES=$(get TARGET_VEHICLES)"
echo "MAX_MILEAGE_KM=$(get MAX_MILEAGE_KM)"
echo "TARGET_CITY=$(get TARGET_CITY)"
echo "TARGET_DISTRICT=$(get TARGET_DISTRICT)"
echo

if [ "$(get MODE)" = "READ_ONLY" ]; then
    ok "AI працює в READ_ONLY"
else
    fail "Небезпечний режим: MODE не READ_ONLY"
fi

if [ "$(get FUNDS_RELEASE)" = "BLOCKED" ]; then
    ok "Фінансове розблокування заблоковане"
else
    fail "Фінансове розблокування не заблоковане"
fi

echo
echo "--- 1. ПІДБІР АВТО ---"

if [ "$(get SOURCE)" = "USA_AUCTIONS" ]; then
    ok "Джерело: аукціони США"
else
    fail "Джерело аукціонів не задане"
fi

if [ "$(get TARGET_VEHICLES)" = "5000" ]; then
    ok "Ціль: 5000 автомобілів"
else
    warn "Цільовий обсяг відрізняється від 5000"
fi

if [ "$(get MAX_MILEAGE_KM)" = "60000" ]; then
    ok "Ліміт пробігу: 60000 км"
else
    warn "Ліміт пробігу змінений"
fi

task "Побудувати пул кандидатів з аукціонів США"
task "Перевіряти VIN/history/document status кожного кандидата"
task "Відсікати flood/fire/critical-structure damage"
task "Розраховувати економіку відновлення кожного кандидата"
task "Ранжувати кандидатів за кінцевою собівартістю"

echo
echo "--- 2. АУКЦІОН ---"

task "Моніторити відповідні лоти"
task "Формувати shortlist"
task "Контролювати максимальну економічно допустиму ставку"
task "Не виконувати ставку без окремого дозволу"

echo
echo "--- 3. МАСОВА ОПТИМІЗАЦІЯ ---"

[ "$(get BULK_PURCHASE_OPTIMIZATION)" = "ENABLED" ] \
    && ok "Оптимізація закупівлі" \
    || fail "Оптимізація закупівлі вимкнена"

[ "$(get BULK_REPAIR_OPTIMIZATION)" = "ENABLED" ] \
    && ok "Оптимізація ремонту" \
    || fail "Оптимізація ремонту вимкнена"

[ "$(get BULK_PARTS_OPTIMIZATION)" = "ENABLED" ] \
    && ok "Оптимізація запчастин" \
    || fail "Оптимізація запчастин вимкнена"

task "Групувати авто за моделлю та типом пошкодження"
task "Формувати оптову потребу в запчастинах"
task "Розраховувати економію серійного ремонту"
task "Порівнювати власний ремонт з альтернативними підрядниками"

echo
echo "--- 4. ЛОГІСТИКА ---"

[ "$(get BULK_LOGISTICS_OPTIMIZATION)" = "ENABLED" ] \
    && ok "Оптимізація логістики" \
    || fail "Оптимізація логістики вимкнена"

task "Групувати автомобілі для консолідованого перевезення"
task "Оптимізувати портову обробку"
task "Оптимізувати суднову партію"
task "Мінімізувати перевантаження"
task "Мінімізувати зберігання"
task "Побудувати маршрут до Києва"

echo
echo "--- 5. МИТНИЦЯ ---"

if [ "$(get CUSTOMS_INCLUDED)" = "YES" ]; then
    ok "Розмитнення включене"
else
    fail "Розмитнення не включене"
fi

task "Підготувати VIN-linked митний пакет"
task "Контролювати відповідність документів"
task "Розраховувати митні витрати до фінального рішення"

echo
echo "--- 6. РЕМОНТ ---"

if [ "$(get REPAIR_INCLUDED)" = "YES" ]; then
    ok "Ремонт включений"
else
    fail "Ремонт не включений"
fi

task "Попереднє дефектування до прибуття"
task "Класифікувати ремонт A/B/C"
task "Формувати batch repair"
task "Підготувати запчастини до прибуття"
task "Контролювати собівартість ремонту"
task "Виконувати фінальну діагностику"
task "Контролювати повторний ремонт"

echo
echo "--- 7. ДОКУМЕНТИ ---"

if [ "$(get TECHPASSPORT_INCLUDED)" = "YES" ]; then
    ok "Техпаспорт включений"
else
    fail "Техпаспорт не включений"
fi

task "Контролювати сертифікацію"
task "Контролювати техпаспорт"
task "Контролювати реєстрацію"
task "Перевіряти VIN на всіх документах"

echo
echo "--- 8. СТРАХУВАННЯ ---"

if [ "$(get INSURANCE_INCLUDED)" = "YES" ]; then
    ok "Страхування включене"
else
    fail "Страхування не включене"
fi

task "Контролювати транспортне страхування"
task "Контролювати фінальне страхування"
task "Звіряти VIN зі страховим пакетом"

echo
echo "--- 9. ДОСТАВКА ---"

echo "CITY=$(get TARGET_CITY)"
echo "DISTRICT=$(get TARGET_DISTRICT)"

if [ "$(get TARGET_CITY)" = "KYIV" ]; then
    ok "Кінцева точка: Київ"
else
    fail "Місто доставки не Київ"
fi

task "Оптимізувати фінальну доставку до Києва"
task "Поточний орієнтир: Караван"
task "Мінімізувати повторні перевантаження"
task "Побудувати графік видачі партіями"

echo
echo "--- 10. ТЕРМІНИ ---"

cat > "$PLAN" <<PLAN
ORDER=$ORDER

TARGET_VEHICLES=$(get TARGET_VEHICLES)
MAX_MILEAGE_KM=$(get MAX_MILEAGE_KM)

PHASE_01_AUCTION_SELECTION=PENDING
PHASE_02_AUCTION_PURCHASE=PENDING
PHASE_03_US_CONSOLIDATION=PENDING
PHASE_04_VESSEL_TRANSPORT=PENDING
PHASE_05_CUSTOMS=PENDING
PHASE_06_REPAIR=PENDING
PHASE_07_DOCUMENTS=PENDING
PHASE_08_INSURANCE=PENDING
PHASE_09_KYIV_DELIVERY=PENDING
PHASE_10_FINAL_READY=PENDING

DEADLINE_ENGINE=ENABLED
RISK_ENGINE=ENABLED
COST_ENGINE=ENABLED

NO_FINANCIAL_ACTION=READ_ONLY
NO_AUTO_BID=YES
NO_AUTO_PAYMENT=YES
PLAN

ok "План етапів створений"

task "Розраховувати ETA по кожному етапу"
task "Виявляти затримки"
task "Перераховувати ETA після зміни параметрів"
task "Піднімати WARN при ризику зриву терміну"

echo
echo "--- 11. ФІНАЛЬНИЙ АУДИТ ---"

AUDIT="$BASE/audit/order_audit.sh"

if [ -x "$AUDIT" ]; then
    ok "Основний аудит замовлення доступний"
else
    warn "Основний аудит не знайдений або не executable"
fi

echo
echo "--- 12. ЗАДАЧІ AUTOPATCH ---"

sort -u "$TASKS" > "$TASKS.tmp"
mv "$TASKS.tmp" "$TASKS"

cat "$TASKS"

echo
echo "--- ПІДСУМОК AUTOPATCH ---"

echo "PASS=$PASS"
echo "WARN=$WARN"
echo "FAIL=$FAIL"
echo "TASKS=$(wc -l < "$TASKS")"
echo "PLAN=$PLAN"

if [ "$FAIL" -eq 0 ]; then
    echo "AUTOPATCH_RESULT=READY_WITH_WARNINGS"
else
    echo "AUTOPATCH_RESULT=BLOCKED"
fi

log "AUTOPATCH RUN ORDER=$ORDER PASS=$PASS WARN=$WARN FAIL=$FAIL"

echo
echo "========================================"
