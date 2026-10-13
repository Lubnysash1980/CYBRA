#!/data/data/com.termux/files/usr/bin/bash
# CYBRA TUI Library — canonical

CYBRA_MOD19_ROOT="$HOME/CYBRA/modules/module_19_contract_tui_menu"
CYBRA_CONTRACTS="$CYBRA_MOD19_ROOT/contracts"
CYBRA_LINKS="$CYBRA_MOD19_ROOT/links"
CYBRA_DEBUG="$CYBRA_MOD19_ROOT/evidence/debug.log"
CYBRA_LICENSE_LEDGER="$CYBRA_MOD19_ROOT/evidence/license_ledger.txt"
CYBRA_LICENSE_LEDGER_B="$CYBRA_MOD19_ROOT/evidence/license_ledger_b.txt"
CYBRA_CREATION_LEDGER="$CYBRA_MOD19_ROOT/evidence/creation_license_ledger.txt"

LICENSE_A_RECIPIENT="0x66434c5501242ccC71b5a39C765892921624B66c"
LICENSE_A_PERCENT=1
LICENSE_A_BPS=100

LICENSE_B_RECIPIENT="0x66434c5501242ccC71b5a39C765892921624B66c"
LICENSE_B_PERCENT=1
LICENSE_B_BPS=100

DUAL_LICENSE_ENABLED=TRUE

LICENSE_RECIPIENT="0x66434c5501242ccC71b5a39C765892921624B66c"
LICENSE_PERCENT="$LICENSE_A_PERCENT"

CREATION_FEE_ENABLED=TRUE
CREATION_FEE_RECIPIENT="0x66434c5501242ccC71b5a39C765892921624B66c"
CREATION_FEE_PERCENT=1
CREATION_FEE_BPS=100
CREATION_FEE_FIXED_WEI=0
CREATION_FEE_MIN_WEI=0
CREATION_FEE_MAX_WEI=0

mkdir -p "$CYBRA_CONTRACTS" "$CYBRA_LINKS" "$(dirname "$CYBRA_DEBUG")"

[ -f "$CYBRA_LICENSE_LEDGER" ] || touch "$CYBRA_LICENSE_LEDGER"
[ -f "$CYBRA_LICENSE_LEDGER_B" ] || touch "$CYBRA_LICENSE_LEDGER_B"
[ -f "$CYBRA_CREATION_LEDGER" ] || touch "$CYBRA_CREATION_LEDGER"

if [ -t 1 ]; then
    C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'
    C_RED=$'\033[31m'; C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'; C_BLUE=$'\033[34m'
    C_CYAN=$'\033[36m'; C_GREY=$'\033[90m'
else
    C_RESET=""; C_BOLD=""; C_RED=""; C_GREEN=""
    C_YELLOW=""; C_BLUE=""; C_CYAN=""; C_GREY=""
fi

cybra_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
cybra_log() { printf '%s | %s\n' "$(cybra_now)" "$*" >> "$CYBRA_DEBUG"; }
cybra_hash() { sha256sum | awk '{print $1}'; }
cybra_rand_id() { head -c 8 /dev/urandom | od -An -tx1 | tr -d ' \n'; }

cybra_calc_license() {
    local amount="$1"
    [[ "$amount" =~ ^[0-9]+$ ]] || { echo 0; return 1; }
    echo $(( amount * LICENSE_A_PERCENT / 100 ))
}

cybra_calc_creation_fee() {
    local amount="$1"
    [[ "$amount" =~ ^[0-9]+$ ]] || { echo 0; return 1; }
    local var=$(( amount * CREATION_FEE_PERCENT / 100 ))
    echo $(( CREATION_FEE_FIXED_WEI + var ))
}

cybra_license_record() {
    local cid="$1" amt="$2" la="$3" lb="$4"
    printf '%s | %s | A | %s | %s | %s\n' "$(cybra_now)" "$cid" "$amt" "$la" "0x66434c5501242ccC71b5a39C765892921624B66c" >> "$CYBRA_LICENSE_LEDGER"
    printf '%s | %s | B | %s | %s | %s\n' "$(cybra_now)" "$cid" "$amt" "$lb" "0x66434c5501242ccC71b5a39C765892921624B66c" >> "$CYBRA_LICENSE_LEDGER_B"
    cybra_log "LICENSE_RECORDED $cid A=$la B=$lb"
}

cybra_creation_license_record() {
    local cid="$1" amt="$2" fee="$3" buyer="$4"
    printf '%s | %s | %s | %s | %s | %s\n' "$(cybra_now)" "$cid" "$buyer" "$amt" "$fee" "0x66434c5501242ccC71b5a39C765892921624B66c" >> "$CYBRA_CREATION_LEDGER"
    cybra_log "CREATION_LICENSE $cid fee=$fee"
}

cybra_contract_path() { echo "$CYBRA_CONTRACTS/$1.env"; }
cybra_contract_exists() { [ -f "$(cybra_contract_path "$1")" ]; }

cybra_contract_create() {
    local buyer="$1" seller="$2" amount="$3" token="$4"
    local decimals="${5:-18}"

    [ -z "$buyer" ] && { echo "ERROR: buyer required" >&2; return 1; }
    [ -z "$seller" ] && { echo "ERROR: seller required" >&2; return 1; }
    [ -z "$amount" ] && { echo "ERROR: amount required" >&2; return 1; }
    [ "$buyer" = "$seller" ] && { echo "ERROR: buyer=seller" >&2; return 1; }
    [[ "$amount" =~ ^[0-9]+$ ]] && [ "$amount" -gt 0 ] || { echo "ERROR: amount>0" >&2; return 1; }

    local cid="C-$(date -u +%Y%m%d%H%M%S)-$(cybra_rand_id)"
    local refund_deadline="$(cybra_refund_deadline)"
    local la="$(cybra_calc_license "$amount")"
    local lb="$(cybra_calc_license "$amount")"
    local cf="$(cybra_calc_creation_fee "$amount")"
    local total=$(( la + lb + cf ))
    local net=$(( amount - total ))
    local now="$(cybra_now)"
    local f="$CYBRA_CONTRACTS/$cid.env"

    cat > "$f" <<CTR
CONTRACT_ID=$cid
CREATED_AT=$now
PATCH_ID=CYBRA-M19-PATCH-0002

BUYER=$buyer
SELLER=$seller
TOKEN=$token
TOKEN_DECIMALS=$decimals

AMOUNT_WEI=$amount
LICENSE_A_WEI=$la
LICENSE_A_PERCENT=1
LICENSE_A_BPS=100
LICENSE_A_RECIPIENT=0x66434c5501242ccC71b5a39C765892921624B66c
LICENSE_B_WEI=$lb
LICENSE_B_PERCENT=1
LICENSE_B_BPS=100
LICENSE_B_RECIPIENT=0x66434c5501242ccC71b5a39C765892921624B66c
CREATION_FEE_WEI=$cf
CREATION_FEE_PERCENT=$CREATION_FEE_PERCENT
CREATION_FEE_FIXED_WEI=$CREATION_FEE_FIXED_WEI
CREATION_FEE_RECIPIENT=0x66434c5501242ccC71b5a39C765892921624B66c
CREATION_FEE_BUYER=$buyer
CREATION_FEE_FROZEN=TRUE
LICENSE_TOTAL_WEI=$total
NET_WEI=$net
DUAL_LICENSE_FROZEN=TRUE

CHAIN_ID=56
NETWORK=BSC_MAINNET
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
# === REFUND (обов'язковий) ===
REFUND_ENABLED=TRUE
REFUND_TIMEOUT_HOURS=72
REFUND_DEADLINE=$refund_deadline
BUYER_FINAL_DECISION=PENDING
BUYER_FINAL_DECISION_AT=
FINAL_DELIVERY_ALLOWED=FALSE
REFUND_STATUS=PENDING
REFUND_TRIGGER=
REFUND_AMOUNT_WEI=0
REFUND_RECIPIENT=
REFUNDED_AT=
CUSTOM_TERMS_COUNT=0


REAL_TRANSACTION_SENT=FALSE
GLOBAL_TRUE_100=FALSE
CTR

    # --- AUTO-DUAL-HASH ---
    if declare -f cybra_contract_compute_dual_hash >/dev/null 2>&1; then
        cybra_contract_compute_dual_hash "$cid" >/dev/null 2>&1 || true
    fi

    cybra_license_record "$cid" "$amount" "$la" "$lb"
    cybra_creation_license_record "$cid" "$amount" "$cf" "$buyer"
    cybra_log "CONTRACT_CREATED $cid"

    echo "$cid"
}

cybra_link_path() { echo "$CYBRA_LINKS/$1.link"; }

cybra_link_generate() {
    local cid="$1" role="$2"

    cybra_contract_exists "$cid" || { echo "ERROR: contract not found" >&2; return 1; }
    case "$role" in BUYER|SELLER|RECEIPT) ;; *) echo "ERROR: role" >&2; return 1 ;; esac

    local lid="L-$role-$(cybra_rand_id)"
    local now="$(cybra_now)"
    local payload="CYBRA|$cid|$role|$now|$lid"
    local lh="$(printf '%s' "$payload" | cybra_hash)"
    local lf="$CYBRA_LINKS/$lid.link"

    cat > "$lf" <<LNK
