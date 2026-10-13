#!/data/data/com.termux/files/usr/bin/bash
# ═══════════════════════════════════════════════════════════
# CYBRA ONE-SHOT: рахунок РБ0518-00742 → контракт → autosave → push
# ═══════════════════════════════════════════════════════════
set -u
export LC_ALL=C

ROOT="$HOME/CYBRA"
M19="$ROOT/modules/module_19_contract_tui_menu"
LIB="$M19/bin/cybra_tui_lib.sh"
MENU="$M19/bin/cybra_menu.sh"
BASELINE="$ROOT/baseline"
EVO_DIR="$ROOT/evolution"
GITMOD="$ROOT/git_module"
LOG="$ROOT/logs/one_shot_$(date -u +%Y%m%dT%H%M%SZ).log"

mkdir -p "$ROOT/logs" "$EVO_DIR" "$BASELINE"

# ─── Кольори ───
if [ -t 1 ]; then
    R=$'\033[31m'; G=$'\033[32m'; Y=$'\033[33m'
    B=$'\033[1m'; C=$'\033[36m'; Z=$'\033[0m'
else
    R=""; G=""; Y=""; B=""; C=""; Z=""
fi
say()  { printf '%s\n' "$*" | tee -a "$LOG"; }
hdr()  { printf '\n%s═══ %s ═══%s\n' "$B$C" "$*" "$Z" | tee -a "$LOG"; }
ok()   { printf '  %s[✓]%s %s\n' "$G" "$Z" "$*" | tee -a "$LOG"; }
warn() { printf '  %s[!]%s %s\n' "$Y" "$Z" "$*" | tee -a "$LOG"; }
err()  { printf '  %s[✗]%s %s\n' "$R" "$Z" "$*" | tee -a "$LOG"; }

# ═══════════════════════════════════════════════════════════
# [1] PRE-FLIGHT: перевірка що все на місці
# ═══════════════════════════════════════════════════════════
hdr "[1/7] Pre-flight"

[ ! -f "$LIB" ]  && { err "Немає cybra_tui_lib.sh"; exit 1; }
[ ! -f "$MENU" ] && { err "Немає cybra_menu.sh"; exit 1; }
ok "lib + menu на місці"

if ! bash -n "$LIB" 2>/dev/null; then
    err "Синтаксис lib зламано — відновлюю з backup"
    for f in $(ls -t "$M19/bin/cybra_tui_lib.sh.bak."* 2>/dev/null); do
        bash -n "$f" 2>/dev/null && { cp "$f" "$LIB"; ok "відновлено з $f"; break; }
    done
fi
ok "lib syntax OK"

# Pre-approve
printf '%s' "$(cat "$BASELINE/module_19_contract_tui_menu.tree" 2>/dev/null)" \
    > "$EVO_DIR/module_19_contract_tui_menu.approved"

# ─── FIX recipients (якщо раптом AUTO) ───
RECIPIENT="0x66434c5501242ccC71b5a39C765892921624B66c"
for k in CREATION_FEE_RECIPIENT LICENSE_A_RECIPIENT LICENSE_B_RECIPIENT; do
    sed -i "s|^${k}=\\\$[A-Z_]*|${k}=${RECIPIENT}|" "$LIB" 2>/dev/null
    sed -i "s|^${k}=AUTO$|${k}=${RECIPIENT}|"        "$LIB" 2>/dev/null
done
ok "recipients = ${RECIPIENT:0:16}..."

# ═══════════════════════════════════════════════════════════
# [2] SOURCE LIB
# ═══════════════════════════════════════════════════════════
hdr "[2/7] Завантажую lib"

source "$LIB"
ok "LIB завантажено"

# Перевірка що потрібні функції є
for fn in cybra_contract_create_invoice cybra_invoice_add_line cybra_invoice_finalize; do
    if ! declare -f "$fn" >/dev/null 2>&1; then
        err "Функція $fn відсутня в lib!"
        exit 1
    fi
done
ok "всі invoice-функції на місці"

# ═══════════════════════════════════════════════════════════
# [3] ДАНІ З РАХУНКУ
# ═══════════════════════════════════════════════════════════
hdr "[3/7] Дані з рахунку РБ0518-00742"

# Рахунок-фактура № РБ0518-00742 від 06.10.2026
# Продавець: ТОВ "КОМФІ ТРЕЙД" (ЄДРПОУ 36962487)
# Покупець:  Грабовський Олександр Миколайович (ІПН 2937002115)
# Сума: 137 475,00 грн (у т.ч. ПДВ 22 912,51)

