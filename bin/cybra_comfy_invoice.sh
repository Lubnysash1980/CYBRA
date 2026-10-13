#!/data/data/com.termux/files/usr/bin/bash
# ═══════════════════════════════════════════════════════════
# CYBRA COMFY INVOICE v2 — SELF-CONTAINED (не залежить від lib)
# ═══════════════════════════════════════════════════════════
set -u
export LC_ALL=C

# ═══════════ АРГУМЕНТИ ═══════════
BUYER_WALLET="${1:-0x29fA26FC5768Fe1E62160E021Fd3f88d92257A1F}"
COMFY_EMAIL="${2:-info@comfy.ua}"

ROOT="$HOME/CYBRA"
M19="$ROOT/modules/module_19_contract_tui_menu"
CONTRACTS="$M19/contracts"
LINKS="$M19/links"
EVIDENCE="$M19/evidence"
BASELINE="$ROOT/baseline"
EVO_DIR="$ROOT/evolution"
GITMOD="$ROOT/git_module"
OUT_DIR="$M19/outbox"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
LOG="$ROOT/logs/comfy_${STAMP}.log"

mkdir -p "$ROOT/logs" "$EVO_DIR" "$BASELINE" "$OUT_DIR" "$CONTRACTS" "$LINKS" "$EVIDENCE"

# ═══════════ КОЛЬОРИ ═══════════
if [ -t 1 ]; then
    R=$'\033[31m'; G=$'\033[32m'; Y=$'\033[33m'
    B=$'\033[1m'; C=$'\033[36m'; M=$'\033[35m'; Z=$'\033[0m'
else
    R=""; G=""; Y=""; B=""; C=""; M=""; Z=""
fi
say()  { printf '%s\n' "$*" | tee -a "$LOG"; }
hdr()  { printf '\n%s═══ %s ═══%s\n' "$B$C" "$*" "$Z" | tee -a "$LOG"; }
ok()   { printf '  %s[✓]%s %s\n' "$G" "$Z" "$*" | tee -a "$LOG"; }
warn() { printf '  %s[!]%s %s\n' "$Y" "$Z" "$*" | tee -a "$LOG"; }
err()  { printf '  %s[✗]%s %s\n' "$R" "$Z" "$*" | tee -a "$LOG"; }

# ═══════════ [0] ВАЛІДАЦІЯ ═══════════
hdr "[0/8] Валідація"

printf '%s' "$BUYER_WALLET" | grep -qE '^0x[a-fA-F0-9]{40}$' \
    && ok "BUYER: $BUYER_WALLET" \
    || { err "Некоректна адреса: $BUYER_WALLET"; exit 1; }

ok "COMFY_EMAIL: $COMFY_EMAIL"

# ═══════════ [0.5] ДІАГНОСТИКА LIB ═══════════
hdr "[0.5/8] Діагностика lib (для інформації)"

LIB="$M19/bin/cybra_tui_lib.sh"
if [ -f "$LIB" ]; then
    ok "lib існує: $(wc -l < "$LIB") рядків"
    
    # Які invoice-функції є?
    say "  Шукаю invoice-функції:"
    for fn in cybra_contract_create_invoice cybra_invoice_add_line cybra_invoice_finalize cybra_contract_create; do
        if grep -qE "^${fn}\(\)" "$LIB" 2>/dev/null; then
            ok "    знайдено: $fn"
        else
            warn "    ВІДСУТНЯ: $fn"
        fi
    done
    
    # Синтаксис
    if bash -n "$LIB" 2>/dev/null; then
        ok "    lib syntax OK"
    else
        warn "    lib syntax ЗЛАМАНО — це причина"
    fi
else
    warn "lib не існує взагалі"
fi

# ═══════════ [1] ДАНІ РАХУНКУ ═══════════
hdr "[1/8] Дані рахунку РБ0518-00742"