LINK_ID=$lid
CONTRACT_ID=$cid
ROLE=$role
CREATED_AT=$now
STATUS=PENDING
LINK_HASH=$lh
LINK_PAYLOAD=$payload
CONFIRMED_AT=
CONFIRMED_BY=
LNK

    local cf="$CYBRA_CONTRACTS/$cid.env"
    case "$role" in
        BUYER)   sed -i "s|^BUYER_LINK_ID=.*|BUYER_LINK_ID=$lid|" "$cf"; sed -i "s|^BUYER_LINK_HASH=.*|BUYER_LINK_HASH=$lh|" "$cf" ;;
        SELLER)  sed -i "s|^SELLER_LINK_ID=.*|SELLER_LINK_ID=$lid|" "$cf"; sed -i "s|^SELLER_LINK_HASH=.*|SELLER_LINK_HASH=$lh|" "$cf" ;;
        RECEIPT) sed -i "s|^RECEIPT_LINK_ID=.*|RECEIPT_LINK_ID=$lid|" "$cf"; sed -i "s|^RECEIPT_LINK_HASH=.*|RECEIPT_LINK_HASH=$lh|" "$cf" ;;
    esac
    grep -q '^STAGE=DRAFT' "$cf" && sed -i "s|^STAGE=DRAFT|STAGE=LINKED|" "$cf"

    cybra_log "LINK_GENERATED $cid $role $lid"
    echo "$lid"
}