# ─── Сторони ───
BUYER_NAME="Грабовський Олександр Миколайович"
BUYER_IPN="2937002115"
BUYER_WALLET="0x29fA26FC5768Fe1E62160E021Fd3f88d92257A1F"   # ← замініть на свій

SELLER_NAME="ТОВ КОМФІ ТРЕЙД"
SELLER_EDRPOU="36962487"
SELLER_WALLET="0x66434c5501242ccC71b5a39C765892921624B66c"

INV_NO="РБ0518-00742"
INV_DATE="2026-10-06"

# ─── Сума у wei (decimals=18) ───
# 137 475,00 UAH → якщо трактуємо як USD-еквівалент, треба курс.
# Для тесту ставимо ТОЧНО 137475 * 10^18 wei
AMOUNT_WEI="137475000000000000000000"

# ─── Token ───
TOKEN="0x74dA52028E42A37bc89E05c2fD5c52daBE4CB48f"   # приклад BSC-токен
DECIMALS=18

say "  BUYER:  $BUYER_NAME ($BUYER_IPN)"
say "  SELLER: $SELLER_NAME ($SELLER_EDRPOU)"
say "  AMOUNT: $AMOUNT_WEI wei (decimals=$DECIMALS)"
say "  TOKEN:  ${TOKEN:0:16}..."

# ═══════════════════════════════════════════════════════════
# [4] СТВОРЕННЯ INVOICE
# ═══════════════════════════════════════════════════════════
hdr "[4/7] Створюю INVOICE"

CID="$(cybra_contract_create_invoice \
    "$BUYER_NAME" "$BUYER_IPN" "$BUYER_WALLET" \
    "$SELLER_NAME" "$SELLER_EDRPOU" "$SELLER_WALLET" \
    "$INV_NO" "$INV_DATE" \
    "$AMOUNT_WEI" "$TOKEN" "$DECIMALS" 20 2>&1)"

# Витягуємо ID (може бути з префіксом)
CID="$(printf '%s' "$CID" | grep -oE 'C-INV-[A-Za-z0-9-]+' | head -1)"
[ -z "$CID" ] && { err "Не вдалось створити invoice"; exit 1; }

ok "CONTRACT_ID: $CID"
printf '%s' "$CID" > "$ROOT/.last_contract_id"

# ═══════════════════════════════════════════════════════════
# [5] ДОДАЮ 5 ПОЗИЦІЙ
# ═══════════════════════════════════════════════════════════
hdr "[5/7] Додаю 5 позицій з рахунку"

# Формат: code|name|qty|price (у базових одиницях — копійки)
LINES=(
    "3984343|Смартфон Samsung Galaxy Fold 8 16/1Tb Graphite|1|8174833"
    "3909742|Послуга Comfort Upgrade 2 роки|1|2452500"
    "2908219|Мережевий зарядний пристрій Samsung Trio 65W 2 Type-C+USB|1|204083"
    "3799926|Батарея мобільна Pitaka Aramid Fiber Magnetic Qi2 5000mAh Sunset|1|333250"
    "4061288|Чохол для смартфону Pitaka Edge Ultra-Slim Case Twill Black/Grey|1|291583"
)

IDX=0
for line in "${LINES[@]}"; do
    IDX=$((IDX+1))
    IFS='|' read -r CODE NAME QTY PRICE <<< "$line"

    RES="$(cybra_invoice_add_line "$CID" "$CODE" "$NAME" "$QTY" "$PRICE" 2>&1)"
    if printf '%s' "$RES" | grep -qi 'error\|fail'; then
        warn "[$IDX] $NAME — $RES"
    else
        ok "[$IDX] $CODE × $QTY × $PRICE = $NAME"
    fi
done

# ═══════════════════════════════════════════════════════════
# [6] ФІНАЛІЗАЦІЯ
# ═══════════════════════════════════════════════════════════
hdr "[6/7] Фіналізую INVOICE"

FINAL="$(cybra_invoice_finalize "$CID" 2>&1)"
if printf '%s' "$FINAL" | grep -qi 'error\|fail'; then
    warn "finalize: $FINAL"
else
    ok "finalized"
fi

# Показ
cybra_invoice_show "$CID" 2>/dev/null | head -40 | sed 's/^/  /' | tee -a "$LOG"