BUYER_NAME="Грабовський Олександр Миколайович"
BUYER_IPN="2937002115"
SELLER_NAME="ТОВ КОМФІ ТРЕЙД"
SELLER_EDRPOU="36962487"
SELLER_WALLET="0x66434c5501242ccC71b5a39C765892921624B66c"
INV_NO="РБ0518-00742"
INV_DATE="2026-10-06"
AMOUNT_WEI="137475000000000000000000"
TOKEN="0x74dA52028E42A37bc89E05c2fD5c52daBE4CB48f"
DECIMALS=18

say "  Buyer:  $BUYER_NAME ($BUYER_IPN)"
say "  Seller: $SELLER_NAME ($SELLER_EDRPOU)"
say "  Amount: $AMOUNT_WEI wei"

# ═══════════ [2] СТВОРЮЮ КОНТРАКТ НАПРЯМУ ═══════════
hdr "[2/8] Створюю контракт (direct write)"

# ─── Генерую ID ───
CID="C-INV-$(date -u +%Y%m%d%H%M%S)-$(head -c 4 /dev/urandom | od -An -tx1 | tr -d ' \n')"
F="$CONTRACTS/$CID.env"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# ─── Розрахунок ліцензій (1%+1%+1% = 3% від суми) ───
AMOUNT_INT="$AMOUNT_WEI"
LIC_A=$(( AMOUNT_INT / 100 ))
LIC_B=$(( AMOUNT_INT / 100 ))
CF_FEE=$(( AMOUNT_INT / 100 ))
LIC_TOTAL=$(( LIC_A + LIC_B + CF_FEE ))
NET=$(( AMOUNT_INT - LIC_TOTAL ))

RECIPIENT="0x66434c5501242ccC71b5a39C765892921624B66c"
DEADLINE="$(date -u -d '+72 hours' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
    || date -u -d "@$(( $(date +%s) + 72*3600 ))" +%Y-%m-%dT%H:%M:%SZ)"

cat > "$F" <<ENV_END
CONTRACT_ID=$CID
CREATED_AT=$NOW
PATCH_ID=CYBRA-M19-COMFY-0001
CONTRACT_TYPE=INVOICE

# ─── Рахунок ───
INVOICE_NO=$INV_NO
INVOICE_DATE=$INV_DATE

# ─── Сторони ───
BUYER=$BUYER_WALLET
BUYER_NAME=$BUYER_NAME
BUYER_IPN=$BUYER_IPN

SELLER=$SELLER_WALLET
SELLER_NAME=$SELLER_NAME
SELLER_EDRPOU=$SELLER_EDRPOU

# ─── Сума ───
TOKEN=$TOKEN
DECIMALS=$DECIMALS
AMOUNT_WEI=$AMOUNT_WEI

# ─── License 1%+1%+1% ───
LICENSE_A_WEI=$LIC_A
LICENSE_A_PERCENT=1
LICENSE_A_BPS=100
LICENSE_A_RECIPIENT=$RECIPIENT

LICENSE_B_WEI=$LIC_B
LICENSE_B_PERCENT=1
LICENSE_B_BPS=100
LICENSE_B_RECIPIENT=$RECIPIENT

CREATION_FEE_WEI=$CF_FEE
CREATION_FEE_PERCENT=1
CREATION_FEE_FIXED_WEI=0
CREATION_FEE_RECIPIENT=$RECIPIENT
CREATION_FEE_BUYER=$BUYER_WALLET
CREATION_FEE_FROZEN=TRUE

LICENSE_TOTAL_WEI=$LIC_TOTAL
NET_WEI=$NET
DUAL_LICENSE_FROZEN=TRUE

# ─── Chain ───
CHAIN_ID=56
NETWORK=BSC_MAINNET

# ─── Stage ───
STAGE=DRAFT
STATUS=CREATED
BUYER_CONFIRMED=FALSE
SELLER_CONFIRMED=FALSE
RECEIPT_CONFIRMED=FALSE
BUYER_CONFIRMED_AT=
SELLER_CONFIRMED_AT=
RECEIPT_CONFIRMED_AT=
BUYER_LINK_ID=
SELLER_LINK_ID=
RECEIPT_LINK_ID=
BUYER_LINK_HASH=
SELLER_LINK_HASH=
RECEIPT_LINK_HASH=

# ─── Refund ───
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