cybra_link_confirm() {
    local lid="$1" who="$2"
    local lf="$CYBRA_LINKS/$lid.link"
    [ -f "$lf" ] || { echo "ERROR: link not found" >&2; return 1; }

    local status="$(grep '^STATUS=' "$lf" | cut -d= -f2)"
    [ "$status" = "CONFIRMED" ] && { echo "ERROR: already confirmed" >&2; return 1; }

    local cid="$(grep '^CONTRACT_ID=' "$lf" | cut -d= -f2)"
    local role="$(grep '^ROLE=' "$lf" | cut -d= -f2)"
    local now="$(cybra_now)"

    sed -i "s|^STATUS=.*|STATUS=CONFIRMED|" "$lf"
    sed -i "s|^CONFIRMED_AT=.*|CONFIRMED_AT=$now|" "$lf"
    sed -i "s|^CONFIRMED_BY=.*|CONFIRMED_BY=$who|" "$lf"

    local cf="$CYBRA_CONTRACTS/$cid.env"
    case "$role" in
        BUYER)   sed -i "s|^BUYER_CONFIRMED=.*|BUYER_CONFIRMED=TRUE|" "$cf"; sed -i "s|^BUYER_CONFIRMED_AT=.*|BUYER_CONFIRMED_AT=$now|" "$cf"; grep -q '^STAGE=LINKED' "$cf" && sed -i "s|^STAGE=LINKED|STAGE=BUYER_OK|" "$cf" ;;
        SELLER)  sed -i "s|^SELLER_CONFIRMED=.*|SELLER_CONFIRMED=TRUE|" "$cf"; sed -i "s|^SELLER_CONFIRMED_AT=.*|SELLER_CONFIRMED_AT=$now|" "$cf"; grep -q '^STAGE=BUYER_OK' "$cf" && sed -i "s|^STAGE=BUYER_OK|STAGE=SELLER_OK|" "$cf" ;;
        RECEIPT) sed -i "s|^RECEIPT_CONFIRMED=.*|RECEIPT_CONFIRMED=TRUE|" "$cf"; sed -i "s|^RECEIPT_CONFIRMED_AT=.*|RECEIPT_CONFIRMED_AT=$now|" "$cf"; grep -q '^STAGE=SELLER_OK' "$cf" && sed -i "s|^STAGE=SELLER_OK|STAGE=RECEIPT_OK|" "$cf" ;;
    esac

    local b="$(grep '^BUYER_CONFIRMED=' "$cf" | cut -d= -f2)"
    local s="$(grep '^SELLER_CONFIRMED=' "$cf" | cut -d= -f2)"
    local r="$(grep '^RECEIPT_CONFIRMED=' "$cf" | cut -d= -f2)"
    if [ "$b" = "TRUE" ] && [ "$s" = "TRUE" ] && [ "$r" = "TRUE" ]; then
        sed -i "s|^STAGE=.*|STAGE=COMPLETE|" "$cf"
        sed -i "s|^STATUS=.*|STATUS=COMPLETE|" "$cf"
        cybra_log "CONTRACT_COMPLETE $cid"
    fi

    cybra_log "LINK_CONFIRMED $lid $role by=$who"
    echo "OK: $role confirmed for $cid"
}

# Aliases для тестів
CREATION_LICENSE_LEDGER="$CYBRA_CREATION_LEDGER"
LICENSE_LEDGER="$CYBRA_LICENSE_LEDGER"
LICENSE_LEDGER_B="$CYBRA_LICENSE_LEDGER_B"
export CREATION_LICENSE_LEDGER LICENSE_LEDGER LICENSE_LEDGER_B

# ------------------------------------------------------------
# AMOUNT CONVERTER: human → wei (з decimals)
# ------------------------------------------------------------

cybra_amount_to_wei() {
    local input="$1"
    local decimals="${2:-18}"

    # Якщо чисте ціле і decimals=0 — повертаємо як є
    if [[ "$input" =~ ^[0-9]+$ ]]; then
        # Якщо decimals=18 і число < 1e6 — ймовірно це wei вже
        if [ "$decimals" = "18" ] && [ "${#input}" -ge 15 ]; then
            echo "$input"
            return 0
        fi
        # Інакше — множимо на 10^decimals
        local mult="1"
        local i=0
        while [ "$i" -lt "$decimals" ]; do
            mult="${mult}0"
            i=$((i+1))
        done
        echo $(( input * 10**decimals )) 2>/dev/null || echo "$input$mult"
        return 0
    fi

    # Десятковий формат
    if [[ "$input" =~ ^[0-9]+\.[0-9]+$ ]]; then
        local whole="${input%.*}"
        local frac="${input#*.}"

        while [ "${#frac}" -lt "$decimals" ]; do
            frac="${frac}0"
        done
        frac="${frac:0:$decimals}"

        [ -z "$whole" ] && whole="0"
        local result="${whole}${frac}"
        result="$(printf '%s' "$result" | sed 's/^0*//')"
        [ -z "$result" ] && result="0"
        echo "$result"
        return 0
    fi

    echo "0"
    return 1
}

# ============================================================
# PII MASKING — SHA-256 для експорту
# ============================================================

# Маска для PII: NAME, IPN, EDRPOU, ADDRESS
# Salt фіксований — щоб hash був детермінований (для перевірки)

CYBRA_PII_SALT="CYBRA_PII_SALT_v1_2026"

cybra_pii_hash() {
    local value="$1"
    [ -z "$value" ] && { echo "EMPTY"; return; }
    printf '%s|%s' "$CYBRA_PII_SALT" "$value" | sha256sum | awk '{print $1}'
}

# --- Короткий хеш для відображення (перші 16 символів) ---
cybra_pii_short() {
    local value="$1"
    [ -z "$value" ] && { echo "EMPTY"; return; }
    local h="$(cybra_pii_hash "$value")"
    echo "${h:0:16}"
}

# --- Повний хеш для машинної перевірки ---
cybra_pii_full() {
    local value="$1"
    cybra_pii_hash "$value"
}

