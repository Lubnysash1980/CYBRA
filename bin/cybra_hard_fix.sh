#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# CYBRA HARD FIX — жорстке виправлення всього
# 1. Rates system (USD/UAH/EUR/BNB → CYBRA)
# 2. Hard preflight errors
# 3. Self-heal (автовідновлення)
# 4. Dual-backend для контрактів
# 5. Auto-detect ownership
# ============================================================

set -u
export LC_ALL=C

ROOT="$HOME/CYBRA"
MOD="$ROOT/modules/module_19_contract_tui_menu"
LIB="$MOD/bin/cybra_tui_lib.sh"
MENU="$MOD/bin/cybra_menu.sh"
EVO_DIR="$ROOT/evolution"
BASELINE="$ROOT/baseline"
LOGS="$ROOT/logs"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
LOG="$LOGS/hard_fix_${STAMP}.log"

mkdir -p "$LOGS" "$MOD/state" "$MOD/evidence" "$EVO_DIR" "$MOD/backups"

log() { printf '%s\n' "$*" | tee -a "$LOG"; }
head1() {
    printf -- '\n============================================================\n' | tee -a "$LOG"
    printf -- ' %s\n' "$*" | tee -a "$LOG"
    printf -- '============================================================\n' | tee -a "$LOG"
}

# ============================================================
# PRE-APPROVE
# ============================================================

head1 "[0] Pre-approve module_19"

PRE_HASH="$(cat "$BASELINE/module_19_contract_tui_menu.tree" 2>/dev/null || echo NONE)"
printf '%s' "$PRE_HASH" > "$EVO_DIR/module_19_contract_tui_menu.approved"
log "  pre-approved: ${PRE_HASH:0:16}..."

# ============================================================
# 1. RATES SYSTEM
# ============================================================

head1 "[1/6] RATES SYSTEM"

RATES_FILE="$MOD/state/rates.env"

if [ ! -f "$RATES_FILE" ]; then
    cat > "$RATES_FILE" <<'RATES'
# CYBRA RATES — оновлюй тут
# Формат: RATE_<FROM>_<TO>=value (скільки TO за 1 FROM)

# Fiat → USD
RATE_UAH_USD=0.0242
RATE_EUR_USD=1.0870
RATE_PLN_USD=0.2500
RATE_GBP_USD=1.2700

# USD → Fiat
RATE_USD_UAH=41.30
RATE_USD_EUR=0.9200
RATE_USD_PLN=4.0000
RATE_USD_GBP=0.7874

# CYBRA (умовний токен) → USD
RATE_CYBRA_USD=0.10

# USD → CYBRA
RATE_USD_CYBRA=10.00

# Default currency для відображення
DEFAULT_DISPLAY_CURRENCY=USD

# Decimals для fiat
FIAT_DECIMALS=2
RATES
    log "  [OK] rates.env створено"
else
    log "  [OK] rates.env існує"
fi

# --- Додаємо функції конвертації в lib ---
cat >> "$LIB" <<'RATES_LIB'

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

RATES_LIB

chmod +x "$LIB"
log "  [OK] rate functions added"

# ============================================================
# 2. HARD PREFLIGHT (жорсткі помилки)
# ============================================================

head1 "[2/6] HARD PREFLIGHT"

PREFLIGHT="$MOD/bin/cybra_preflight.sh"

cat > "$PREFLIGHT" <<'PREFLIGHT_EOF'
#!/data/data/com.termux/files/usr/bin/bash
# CYBRA HARD PREFLIGHT — показує жорсткі помилки з інструкціями

CYBRA_MOD19_ROOT="$HOME/CYBRA/modules/module_19_contract_tui_menu"
CYBRA_CONTRACTS="$CYBRA_MOD19_ROOT/contracts"

PREFLIGHT_PASS=0
PREFLIGHT_FAIL=0

# --- Кольори ---
if [ -t 1 ]; then
    R=$'\033[31m'; G=$'\033[32m'; Y=$'\033[33m'; B=$'\033[1m'; Z=$'\033[0m'
else
    R=""; G=""; Y=""; B=""; Z=""
fi