# ─── Safety ───
REAL_TRANSACTION_SENT=FALSE
GLOBAL_TRUE_100=FALSE
ENV_END

ok "CONTRACT_ID: $CID"
ok "  File: $F"
printf '%s' "$CID" > "$ROOT/.last_contract_id"

# ─── Ledger записи ───
{
    printf '%s | %s | A | %s | %s | %s\n' "$NOW" "$CID" "$AMOUNT_INT" "$LIC_A" "$RECIPIENT"
} >> "$EVIDENCE/license_ledger.txt"

{
    printf '%s | %s | B | %s | %s | %s\n' "$NOW" "$CID" "$AMOUNT_INT" "$LIC_B" "$RECIPIENT"
} >> "$EVIDENCE/license_ledger_b.txt"

{
    printf '%s | %s | %s | %s | %s | %s\n' "$NOW" "$CID" "$BUYER_WALLET" "$AMOUNT_INT" "$CF_FEE" "$RECIPIENT"
} >> "$EVIDENCE/creation_license_ledger.txt"

ok "ledger: A/B/Creation записано"

# ═══════════ [3] ПОЗИЦІЇ ═══════════
hdr "[3/8] Додаю 5 позицій"

LINES_FILE="$CONTRACTS/$CID.lines"
TOTAL_ITEMS=0

# Формат: CODE|NAME|QTY|PRICE_IN_KOPIYKY
ITEMS=(
    "3984343|Смартфон Samsung Galaxy Fold 8 16/1Tb Graphite|1|8174833"
    "3909742|Послуга Comfort Upgrade 2 роки|1|2452500"
    "2908219|Мережевий зарядний пристрій Samsung Trio 65W 2 Type-C+USB|1|204083"
    "3799926|Батарея мобільна Pitaka Aramid Fiber Magnetic Qi2 5000mAh Sunset|1|333250"
    "4061288|Чохол для смартфону Pitaka Edge Ultra-Slim Case Twill Black/Grey|1|291583"
)

: > "$LINES_FILE"
IDX=0
for item in "${ITEMS[@]}"; do
    IDX=$((IDX+1))
    IFS='|' read -r CODE NAME QTY PRICE <<< "$item"
    LINE_SUM=$(( QTY * PRICE ))
    TOTAL_ITEMS=$(( TOTAL_ITEMS + LINE_SUM ))
    printf '%s|%s|%s|%s|%s\n' "$CODE" "$NAME" "$QTY" "$PRICE" "$LINE_SUM" >> "$LINES_FILE"
    ok "[$IDX] $CODE  $QTY × $PRICE = $LINE_SUM коп."
done

ok "Разом позицій: $IDX"
ok "Сума позицій: $TOTAL_ITEMS коп. ($(awk -v s="$TOTAL_ITEMS" 'BEGIN{printf "%.2f", s/100}') грн)"

# Записую суму позицій у контракт
printf 'INVOICE_ITEMS_TOTAL_KOP=%s\n' "$TOTAL_ITEMS" >> "$F"
printf 'INVOICE_ITEMS_COUNT=%s\n' "$IDX" >> "$F"

# ─── Terms ───
TERMS_FILE="$CONTRACTS/$CID.terms"
cat > "$TERMS_FILE" <<TERMS
CYBRA CONTRACT TERMS
Contract: $CID
Invoice:  $INV_NO ($INV_DATE)
Generated: $NOW

1. Продавець: $SELLER_NAME (ЄДРПОУ $SELLER_EDRPOU)
2. Покупець:  $BUYER_NAME (ІПН $BUYER_IPN)
3. Сума:      137 475,00 грн (у т.ч. ПДВ 22 912,51 грн)
4. Позицій:   $IDX
5. Ліцензія:  1% + 1% + 1% = 3% → $RECIPIENT
6. Refund:    72 години з моменту створення
7. Chain:     BSC (56)
8. Auto-exec: FALSE (немає auto-transaction)
TERMS
TERMS_HASH="$(sha256sum "$TERMS_FILE" | awk '{print $1}')"
printf 'TERMS_HASH=%s\n' "$TERMS_HASH" >> "$F"
ok "terms: $TERMS_FILE"