# ─── Додаю REFUND deadline (72h) ───
F="$M19/contracts/$CID.env"
if [ -f "$F" ]; then
    DEADLINE="$(date -u -d '+72 hours' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
        || date -u -d "@$(( $(date +%s) + 72*3600 ))" +%Y-%m-%dT%H:%M:%SZ)"
    grep -q '^REFUND_ENABLED=' "$F" || {
        cat >> "$F" <<EOF

# === REFUND (auto) ===
REFUND_ENABLED=TRUE
REFUND_TIMEOUT_HOURS=72
REFUND_DEADLINE=$DEADLINE
BUYER_FINAL_DECISION=PENDING
BUYER_FINAL_DECISION_AT=
FINAL_DELIVERY_ALLOWED=FALSE
REFUND_STATUS=PENDING
REFUND_TRIGGER=
REFUND_AMOUNT_WEI=0
REFUND_RECIPIENT=
REFUNDED_AT=
CUSTOM_TERMS_COUNT=0
EOF
    }
    ok "REFUND deadline: $DEADLINE"
fi

# ═══════════════════════════════════════════════════════════
# [7] GUARDIAN AUTOSAVE + GIT PUSH
# ═══════════════════════════════════════════════════════════
hdr "[7/7] Autosave + git push"

AS="$ROOT/modules/module_35_cybra_guardian/bin/autosave.sh"

if [ -f "$AS" ]; then
    source "$AS" 2>/dev/null

    # Local
    as_save_local "$CID" 2>/dev/null && ok "local archive" || warn "local archive"

    # Git
    as_save_git "$CID" 2>/dev/null && ok "git push" || warn "git push"

    # Telegram (якщо налаштовано)
    if [ -f "$ROOT/modules/module_27_telegram_bot/state/config.env" ]; then
        as_save_telegram "$CID" 2>/dev/null || true
    fi

    # Email (якщо налаштовано)
    if grep -q '^EMAIL_ENABLED=TRUE' \
        "$ROOT/modules/module_35_cybra_guardian/state/autosave.env" 2>/dev/null; then
        as_save_email "$CID" 2>/dev/null || true
    fi

    # Cloud (якщо налаштовано)
    if grep -q '^CLOUD_ENABLED=TRUE' \
        "$ROOT/modules/module_35_cybra_guardian/state/autosave.env" 2>/dev/null; then
        as_save_cloud "$CID" 2>/dev/null || true
    fi
else
    warn "autosave.sh не знайдено — fallback git push"

    if [ -d "$GITMOD/.git" ]; then
        cd "$GITMOD" || exit 1
        mkdir -p contracts
        cp "$M19/contracts/$CID"* contracts/ 2>/dev/null
        git add -A 2>/dev/null
        git commit -m "INVOICE $CID autosave $(date -u +%Y%m%dT%H%M%SZ)" 2>&1 | tail -2
        git push 2>&1 | tail -2
        cd "$ROOT" || exit 1
    fi
fi

# ─── Baseline оновлення ───
NEW_HASH="$(
    cd "$M19" || exit 1
    find . -type f \
        ! -name '*.log' ! -name '*.test.log' \
        ! -name 'test_output.txt' ! -name 'test_output.sha256' \
        ! -name 'SNAPSHOT_SHA256.txt' ! -name '*.bak.*' \
        -print0 2>/dev/null |
    sort -z | xargs -0 -r sha256sum 2>/dev/null |
    sha256sum | awk '{print $1}'
)"
printf '%s' "$NEW_HASH" > "$BASELINE/module_19_contract_tui_menu.tree"
printf '%s' "$NEW_HASH" > "$EVO_DIR/module_19_contract_tui_menu.approved"
ok "baseline: ${NEW_HASH:0:16}..."

# ═══════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════
hdr "ГОТОВО"

say ""
say "  CONTRACT_ID: $CID"
say "  Buyer:       $BUYER_NAME"
say "  Seller:      $SELLER_NAME"
say "  Amount:      $AMOUNT_WEI wei"
say "  Lines:       ${#LINES[@]}"
say ""
say "  Файли:"
say "    Contract:  $M19/contracts/$CID.env"
say "    Lines:     $M19/contracts/$CID.lines"
say "    Terms:     $M19/contracts/$CID.terms"
say "    Archive:   $ROOT/modules/module_35_cybra_guardian/data/contracts_archive/$CID.tar.gz"
say ""
say "  Перевірка в TUI:"
say "    cybra → [2] Список контрактів"
say "    cybra → [3] Статус → $CID"
say "    cybra → [13] Показати INVOICE → $CID"
say ""
say "  Log: $LOG"
say ""
exit 0