ph_ok()   { printf '  %s[OK]%s %s\n' "$G" "$Z" "$1"; PREFLIGHT_PASS=$((PREFLIGHT_PASS+1)); }
ph_err()  { printf '  %s[FIX]%s %s\n' "$R" "$Z" "$1"; PREFLIGHT_FAIL=$((PREFLIGHT_FAIL+1)); }
ph_warn() { printf '  %s[WARN]%s %s\n' "$Y" "$Z" "$1"; }

cybra_preflight() {
    PREFLIGHT_PASS=0
    PREFLIGHT_FAIL=0

    printf '%s=== CYBRA PREFLIGHT ===%s\n' "$B" "$Z"

    # --- 1. Essential dirs ---
    for d in "$CYBRA_CONTRACTS" "$CYBRA_MOD19_ROOT/links" "$CYBRA_MOD19_ROOT/evidence" "$CYBRA_MOD19_ROOT/state"; do
        if [ -d "$d" ]; then
            ph_ok "dir: $(basename "$d")"
        else
            mkdir -p "$d"
            ph_warn "dir created: $(basename "$d")"
        fi
    done

    # --- 2. Essential files ---
    for f in \
        "$CYBRA_MOD19_ROOT/bin/cybra_tui_lib.sh" \
        "$CYBRA_MOD19_ROOT/bin/cybra_menu.sh" \
        "$CYBRA_MOD19_ROOT/state/config.env"
    do
        if [ -f "$f" ]; then
            ph_ok "file: $(basename "$f")"
        else
            ph_err "MISSING: $f → запусти: cybra_self_heal"
        fi
    done

    # --- 3. Ledgers ---
    for l in \
        "$CYBRA_MOD19_ROOT/evidence/license_ledger.txt" \
        "$CYBRA_MOD19_ROOT/evidence/license_ledger_b.txt" \
        "$CYBRA_MOD19_ROOT/evidence/creation_license_ledger.txt" \
        "$CYBRA_MOD19_ROOT/evidence/refund_ledger.txt"
    do
        if [ -f "$l" ]; then
            ph_ok "ledger: $(basename "$l")"
        else
            touch "$l"
            ph_warn "ledger init: $(basename "$l")"
        fi
    done

    # --- 4. Syntax check ---
    for f in "$CYBRA_MOD19_ROOT/bin/cybra_tui_lib.sh" "$CYBRA_MOD19_ROOT/bin/cybra_menu.sh"; do
        [ ! -f "$f" ] && continue
        if bash -n "$f" 2>/dev/null; then
            ph_ok "syntax: $(basename "$f")"
        else
            ph_err "SYNTAX ERROR in $f → запусти: cybra_self_heal"
        fi
    done

    # --- 5. Owner ---
    if [ -f "$HOME/CYBRA/.owner" ]; then
        ph_ok "owner marker"
    else
        ph_err "owner missing → запусти: cybra_hard_fix"
    fi

    # --- 6. Frozen ---
    if [ -f "$HOME/CYBRA/evolution/FROZEN" ]; then
        ph_err "СИСТЕМА FROZEN → cybra_evo unfreeze"
    else
        ph_ok "not frozen"
    fi

    # --- 7. Rates ---
    if [ -f "$CYBRA_MOD19_ROOT/state/rates.env" ]; then
        ph_ok "rates"
    else
        ph_warn "rates.env missing → створиться автоматично"
    fi

    # --- 8. Refund schema check (per contract) ---
    local bad_contracts=0
    local total_contracts=0
    for f in "$CYBRA_CONTRACTS"/*.env; do
        [ -f "$f" ] || continue
        total_contracts=$((total_contracts+1))

        # Обов'язкові поля
        for key in REFUND_ENABLED BUYER_FINAL_DECISION REFUND_STATUS; do
            if ! grep -qm1 "^${key}=" "$f"; then
                ph_err "contract $(basename "$f" .env) missing $key"
                bad_contracts=$((bad_contracts+1))
                break
            fi
        done
    done

    if [ "$total_contracts" -eq 0 ]; then
        ph_warn "немає контрактів (це ок для першого запуску)"
    elif [ "$bad_contracts" -eq 0 ]; then
        ph_ok "all contracts valid ($total_contracts)"
    fi

    printf -- '------------------------\n'
    printf '  PASS: %s  FAIL: %s\n' "$PREFLIGHT_PASS" "$PREFLIGHT_FAIL"

    if [ "$PREFLIGHT_FAIL" -eq 0 ]; then
        printf '  %s✓ PREFLIGHT OK%s\n' "$G" "$Z"
        return 0
    else
        printf '  %s✗ PREFLIGHT FAILED — виправ помилки вище%s\n' "$R" "$Z"
        return 1
    fi
}

# Якщо скрипт викликано напряму — запустити
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    cybra_preflight
fi
PREFLIGHT_EOF

chmod +x "$PREFLIGHT"
log "  [OK] preflight створено"

# ============================================================
# 3. SELF-HEAL (автовідновлення)
# ============================================================

head1 "[3/6] SELF-HEAL"

SELFHEAL="$MOD/bin/cybra_self_heal.sh"

cat > "$SELFHEAL" <<'SELFHEAL_EOF'
#!/data/data/com.termux/files/usr/bin/bash
# CYBRA SELF-HEAL — автовідновлення пошкоджених файлів

set -u

ROOT="$HOME/CYBRA"
MOD="$ROOT/modules/module_19_contract_tui_menu"
BACKUP="$MOD/backups"
SNAPSHOT="$MOD/snapshot"

mkdir -p "$BACKUP" "$SNAPSHOT"

HEALED=0

heal_file() {
    local name="$1"
    local live="$MOD/bin/$name"
    local snap="$SNAPSHOT/$name"
    local bak="$BACKUP/$name"

    if [ -f "$live" ] && bash -n "$live" 2>/dev/null; then
        # Живий файл OK — оновлюємо backup
        cp "$live" "$bak" 2>/dev/null || true
        return 0
    fi

    # Спроба відновити
    printf '  [HEAL] %s — пошкоджено, відновлюю...\n' "$name"

    if [ -f "$snap" ] && bash -n "$snap" 2>/dev/null; then
        cp "$snap" "$live"
        printf '    → відновлено з snapshot\n'
        HEALED=$((HEALED+1))
        return 0
    fi

    if [ -f "$bak" ] && bash -n "$bak" 2>/dev/null; then
        cp "$bak" "$live"
        printf '    → відновлено з backup\n'
        HEALED=$((HEALED+1))
        return 0
    fi

    printf '    → %s[FAIL]%s немає валідної копії\n' $'\033[31m' $'\033[0m'
    return 1
}

cybra_self_heal() {
    printf '=== CYBRA SELF-HEAL ===\n'

    for f in cybra_tui_lib.sh cybra_menu.sh; do
        heal_file "$f"
    done

    # Решта файлів
    for f in "$MOD"/bin/*.sh; do
        [ -f "$f" ] || continue
        local name="$(basename "$f")"
        [ "$name" = "cybra_tui_lib.sh" ] || [ "$name" = "cybra_menu.sh" ] && continue

        # Просто перевіряємо синтаксис
        if ! bash -n "$f" 2>/dev/null; then
            printf '  [WARN] %s — syntax error\n' "$name"
        fi
    done

    printf -- '----------------\n'
    if [ "$HEALED" -eq 0 ]; then
        printf '  ✓ Все OK\n'
    else
        printf '  Healed: %s\n' "$HEALED"
    fi
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    cybra_self_heal
fi
SELFHEAL_EOF

chmod +x "$SELFHEAL"
log "  [OK] self-heal створено"

# ============================================================
# 4. DUAL-BACKEND для контрактів
# ============================================================

head1 "[4/6] DUAL-BACKEND для контрактів"

cat >> "$LIB" <<'DUAL_LIB'

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

DUAL_LIB

chmod +x "$LIB"
log "  [OK] dual-backend для контрактів"

# ============================================================
# 5. AUTO-DETECT OWNERSHIP
# ============================================================

head1 "[5/6] AUTO-DETECT OWNERSHIP"

OWNERSHIP_FILE="$MOD/state/ownership.manifest"

cat > "$OWNERSHIP_FILE" <<'OWN'
# CYBRA MODULE 19 — OWNERSHIP MANIFEST
# Файли що належать цьому модулю (авто-детект)

# Бінарні скрипти
bin/cybra_tui_lib.sh
bin/cybra_menu.sh
bin/cybra_preflight.sh
bin/cybra_self_heal.sh

# State
state/config.env
state/rates.env
state/ownership.manifest

# Rules
rules/*.canonical

# Tests
tests/run_tests.sh

# Snapshot
snapshot/*

# Evidence (ledgers)
evidence/license_ledger.txt
evidence/license_ledger_b.txt
evidence/creation_license_ledger.txt
evidence/refund_ledger.txt
evidence/tui_rules.txt
evidence/rules.sha256
evidence/debug.log

# Contracts (user data)
contracts/*.env
contracts/*.lines
contracts/*.terms
contracts/*.parties
contracts/*.input

# Links (user data)
links/*.link
OWN

cat >> "$LIB" <<'OWN_LIB'

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

OWN_LIB

chmod +x "$LIB"
log "  [OK] ownership system"

# ============================================================
# 6. MENU — нові пункти
# ============================================================

head1 "[6/6] MENU UPDATE"

python3 - <<'PY'
import re
p = "/data/data/com.termux/files/home/CYBRA/modules/module_19_contract_tui_menu/bin/cybra_menu.sh"
with open(p) as f: s = f.read()

# --- Rewrite print_menu ---
lines = s.split('\n')
START = None
END = None
for i, line in enumerate(lines):
    if line.startswith('print_menu() {'):
        START = i
    if START is not None and i > START and line.strip() == '}':
        END = i
        break

if START is not None and END is not None:
    new_menu = '''print_menu() {
    printf '%s\\n' "  ${C_BOLD}[1]${C_RESET}  Створити контракт"
    printf '%s\\n' "  ${C_BOLD}[2]${C_RESET}  Список контрактів"
    printf '%s\\n' "  ${C_BOLD}[3]${C_RESET}  Статус контракту"
    printf '%s\\n' "  ${C_BOLD}[4]${C_RESET}  Згенерувати лінки"
    printf '%s\\n' "  ${C_BOLD}[5]${C_RESET}  Підтвердити лінк"
    printf '%s\\n' "  ${C_BOLD}[6]${C_RESET}  Debug"
    printf '%s\\n' "  ${C_BOLD}[7]${C_RESET}  DUAL-LICENSE ledger"
    printf '%s\\n' "  ${C_BOLD}[8]${C_RESET}  CREATION-LICENSE ledger"
    printf '%s\\n' "  ${C_BOLD}[9]${C_RESET}  Hardening"
    printf '%s\\n' "${C_CYAN}  ── INVOICE ──${C_RESET}"
    printf '%s\\n' "  ${C_BOLD}[11]${C_RESET} Створити INVOICE"
    printf '%s\\n' "  ${C_BOLD}[12]${C_RESET} Додати позицію"
    printf '%s\\n' "  ${C_BOLD}[13]${C_RESET} Показати INVOICE"
    printf '%s\\n' "  ${C_BOLD}[14]${C_RESET} Фіналізувати INVOICE"
    printf '%s\\n' "${C_CYAN}  ── REFUND ──${C_RESET}"
    printf '%s\\n' "  ${C_BOLD}[18]${C_RESET} Фінальне рішення покупця"
    printf '%s\\n' "  ${C_BOLD}[19]${C_RESET} Перевірити timeout"
    printf '%s\\n' "  ${C_BOLD}[20]${C_RESET} Статус refund"
    printf '%s\\n' "  ${C_BOLD}[21]${C_RESET} Додати умову"
    printf '%s\\n' "${C_CYAN}  ── PII ──${C_RESET}"
    printf '%s\\n' "  ${C_BOLD}[15]${C_RESET} Експорт PII-masked"
    printf '%s\\n' "  ${C_BOLD}[16]${C_RESET} Експорт усіх + git"
    printf '%s\\n' "  ${C_BOLD}[17]${C_RESET} Перевірити PII хеш"
    printf '%s\\n' "${C_CYAN}  ── CURRENCY ──${C_RESET}"
    printf '%s\\n' "  ${C_BOLD}[22]${C_RESET} Показати курси валют"
    printf '%s\\n' "  ${C_BOLD}[23]${C_RESET} Оновити курс"
    printf '%s\\n' "  ${C_BOLD}[24]${C_RESET} Конвертер валют"
    printf '%s\\n' "${C_CYAN}  ── SYSTEM ──${C_RESET}"
    printf '%s\\n' "  ${C_BOLD}[30]${C_RESET} Preflight (перевірка)"
    printf '%s\\n' "  ${C_BOLD}[31]${C_RESET} Self-heal (автовідновлення)"
    printf '%s\\n' "  ${C_BOLD}[32]${C_RESET} Dual-backend verify"
    printf '%s\\n' "  ${C_BOLD}[33]${C_RESET} Ownership scan"
    printf '%s\\n' "  ${C_BOLD}[0]${C_RESET}  Вихід"
    printf '\\n'
}'''
    lines[START:END+1] = new_menu.split('\n')
    s = '\n'.join(lines)

# --- Додаємо action-функції ---
if 'action_show_rates' not in s:
    funcs = '''action_show_rates() {
    source "$HOME/CYBRA/modules/module_19_contract_tui_menu/bin/cybra_tui_lib.sh"
    cybra_show_rates
}

action_update_rate() {
    printf 'RATE_KEY (наприклад RATE_USD_UAH): '; read -r KEY
    printf 'VALUE: '; read -r VAL
    local rf="$HOME/CYBRA/modules/module_19_contract_tui_menu/state/rates.env"
    if grep -q "^${KEY}=" "$rf"; then
        sed -i "s|^${KEY}=.*|${KEY}=${VAL}|" "$rf"
    else
        printf '%s=%s\\n' "$KEY" "$VAL" >> "$rf"
    fi
    printf '%s\\n' "${C_GREEN}OK${C_RESET}"
}

action_convert() {
    source "$HOME/CYBRA/modules/module_19_contract_tui_menu/bin/cybra_tui_lib.sh"
    printf 'Сума: '; read -r AMT
    printf 'З валюти (USD/UAH/EUR/CYBRA): '; read -r FROM
    printf 'У валюту (USD/UAH/EUR/CYBRA): '; read -r TO

    FROM="$(printf '%s' "$FROM" | tr '[:lower:]' '[:upper:]')"
    TO="$(printf '%s' "$TO" | tr '[:lower:]' '[:upper:]')"

    case "${FROM}_${TO}" in
        *_CYBRA)
            local wei="$(cybra_currency_to_cybra "$AMT" "$FROM" 18)"
            local dec="$(awk -v w="$wei" 'BEGIN { printf "%.6f", w / 1000000000000000000 }')"
            printf '  %s %s = %s CYBRA (wei: %s)\\n' "$AMT" "$FROM" "$dec" "$wei"
            ;;
        CYBRA_*)
            printf '  Введи wei: '; read -r WEI
            local res="$(cybra_cybra_to_currency "$WEI" "$TO" 18)"
            printf '  %s wei = %s %s\\n' "$WEI" "$res" "$TO"
            ;;
        *)
            printf '  Пряма конвертація не підтримується, використовуй через USD\\n'
            ;;
    esac
}

action_preflight() {
    source "$HOME/CYBRA/modules/module_19_contract_tui_menu/bin/cybra_preflight.sh"
    cybra_preflight
}

action_self_heal() {
    source "$HOME/CYBRA/modules/module_19_contract_tui_menu/bin/cybra_self_heal.sh"
    cybra_self_heal
}

action_dual_verify() {
    source "$HOME/CYBRA/modules/module_19_contract_tui_menu/bin/cybra_tui_lib.sh"
    printf 'CONTRACT_ID: '; read -r CID
    printf 'Computed hash...\\n'
    cybra_contract_compute_dual_hash "$CID" >/dev/null
    local v="$(cybra_contract_verify_dual "$CID")"
    printf 'Result: %s\\n' "$v"
}

action_ownership() {
    source "$HOME/CYBRA/modules/module_19_contract_tui_menu/bin/cybra_tui_lib.sh"
    cybra_ownership_scan
}

'''
    s = s.replace("print_header() {", funcs + "print_header() {", 1)

# --- Case update ---
new_case = '''case "$CHOICE" in
        1) action_create_contract ;;
        2) action_list_contracts ;;
        3) action_show_status ;;
        4) action_generate_links ;;
        5) action_confirm_link ;;
        6) action_debug ;;
        7) action_dual_license_ledger ;;
        8) action_creation_license ;;
        9) action_hardening ;;
        11) action_create_invoice ;;
        12) action_add_line ;;
        13) action_show_invoice ;;
        14) action_finalize_invoice ;;
        15) action_export_masked ;;
        16) action_export_all_masked ;;
        17) action_verify_pii ;;
        18) action_buyer_final_decision ;;
        19) action_check_timeouts ;;
        20) action_refund_status ;;
        21) action_add_term ;;
        22) action_show_rates ;;
        23) action_update_rate ;;
        24) action_convert ;;
        30) action_preflight ;;
        31) action_self_heal ;;
        32) action_dual_verify ;;
        33) action_ownership ;;
        0|q|Q|exit|quit)
            printf "%s\\n" "${C_GREEN}До побачення.${C_RESET}"
            exit 0
            ;;
        *)
            printf "%s\\n" "${C_RED}Невідома опція.${C_RESET}"
            ;;
    esac'''

s = re.sub(r'case "\$CHOICE" in.*?esac', new_case, s, count=1, flags=re.DOTALL)

with open(p, "w") as f: f.write(s)
print("[FIXED] menu extended with currency + system")
PY

# --- Auto-heal + preflight при старті ---
python3 - <<'PY'
p = "/data/data/com.termux/files/home/CYBRA/modules/module_19_contract_tui_menu/bin/cybra_menu.sh"
with open(p) as f: s = f.read()

# Додаємо self-heal перед main loop
if 'cybra_self_heal' not in s:
    marker = 'while true; do'
    pre = '''# --- Auto self-heal on start ---
if [ -f "$HOME/CYBRA/modules/module_19_contract_tui_menu/bin/cybra_self_heal.sh" ]; then
    source "$HOME/CYBRA/modules/module_19_contract_tui_menu/bin/cybra_self_heal.sh" 2>/dev/null || true
    cybra_self_heal >/dev/null 2>&1 || true
fi

while true; do'''
    if marker in s:
        s = s.replace(marker, pre, 1)

with open(p, "w") as f: f.write(s)
print("[FIXED] auto self-heal on start")
PY

chmod +x "$MENU"

# --- Синтаксис ---
log ""
log "  Синтаксис:"
bash -n "$LIB"  && log "    [OK] lib"  || { log "    [FAIL] lib"; }
bash -n "$MENU" && log "    [OK] menu" || { log "    [FAIL] menu"; }
bash -n "$PREFLIGHT" && log "    [OK] preflight" || true
bash -n "$SELFHEAL" && log "    [OK] self-heal" || true

# ============================================================
# RE-SEAL + BASELINE + APPROVE
# ============================================================

head1 "RE-SEAL"

cp "$LIB"  "$MOD/snapshot/cybra_tui_lib.sh"
cp "$MENU" "$MOD/snapshot/cybra_menu.sh"
cp "$PREFLIGHT" "$MOD/snapshot/cybra_preflight.sh"
cp "$SELFHEAL"  "$MOD/snapshot/cybra_self_heal.sh"

rm -f "$MOD/snapshot/final_manifest.sha256"
(
    cd "$MOD/snapshot" || exit 1
    find . -type f ! -name 'final_manifest.sha256' ! -name '*.log' -print0 |
    sort -z | xargs -0 -r sha256sum 2>/dev/null
) > "$MOD/snapshot/final_manifest.sha256"

NEW_HASH="$(
    cd "$MOD" || exit 1
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

log "  [OK] hash: ${NEW_HASH:0:16}..."

# ============================================================
# PREFLIGHT + SELF-HEAL TEST
# ============================================================

head1 "TEST"

log ""
log "--- Self-heal ---"
bash "$SELFHEAL"

log ""
log "--- Preflight ---"
bash "$PREFLIGHT"

# ============================================================
# GIT PUSH
# ============================================================

head1 "GIT PUSH"

cd "$ROOT/git_module" 2>/dev/null && {
    git add -A 2>/dev/null
    if ! git diff --cached --quiet 2>/dev/null; then
        git commit -m "CYBRA hard fix: rates + preflight + self-heal + dual-backend + ownership $STAMP" 2>&1 | tail -2 | tee -a "$LOG"
        git push 2>&1 | tail -2 | tee -a "$LOG"
    else
        log "  немає змін"
    fi
}

head1 "DONE"
log ""
log " Меню: cybra"
log ""
log " Нові пункти:"
log "   [22] Показати курси"
log "   [23] Оновити курс"
log "   [24] Конвертер (USD/UAH/EUR ↔ CYBRA)"
log "   [30] Preflight"
log "   [31] Self-heal"
log "   [32] Dual-backend verify"
log "   [33] Ownership scan"
log ""
log " Log: $LOG"