# ------------------------------------------------------------
# Експорт контракту з маскованими PII
# ------------------------------------------------------------
cybra_export_masked() {
    local cid="$1"
    local out_dir="${2:-$HOME/CYBRA/public/contracts}"

    local f="$CYBRA_CONTRACTS/$cid.env"
    [ ! -f "$f" ] && {
        echo "ERROR: contract not found" >&2
        return 1
    }

    mkdir -p "$out_dir"

    local buyer_name="$(grep '^BUYER_NAME=' "$f" | cut -d= -f2-)"
    local buyer_ipn="$(grep '^BUYER_IPN=' "$f" | cut -d= -f2-)"
    local seller_name="$(grep '^SELLER_NAME=' "$f" | cut -d= -f2-)"
    local seller_edrpou="$(grep '^SELLER_EDRPOU=' "$f" | cut -d= -f2-)"

    local buyer_name_hash="$(cybra_pii_hash "$buyer_name")"
    local buyer_ipn_hash="$(cybra_pii_hash "$buyer_ipn")"
    local seller_name_hash="$(cybra_pii_hash "$seller_name")"
    local seller_edrpou_hash="$(cybra_pii_hash "$seller_edrpou")"

    # --- Masked .env ---
    local out_env="$out_dir/$cid.masked.env"
    sed \
        -e "s|^BUYER_NAME=.*|BUYER_NAME=sha256:$buyer_name_hash|" \
        -e "s|^BUYER_IPN=.*|BUYER_IPN=sha256:$buyer_ipn_hash|" \
        -e "s|^SELLER_NAME=.*|SELLER_NAME=sha256:$seller_name_hash|" \
        -e "s|^SELLER_EDRPOU=.*|SELLER_EDRPOU=sha256:$seller_edrpou_hash|" \
        "$f" > "$out_env"

    # --- Masked .parties ---
    if [ -f "$CYBRA_CONTRACTS/$cid.parties" ]; then
        sed \
            -e "s|^name=.*|name=sha256:$buyer_name_hash|" \
            -e "s|^ipn=.*|ipn=sha256:$buyer_ipn_hash|" \
            "$CYBRA_CONTRACTS/$cid.parties" \
            | awk -v sn="$seller_name_hash" -v se="$seller_edrpou_hash" '
                /^\[SELLER\]/ { seller=1 }
                seller && /^name=/ { print "name=sha256:"sn; next }
                seller && /^edrpou=/ { print "edrpou=sha256:"se; next }
                { print }
            ' > "$out_dir/$cid.masked.parties"
    fi

    # --- Masked .lines (товари — це не PII, копіюємо як є) ---
    [ -f "$CYBRA_CONTRACTS/$cid.lines" ] && \
        cp "$CYBRA_CONTRACTS/$cid.lines" "$out_dir/$cid.masked.lines"

    # --- Masked .terms (умови — публічні) ---
    [ -f "$CYBRA_CONTRACTS/$cid.terms" ] && \
        cp "$CYBRA_CONTRACTS/$cid.terms" "$out_dir/$cid.masked.terms"

    # --- PII manifest (для перевірки при потребі) ---
    cat > "$out_dir/$cid.pii_manifest" <<PIINFO
# PII MASK MANIFEST
# CONTRACT_ID=$cid
# MASKED_AT=$(cybra_now)
# ALGORITHM=sha256
# SALT_FINGERPRINT=$(printf '%s' "$CYBRA_PII_SALT" | sha256sum | awk '{print $1}' | head -c 16)

[BUYER]
name_hash=$buyer_name_hash
ipn_hash=$buyer_ipn_hash

[SELLER]
name_hash=$seller_name_hash
edrpou_hash=$seller_edrpou_hash

# Для верифікації: cybra_pii_hash "ПІБ" → повинно співпасти
PIINFO

    # --- Хеш експорту ---
    (
        cd "$out_dir" || exit 1
        sha256sum "$cid.masked."* 2>/dev/null
    ) > "$out_dir/$cid.export.sha256"

    local export_hash="$(sha256sum "$out_dir/$cid.export.sha256" | awk '{print $1}')"

    cybra_log "PII_EXPORT $cid export_hash=$export_hash"

    printf '%s\n' "$export_hash"
}