# ═══════════ [4] ЛІНКИ ═══════════
hdr "[4/8] Генерую лінки BUYER / SELLER / RECEIPT"

gen_link() {
    local role="$1"
    local LID="L-${role}-$(head -c 4 /dev/urandom | od -An -tx1 | tr -d ' \n')"
    local LF="$LINKS/$LID.link"
    local LH
    LH="$(printf 'CYBRA|%s|%s|%s|%s' "$CID" "$role" "$NOW" "$LID" | sha256sum | awk '{print $1}')"

    cat > "$LF" <<LNK
LINK_ID=$LID
CONTRACT_ID=$CID
ROLE=$role
CREATED_AT=$NOW
STATUS=PENDING
LINK_HASH=$LH
CONFIRMED_AT=
CONFIRMED_BY=
LNK

    # Оновлюю контракт
    case "$role" in
        BUYER)   sed -i "s|^BUYER_LINK_ID=.*|BUYER_LINK_ID=$LID|"   "$F"
                 sed -i "s|^BUYER_LINK_HASH=.*|BUYER_LINK_HASH=$LH|" "$F" ;;
        SELLER)  sed -i "s|^SELLER_LINK_ID=.*|SELLER_LINK_ID=$LID|" "$F"
                 sed -i "s|^SELLER_LINK_HASH=.*|SELLER_LINK_HASH=$LH|" "$F" ;;
        RECEIPT) sed -i "s|^RECEIPT_LINK_ID=.*|RECEIPT_LINK_ID=$LID|" "$F"
                 sed -i "s|^RECEIPT_LINK_HASH=.*|RECEIPT_LINK_HASH=$LH|" "$F" ;;
    esac

    printf '%s' "$LID"
}

L_BUYER="$(gen_link BUYER)"
L_SELLER="$(gen_link SELLER)"
L_RECEIPT="$(gen_link RECEIPT)"

sed -i "s|^STAGE=DRAFT|STAGE=LINKED|" "$F"

ok "BUYER:   $L_BUYER"
ok "SELLER:  $L_SELLER"
ok "RECEIPT: $L_RECEIPT"

# ─── URL-и ───
URL_SELLER="cybra://confirm?seller=$L_SELLER&contract=$CID"
URL_BUYER="cybra://confirm?buyer=$L_BUYER&contract=$CID"

# ═══════════ [5] ЛИСТ ДЛЯ КОМФІ ═══════════
hdr "[5/8] Формую лист для Комфі"

EML="$OUT_DIR/${CID}_comfy.eml"
SUBJECT="Підтвердження контракту $CID (рахунок $INV_NO)"

cat > "$EML" <<EML_END
From: noreply@cybra.local
To: $COMFY_EMAIL
Subject: $SUBJECT
MIME-Version: 1.0
Content-Type: text/plain; charset=UTF-8
X-CYBRA-Contract: $CID
X-CYBRA-Link-Seller: $L_SELLER

Шановні ТОВ "КОМФІ ТРЕЙД"!

Покупець Грабовський Олександр Миколайович (ІПН 2937002115)
підтверджує замовлення за рахунком № $INV_NO від $INV_DATE
на суму 137 475,00 грн.

Для підтвердження з боку продавця, будь ласка, перейдіть за посиланням:

  $URL_SELLER

Посилання підтверджує:
  • факт узгодження умов замовлення
  • фіксацію на стороні продавця
  • активацію refund-механізму (72 год)

Деталі контракту:
  Contract ID:   $CID
  Рахунок:       $INV_NO
  Дата:          $INV_DATE
  Покупець:      Грабовський О.М.
  Сума:          137 475,00 UAH
  Token (BSC):   $TOKEN
  Chain:         BSC (56)
  Позицій:       $IDX

Після підтвердження продавцем, контракт переходить у стадію SELLER_OK.

---
CYBRA Contract Platform
Contract: $CID
Generated: $NOW
EML_END

ok "лист: $EML"

# ═══════════ [6] METAMASK PAYLOAD ═══════════
hdr "[6/8] MetaMask payload"