# ------------------------------------------------------------
# Масовий експорт всіх контрактів
# ------------------------------------------------------------
cybra_export_all_masked() {
    local out_dir="${1:-$HOME/CYBRA/public/contracts}"
    mkdir -p "$out_dir"

    local count=0
    for f in "$CYBRA_CONTRACTS"/*.env; do
        [ -f "$f" ] || continue
        local cid="$(basename "$f" .env)"
        local h="$(cybra_export_masked "$cid" "$out_dir")"
        printf '  %s → %s\n' "$cid" "${h:0:16}..."
        count=$((count+1))
    done

    printf '\n Експортовано: %d контрактів\n' "$count"
    printf ' Шлях: %s\n' "$out_dir"
}

# ------------------------------------------------------------
# Перевірка: чи PII співпадає з хешем
# ------------------------------------------------------------
cybra_pii_verify() {
    local value="$1"
    local expected_hash="$2"
    local computed="$(cybra_pii_hash "$value")"

    if [ "$computed" = "$expected_hash" ]; then
        echo "MATCH"
        return 0
    else
        echo "MISMATCH"
        return 1
    fi
}

# ============================================================
# PII MASKING — SHA-256 для експорту
# ============================================================

# Маска для PII: NAME, IPN, EDRPOU, ADDRESS
# Salt фіксований — щоб hash був детермінований (для перевірки)

CYBRA_PII_SALT="CYBRA_PII_SALT_v1_2026"

cybra_pii_hash() {
    local value="$1"
    [ -z "$value" ] && { echo "EMPTY"; return; }
    printf '%s|%s' "$CYBRA_PII_SALT" "$value" | sha256sum | awk '{print $1}'
}

# --- Короткий хеш для відображення (перші 16 символів) ---
cybra_pii_short() {
    local value="$1"
    [ -z "$value" ] && { echo "EMPTY"; return; }
    local h="$(cybra_pii_hash "$value")"
    echo "${h:0:16}"
}

# --- Повний хеш для машинної перевірки ---
cybra_pii_full() {
    local value="$1"
    cybra_pii_hash "$value"
}

# ------------------------------------------------------------
# Експорт контракту з маскованими PII
# ------------------------------------------------------------
cybra_export_masked() {
    local cid="$1"
    local out_dir="${2:-$HOME/CYBRA/public/contracts}"

    local f="$CYBRA_CONTRACTS/$cid.env"
    [ ! -f "$f" ] && {
        echo "ERROR: contract not found" >&2
        return 1
    }

    mkdir -p "$out_dir"

    local buyer_name="$(grep '^BUYER_NAME=' "$f" | cut -d= -f2-)"
    local buyer_ipn="$(grep '^BUYER_IPN=' "$f" | cut -d= -f2-)"
    local seller_name="$(grep '^SELLER_NAME=' "$f" | cut -d= -f2-)"
    local seller_edrpou="$(grep '^SELLER_EDRPOU=' "$f" | cut -d= -f2-)"

    local buyer_name_hash="$(cybra_pii_hash "$buyer_name")"
    local buyer_ipn_hash="$(cybra_pii_hash "$buyer_ipn")"
    local seller_name_hash="$(cybra_pii_hash "$seller_name")"
    local seller_edrpou_hash="$(cybra_pii_hash "$seller_edrpou")"

    # --- Masked .env ---
    local out_env="$out_dir/$cid.masked.env"
    sed \
        -e "s|^BUYER_NAME=.*|BUYER_NAME=sha256:$buyer_name_hash|" \
        -e "s|^BUYER_IPN=.*|BUYER_IPN=sha256:$buyer_ipn_hash|" \
        -e "s|^SELLER_NAME=.*|SELLER_NAME=sha256:$seller_name_hash|" \
        -e "s|^SELLER_EDRPOU=.*|SELLER_EDRPOU=sha256:$seller_edrpou_hash|" \
        "$f" > "$out_env"

    # --- Masked .parties ---
    if [ -f "$CYBRA_CONTRACTS/$cid.parties" ]; then
        sed \
            -e "s|^name=.*|name=sha256:$buyer_name_hash|" \
            -e "s|^ipn=.*|ipn=sha256:$buyer_ipn_hash|" \
            "$CYBRA_CONTRACTS/$cid.parties" \
            | awk -v sn="$seller_name_hash" -v se="$seller_edrpou_hash" '
                /^\[SELLER\]/ { seller=1 }
                seller && /^name=/ { print "name=sha256:"sn; next }
                seller && /^edrpou=/ { print "edrpou=sha256:"se; next }
                { print }
            ' > "$out_dir/$cid.masked.parties"
    fi

    # --- Masked .lines (товари — це не PII, копіюємо як є) ---
    [ -f "$CYBRA_CONTRACTS/$cid.lines" ] && \
        cp "$CYBRA_CONTRACTS/$cid.lines" "$out_dir/$cid.masked.lines"

    # --- Masked .terms (умови — публічні) ---
    [ -f "$CYBRA_CONTRACTS/$cid.terms" ] && \
        cp "$CYBRA_CONTRACTS/$cid.terms" "$out_dir/$cid.masked.terms"

    # --- PII manifest (для перевірки при потребі) ---
    cat > "$out_dir/$cid.pii_manifest" <<PIINFO
# PII MASK MANIFEST
# CONTRACT_ID=$cid
# MASKED_AT=$(cybra_now)
# ALGORITHM=sha256
# SALT_FINGERPRINT=$(printf '%s' "$CYBRA_PII_SALT" | sha256sum | awk '{print $1}' | head -c 16)

[BUYER]
name_hash=$buyer_name_hash
ipn_hash=$buyer_ipn_hash

[SELLER]
name_hash=$seller_name_hash
edrpou_hash=$seller_edrpou_hash

# Для верифікації: cybra_pii_hash "ПІБ" → повинно співпасти
PIINFO

    # --- Хеш експорту ---
    (
        cd "$out_dir" || exit 1
        sha256sum "$cid.masked."* 2>/dev/null
    ) > "$out_dir/$cid.export.sha256"

    local export_hash="$(sha256sum "$out_dir/$cid.export.sha256" | awk '{print $1}')"

    cybra_log "PII_EXPORT $cid export_hash=$export_hash"

    printf '%s\n' "$export_hash"
}

# ------------------------------------------------------------
# Масовий експорт всіх контрактів
# ------------------------------------------------------------
cybra_export_all_masked() {
    local out_dir="${1:-$HOME/CYBRA/public/contracts}"
    mkdir -p "$out_dir"

    local count=0
    for f in "$CYBRA_CONTRACTS"/*.env; do
        [ -f "$f" ] || continue
        local cid="$(basename "$f" .env)"
        local h="$(cybra_export_masked "$cid" "$out_dir")"
        printf '  %s → %s\n' "$cid" "${h:0:16}..."
        count=$((count+1))
    done

    printf '\n Експортовано: %d контрактів\n' "$count"
    printf ' Шлях: %s\n' "$out_dir"
}

# ------------------------------------------------------------
# Перевірка: чи PII співпадає з хешем
# ------------------------------------------------------------
cybra_pii_verify() {
    local value="$1"
    local expected_hash="$2"
    local computed="$(cybra_pii_hash "$value")"

    if [ "$computed" = "$expected_hash" ]; then
        echo "MATCH"
        return 0
    else
        echo "MISMATCH"
        return 1
    fi
}

# ============================================================
# REFUND МЕХАНІЗМ — обов'язковий для КОЖНОГО контракту
# ============================================================

CYBRA_REFUND_DEFAULT_TIMEOUT_HOURS=72

# ---
# Обчислити deadline
# ---
cybra_refund_deadline() {
    local hours="${1:-$CYBRA_REFUND_DEFAULT_TIMEOUT_HOURS}"
    # GNU date
    date -u -d "+${hours} hours" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || \
    # busybox fallback
    date -u -d "@$(($(date +%s) + hours * 3600))" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || \
    date -u +%Y-%m-%dT%H:%M:%SZ
}

# ---
# Перевірити чи timeout минув
# ---
cybra_refund_expired() {
    local deadline="$1"
    [ -z "$deadline" ] && return 1

    local now_epoch
    local deadline_epoch

    now_epoch="$(date -u +%s)"
    deadline_epoch="$(date -u -d "$deadline" +%s 2>/dev/null || echo 0)"

    [ "$deadline_epoch" -eq 0 ] && return 1

    [ "$now_epoch" -ge "$deadline_epoch" ]
}

# ---
# Покупець: фінальне рішення
# CONFIRMED = дозволити доставку
# REJECTED = повернути кошти
# ---
cybra_buyer_final_decision() {
    local cid="$1"
    local decision="$2"  # CONFIRMED | REJECTED
    local buyer_wallet="${3:-}"

    local f="$CYBRA_CONTRACTS/$cid.env"
    [ ! -f "$f" ] && { echo "ERROR: contract not found" >&2; return 1; }

    case "$decision" in
        CONFIRMED|REJECTED) ;;
        *) echo "ERROR: decision must be CONFIRMED|REJECTED" >&2; return 1 ;;
    esac

    # Перевірка: чи це справді покупець
    local expected_buyer="$(grep '^BUYER=' "$f" | cut -d= -f2-)"
    if [ -n "$buyer_wallet" ] && [ "$buyer_wallet" != "$expected_buyer" ]; then
        echo "ERROR: wallet mismatch (expected $expected_buyer)" >&2
        return 1
    fi

    local now="$(cybra_now)"

    sed -i "s|^BUYER_FINAL_DECISION=.*|BUYER_FINAL_DECISION=$decision|" "$f"
    sed -i "s|^BUYER_FINAL_DECISION_AT=.*|BUYER_FINAL_DECISION_AT=$now|" "$f"

    if [ "$decision" = "CONFIRMED" ]; then
        sed -i "s|^FINAL_DELIVERY_ALLOWED=.*|FINAL_DELIVERY_ALLOWED=TRUE|" "$f"
        sed -i "s|^REFUND_STATUS=.*|REFUND_STATUS=NOT_REQUIRED|" "$f"
        cybra_log "BUYER_CONFIRMED_FINAL $cid"
        echo "OK: CONFIRMED — продавець може відправляти товар"
    else
        sed -i "s|^FINAL_DELIVERY_ALLOWED=.*|FINAL_DELIVERY_ALLOWED=FALSE|" "$f"
        sed -i "s|^REFUND_STATUS=.*|REFUND_STATUS=PENDING|" "$f"
        sed -i "s|^REFUND_TRIGGER=.*|REFUND_TRIGGER=buyer_reject|" "$f"
        cybra_log "BUYER_REJECTED_FINAL $cid"
        echo "OK: REJECTED — ініційовано refund"

        # Автоматично виконуємо refund
        cybra_execute_refund "$cid" "buyer_reject"
    fi
}

# ---
# Виконати REFUND
# ---
cybra_execute_refund() {
    local cid="$1"
    local trigger="${2:-manual}"

    local f="$CYBRA_CONTRACTS/$cid.env"
    [ ! -f "$f" ] && { echo "ERROR: contract not found" >&2; return 1; }

    local status="$(grep '^REFUND_STATUS=' "$f" | cut -d= -f2)"
    if [ "$status" = "REFUNDED" ]; then
        echo "ERROR: вже повернено" >&2
        return 1
    fi

    local buyer="$(grep '^BUYER=' "$f" | cut -d= -f2-)"
    local net_wei="$(grep '^NET_WEI=' "$f" | cut -d= -f2)"
    local amount_wei="$(grep '^AMOUNT_WEI=' "$f" | cut -d= -f2)"
    local now="$(cybra_now)"

    # Refund = вся сума мінус ліцензія (ліцензія не повертається)
    local refund_amount="$net_wei"

    sed -i "s|^REFUND_STATUS=.*|REFUND_STATUS=REFUNDED|" "$f"
    sed -i "s|^REFUND_TRIGGER=.*|REFUND_TRIGGER=$trigger|" "$f"
    sed -i "s|^REFUND_AMOUNT_WEI=.*|REFUND_AMOUNT_WEI=$refund_amount|" "$f"
    sed -i "s|^REFUND_RECIPIENT=.*|REFUND_RECIPIENT=$buyer|" "$f"
    sed -i "s|^REFUNDED_AT=.*|REFUNDED_AT=$now|" "$f"
    sed -i "s|^STAGE=.*|STAGE=REFUNDED|" "$f"
    sed -i "s|^STATUS=.*|STATUS=REFUNDED|" "$f"

    # Запис в refund ledger
    printf '%s | %s | %s | %s | %s\n' \
        "$now" "$cid" "$buyer" "$refund_amount" "$trigger" \
        >> "$CYBRA_MOD19_ROOT/evidence/refund_ledger.txt"

    cybra_log "REFUND_EXECUTED $cid amount=$refund_amount trigger=$trigger to=$buyer"

    echo "OK: REFUNDED $refund_amount wei → $buyer"
    echo "Trigger: $trigger"
}

# ---
# Перевірити всі контракти на timeout
# ---
cybra_check_all_refunds() {
    local executed=0
    local checked=0

    for f in "$CYBRA_CONTRACTS"/*.env; do
        [ -f "$f" ] || continue
        checked=$((checked+1))

        local cid="$(basename "$f" .env)"
        local stage="$(grep '^STAGE=' "$f" | cut -d= -f2)"
        local decision="$(grep '^BUYER_FINAL_DECISION=' "$f" | cut -d= -f2)"
        local deadline="$(grep '^REFUND_DEADLINE=' "$f" | cut -d= -f2)"
        local refund_status="$(grep '^REFUND_STATUS=' "$f" | cut -d= -f2)"

        # Пропускаємо COMPLETE, REFUNDED, NOT_REQUIRED
        [ "$stage" = "COMPLETE" ] && continue
        [ "$refund_status" = "REFUNDED" ] && continue
        [ "$refund_status" = "NOT_REQUIRED" ] && continue
        [ "$decision" = "CONFIRMED" ] && continue

        # Якщо deadline пройшов і покупець не відповів
        if cybra_refund_expired "$deadline"; then
            if [ "$decision" = "PENDING" ] || [ -z "$decision" ]; then
                printf '  [TIMEOUT] %s — REFUND\n' "$cid"
                cybra_execute_refund "$cid" "timeout" >/dev/null
                executed=$((executed+1))
            fi
        fi
    done

    printf '\n  Перевірено: %s, Refund: %s\n' "$checked" "$executed"
    return 0
}

# ---
# Статус refund
# ---
cybra_refund_status() {
    local cid="$1"
    local f="$CYBRA_CONTRACTS/$cid.env"
    [ ! -f "$f" ] && { echo "ERROR: not found" >&2; return 1; }

    # --- Helper: безпечний grep (перше входження, без дублювання) ---
    local _v
    _get() { grep -m1 "^$1=" "$f" | head -1 | cut -d= -f2-; }

    printf -- '===== REFUND STATUS %s =====\n' "$cid"
    printf 'DEADLINE:       %s\n' "$(_get REFUND_DEADLINE)"
    printf 'TIMEOUT_HOURS:  %s\n' "$(_get REFUND_TIMEOUT_HOURS)"
    printf 'BUYER_DECISION: %s\n' "$(_get BUYER_FINAL_DECISION)"
    printf 'DECISION_AT:    %s\n' "$(_get BUYER_FINAL_DECISION_AT)"
    printf 'DELIVERY_OK:    %s\n' "$(_get FINAL_DELIVERY_ALLOWED)"
    printf 'REFUND_STATUS:  %s\n' "$(_get REFUND_STATUS)"
    printf 'REFUND_TRIGGER: %s\n' "$(_get REFUND_TRIGGER)"
    printf 'REFUND_AMOUNT:  %s\n' "$(_get REFUND_AMOUNT_WEI)"
    printf 'REFUND_TO:      %s\n' "$(_get REFUND_RECIPIENT)"

    local deadline="$(_get REFUND_DEADLINE)"
    if cybra_refund_expired "$deadline"; then
        printf 'EXPIRED:       %sYES%s\n' "$C_RED" "$C_RESET"
    else
        printf 'EXPIRED:       %sNO%s\n' "$C_GREEN" "$C_RESET"
    fi
    printf -- '=============================\n'
}

# ---
# Додати додаткові умови (покупцем)
# ---
cybra_add_custom_term() {
    local cid="$1"
    local term="$2"

    [ -z "$term" ] && { echo "ERROR: empty term" >&2; return 1; }

    local tf="$CYBRA_CONTRACTS/$cid.terms"
    [ ! -f "$tf" ] && { echo "ERROR: terms file missing" >&2; return 1; }

    local now="$(cybra_now)"
    printf '\n[CUSTOM %s] %s\n' "$now" "$term" >> "$tf"

    # Оновити terms_hash
    local new_hash="$(sha256sum "$tf" | awk '{print $1}')"
    sed -i "s|^TERMS_HASH=.*|TERMS_HASH=$new_hash|" "$CYBRA_CONTRACTS/$cid.env"

    cybra_log "CUSTOM_TERM $cid: $term"
    echo "OK: term added"
}

# ============================================================
# RATES & CURRENCY CONVERSION
# ============================================================

CYBRA_RATES_FILE="$CYBRA_MOD19_ROOT/state/rates.env"
[ -f "$CYBRA_RATES_FILE" ] && source "$CYBRA_RATES_FILE"

cybra_rate_get() {
    local from="$1" to="$2"
    local varname="RATE_${from}_${to}"
    eval "echo \"\${$varname:-0}\""
}

cybra_currency_to_usd() {
    local amount="$1" currency="$2"
    currency="$(printf '%s' "$currency" | tr '[:lower:]' '[:upper:]')"

    case "$currency" in
        USD) echo "$amount"; return ;;
    esac

    local rate="$(cybra_rate_get "$currency" "USD")"
    [ "$rate" = "0" ] && { echo "0"; return 1; }

    # Використовуємо awk для float
    awk -v a="$amount" -v r="$rate" 'BEGIN { printf "%.8f", a * r }'
}

cybra_usd_to_currency() {
    local amount="$1" currency="$2"
    currency="$(printf '%s' "$currency" | tr '[:lower:]' '[:upper:]')"

    case "$currency" in
        USD) echo "$amount"; return ;;
    esac

    local rate="$(cybra_rate_get "USD" "$currency")"
    [ "$rate" = "0" ] && { echo "0"; return 1; }

    awk -v a="$amount" -v r="$rate" 'BEGIN { printf "%.8f", a * r }'
}

cybra_currency_to_cybra() {
    local amount="$1" currency="$2" decimals="${3:-18}"
    currency="$(printf '%s' "$currency" | tr '[:lower:]' '[:upper:]')"

    local usd="$(cybra_currency_to_usd "$amount" "$currency")"
    [ -z "$usd" ] || [ "$usd" = "0" ] && { echo "0"; return 1; }

    local cybra_rate="$(cybra_rate_get "USD" "CYBRA")"
    [ "$cybra_rate" = "0" ] && { echo "0"; return 1; }

    # cybra_amount (в одиницях токена) = usd * rate_USD_CYBRA
    local cybra_amount="$(awk -v u="$usd" -v r="$cybra_rate" 'BEGIN { printf "%.10f", u * r }')"

    # Конвертуємо в wei
    cybra_amount_to_wei "$cybra_amount" "$decimals"
}

cybra_cybra_to_currency() {
    local cybra_wei="$1" currency="$2" decimals="${3:-18}"
    currency="$(printf '%s' "$currency" | tr '[:lower:]' '[:upper:]')"

    # wei → токен (ділимо на 10^decimals)
    local mult=1
    local i=0
    while [ "$i" -lt "$decimals" ]; do mult="${mult}0"; i=$((i+1)); done

    local cybra_amount="$(awk -v w="$cybra_wei" -v m="$mult" 'BEGIN { printf "%.10f", w / m }')"

    local usd_rate="$(cybra_rate_get "CYBRA" "USD")"
    local usd="$(awk -v c="$cybra_amount" -v r="$usd_rate" 'BEGIN { printf "%.8f", c * r }')"

    if [ "$currency" = "USD" ]; then
        echo "$usd"
        return
    fi

    cybra_usd_to_currency "$usd" "$currency"
}

cybra_show_rates() {
    printf -- '===== CYBRA RATES =====\n'
    printf '%-8s %-8s %s\n' "FROM" "TO" "RATE"
    printf -- '----\n'
    for k in $(grep '^RATE_' "$CYBRA_RATES_FILE" 2>/dev/null | cut -d= -f1); do
        local v="$(grep "^$k=" "$CYBRA_RATES_FILE" | cut -d= -f2-)"
        printf '%-30s %s\n' "$k" "$v"
    done
    printf -- '=======================\n'
}


# ============================================================
# DUAL-BACKEND для контрактів
# ============================================================

cybra_contract_compute_dual_hash() {
    local cid="$1"
    local f="$CYBRA_CONTRACTS/$cid.env"
    [ ! -f "$f" ] && return 1

    # BACKEND_A: hash від core контракту (без службових полів)
    local a_input="$CYBRA_CONTRACTS/$cid.backend_a.input"
    grep -E '^(CONTRACT_ID|BUYER|SELLER|AMOUNT_WEI|TOKEN|CHAIN_ID|LICENSE_A_WEI|LICENSE_B_WEI|CREATION_FEE_WEI|NET_WEI)=' \
        "$f" | LC_ALL=C sort > "$a_input"
    local a_hash="$(sha256sum "$a_input" | awk '{print $1}')"

    # BACKEND_B: hash від lines + terms + parties (metadata)
    local b_input="$CYBRA_CONTRACTS/$cid.backend_b.input"
    {
        [ -f "$CYBRA_CONTRACTS/$cid.lines" ] && cat "$CYBRA_CONTRACTS/$cid.lines"
        printf '\n---\n'
        [ -f "$CYBRA_CONTRACTS/$cid.terms" ] && cat "$CYBRA_CONTRACTS/$cid.terms"
        printf '\n---\n'
        [ -f "$CYBRA_CONTRACTS/$cid.parties" ] && cat "$CYBRA_CONTRACTS/$cid.parties"
    } > "$b_input"
    local b_hash="$(sha256sum "$b_input" | awk '{print $1}')"

    # Dual
    local dual="$(printf '%s\n%s\n' "$a_hash" "$b_hash" | sha256sum | awk '{print $1}')"

    # Запис в контракт
    sed -i "s|^BACKEND_A_HASH=.*|BACKEND_A_HASH=$a_hash|" "$f" 2>/dev/null || \
        printf 'BACKEND_A_HASH=%s\n' "$a_hash" >> "$f"
    sed -i "s|^BACKEND_B_HASH=.*|BACKEND_B_HASH=$b_hash|" "$f" 2>/dev/null || \
        printf 'BACKEND_B_HASH=%s\n' "$b_hash" >> "$f"
    sed -i "s|^DUAL_HASH=.*|DUAL_HASH=$dual|" "$f" 2>/dev/null || \
        printf 'DUAL_HASH=%s\n' "$dual" >> "$f"

    printf '%s\n' "$dual"
}

cybra_contract_verify_dual() {
    local cid="$1"
    local f="$CYBRA_CONTRACTS/$cid.env"
    [ ! -f "$f" ] && { echo "NOT_FOUND"; return 1; }

    local expected="$(grep -m1 '^DUAL_HASH=' "$f" | cut -d= -f2-)"
    [ -z "$expected" ] && { echo "NO_HASH"; return 1; }

    # Перерахувати
    local a_input="$CYBRA_CONTRACTS/$cid.backend_a.input"
    local b_input="$CYBRA_CONTRACTS/$cid.backend_b.input"
    [ ! -f "$a_input" ] || [ ! -f "$b_input" ] && { echo "NO_INPUT"; return 1; }

    local a="$(sha256sum "$a_input" | awk '{print $1}')"
    local b="$(sha256sum "$b_input" | awk '{print $1}')"
    local computed="$(printf '%s\n%s\n' "$a" "$b" | sha256sum | awk '{print $1}')"

    if [ "$computed" = "$expected" ]; then
        echo "MATCH"
        return 0
    else
        echo "MISMATCH"
        return 1
    fi
}


# ============================================================
# AUTO-DETECT OWNERSHIP
# ============================================================

cybra_is_own_file() {
    local file="$1"
    local manifest="$CYBRA_MOD19_ROOT/state/ownership.manifest"
    [ ! -f "$manifest" ] && return 1

    # Отримуємо відносний шлях від module root
    local rel="${file#$CYBRA_MOD19_ROOT/}"

    while IFS= read -r pattern; do
        [ -z "$pattern" ] && continue
        [ "${pattern:0:1}" = "#" ] && continue

        case "$pattern" in
            *'*'*)
                # glob pattern
                case "$rel" in
                    $pattern) return 0 ;;
                esac
                ;;
            *)
                [ "$rel" = "$pattern" ] && return 0
                ;;
        esac
    done < "$manifest"

    return 1
}

cybra_ownership_scan() {
    printf '=== OWNERSHIP SCAN ===\n'
    local own=0
    local foreign=0

    find "$CYBRA_MOD19_ROOT" -type f 2>/dev/null | while IFS= read -r f; do
        if cybra_is_own_file "$f"; then
            printf '  [OWN]     %s\n' "${f#$CYBRA_MOD19_ROOT/}"
            own=$((own+1))
        else
            printf '  [FOREIGN] %s\n' "${f#$CYBRA_MOD19_ROOT/}"
            foreign=$((foreign+1))
        fi
    done

    printf -- '--------------------\n'
}

cybra_ownership_register() {
    local file="$1"
    local rel="${file#$CYBRA_MOD19_ROOT/}"
    local manifest="$CYBRA_MOD19_ROOT/state/ownership.manifest"

    grep -qxF "$rel" "$manifest" 2>/dev/null && return 0
    printf '%s\n' "$rel" >> "$manifest"
    return 0
}