MM_PAYLOAD="$(printf 'CYBRA|%s|BUYER|%s' "$CID" "$BUYER_WALLET" | sha256sum | awk '{print $1}')"

cat > "$OUT_DIR/${CID}_metamask.json" <<MM
{
  "domain": {"name":"CYBRA Contract","version":"1.1","chainId":56,"verifyingContract":"$RECIPIENT"},
  "primaryType": "Contract",
  "message": {
    "contractId": "$CID",
    "invoice": "$INV_NO",
    "buyer": "$BUYER_WALLET",
    "seller": "$SELLER_WALLET",
    "amountWei": "$AMOUNT_WEI",
    "role": "BUYER",
    "action": "CONFIRM_CONTRACT",
    "signatureDigest": "$MM_PAYLOAD"
  },
  "types": {
    "Contract": [
      {"name":"contractId","type":"string"},
      {"name":"invoice","type":"string"},
      {"name":"buyer","type":"address"},
      {"name":"seller","type":"address"},
      {"name":"amountWei","type":"string"},
      {"name":"role","type":"string"},
      {"name":"action","type":"string"},
      {"name":"signatureDigest","type":"string"}
    ]
  }
}
MM
ok "MetaMask: $OUT_DIR/${CID}_metamask.json"

# ═══════════ [7] ВІДПРАВКА EMAIL ═══════════
hdr "[7/8] Відправка листа"

SENT=0
MSMTP_RC="$ROOT/modules/module_35_cybra_guardian/data/.msmtprc"

if command -v msmtp >/dev/null 2>&1 && [ -f "$MSMTP_RC" ]; then
    if msmtp --file="$MSMTP_RC" -t < "$EML" 2>>"$LOG"; then
        ok "лист відправлено через msmtp → $COMFY_EMAIL"
        SENT=1
    else
        warn "msmtp error — див. $LOG"
    fi
fi

if [ "$SENT" -eq 0 ]; then
    # Fallback: mailto
    BODY_ENC="$(printf 'Contract: %s\n\nConfirm seller via:\n%s\n' "$CID" "$URL_SELLER" | sed 's/ /%20/g;s/\n/%0A/g')"
    MAILTO="mailto:$COMFY_EMAIL?subject=$(printf '%s' "$SUBJECT" | sed 's/ /%20/g')&body=$BODY_ENC"
    printf '%s\n' "$MAILTO" > "$OUT_DIR/${CID}_mailto.txt"
    ok "mailto: $OUT_DIR/${CID}_mailto.txt"
    say ""
    say "  ${Y}Email автоматично НЕ відправлено — SMTP не налаштовано.${Z}"
    say "  ${C}Відкрийте це посилання вручну:${Z}"
    say "  $MAILTO"
fi

# ═══════════ [8] METAMASK ПІДПИС ═══════════
hdr "[8/8] Ваше підтвердження через MetaMask"

SIGN_FILE="$OUT_DIR/${CID}_buyer_sign.txt"
cat > "$SIGN_FILE" <<SIGN
CYBRA CONTRACT CONFIRMATION
Contract:  $CID
Invoice:   $INV_NO
Role:      BUYER
Buyer:     $BUYER_WALLET
Seller:    $SELLER_WALLET
Amount:    $AMOUNT_WEI wei
Chain:     BSC (56)
Action:    CONFIRM_CONTRACT
Digest:    $MM_PAYLOAD
Timestamp: $NOW
SIGN

say ""
say "  ${B}Адреса:${Z}  $BUYER_WALLET"
say "  ${B}Мережа:${Z}  BNB Smart Chain"
say ""
say "  ${C}Крок 1:${Z} Відкрийте MetaMask → переключіться на BNB Smart Chain"
say "  ${C}Крок 2:${Z} Натисніть 'Sign Message'"
say "  ${C}Крок 3:${Z} Вставте цей текст:"
say ""
sed 's/^/    /' "$SIGN_FILE"
say ""
say "  ${C}Крок 4:${Z} Після підпису поверніться сюди"
say ""

printf '  Підписали? [y/N]: '
read -r ANS

if [ "$ANS" = "y" ] || [ "$ANS" = "Y" ]; then
    # Оновлюю контракт
    sed -i "s|^BUYER_CONFIRMED=.*|BUYER_CONFIRMED=TRUE|"   "$F"
    sed -i "s|^BUYER_CONFIRMED_AT=.*|BUYER_CONFIRMED_AT=$NOW|" "$F"
    sed -i "s|^STAGE=LINKED|STAGE=BUYER_OK|" "$F"

    # Оновлюю лінк
    sed -i "s|^STATUS=PENDING|STATUS=CONFIRMED|"       "$LINKS/$L_BUYER.link"
    sed -i "s|^CONFIRMED_AT=.*|CONFIRMED_AT=$NOW|"     "$LINKS/$L_BUYER.link"
    sed -i "s|^CONFIRMED_BY=.*|CONFIRMED_BY=$BUYER_WALLET|" "$LINKS/$L_BUYER.link"

    printf '%s' "$MM_PAYLOAD" > "$EVIDENCE/${CID}_buyer.sig"

    ok "BUYER підтверджено (stage=BUYER_OK)"
else
    warn "BUYER ще не підтверджено — зробіть це пізніше через TUI [5]"
fi

# ═══════════ AUTOSAVE + PUSH ═══════════
hdr "Autosave + push"

AS="$ROOT/modules/module_35_cybra_guardian/bin/autosave.sh"
if [ -f "$AS" ]; then
    source "$AS" 2>/dev/null
    as_save_local "$CID" 2>/dev/null && ok "local archive"
    as_save_git     "$CID" 2>/dev/null && ok "git push"
else
    if [ -d "$GITMOD/.git" ]; then
        cd "$GITMOD" || exit 1
        mkdir -p contracts
        cp "$CONTRACTS/$CID"* contracts/ 2>/dev/null
        git add -A 2>/dev/null
        git commit -m "COMFY INVOICE $CID $(date -u +%Y%m%dT%H%M%SZ)" 2>&1 | tail -2
        git push 2>&1 | tail -2
        cd "$ROOT" || exit 1
    fi
fi

# ─── Baseline ───
NEW_HASH="$(
    cd "$M19" || exit 1
    find . -type f ! -name '*.log' ! -name '*.test.log' \
        ! -name 'test_output.txt' ! -name 'test_output.sha256' \
        ! -name 'SNAPSHOT_SHA256.txt' ! -name '*.bak.*' \
        -print0 2>/dev/null |
    sort -z | xargs -0 -r sha256sum 2>/dev/null |
    sha256sum | awk '{print $1}'
)"
printf '%s' "$NEW_HASH" > "$BASELINE/module_19_contract_tui_menu.tree"
printf '%s' "$NEW_HASH" > "$EVO_DIR/module_19_contract_tui_menu.approved"

# ═══════════ SUMMARY ═══════════
hdr "ГОТОВО"

say ""
say "  ${B}CONTRACT:${Z}   $CID"
say "  ${B}Buyer:${Z}      Грабовський О.М. ($BUYER_WALLET)"
say "  ${B}Seller:${Z}     ТОВ КОМФІ ТРЕЙД ($COMFY_EMAIL)"
say "  ${B}Amount:${Z}     137 475,00 UAH = $AMOUNT_WEI wei"
say "  ${B}Pozicij:${Z}     $IDX"
say "  ${B}Stage:${Z}      $(grep -m1 '^STAGE=' "$F" | cut -d= -f2-)"
say "  ${B}Chain:${Z}      BSC (56)"
say ""
say "  ${C}Файли:${Z}"
say "    Контракт:           $F"
say "    Позиції:            $LINES_FILE"
say "    Terms:              $TERMS_FILE"
say "    Лист для Комфі:     $EML"
say "    MetaMask payload:   $OUT_DIR/${CID}_metamask.json"
say "    Підпис BUYER:       $SIGN_FILE"
say "    Лінк SELLER:        $L_SELLER"
say ""
say "  ${C}Перевірка:${Z}"
say "    cybra → [2]  Список контрактів"
say "    cybra → [3]  Статус → $CID"
say "    cybra → [20] Refund статус"
say ""
say "  Log: $LOG"
say ""
exit 0
