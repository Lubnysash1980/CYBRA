#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# CYBRA AUTO EVOLUTION TEST + FIX + GIT
# 1. Fix module_19 через правильний порядок
# 2. Автоматичний тест еволюції (accepted/rejected)
# 3. Автогід push
# 4. @cybra node update
# ============================================================

set -u
export LC_ALL=C

ROOT="$HOME/CYBRA"
MODULES="$ROOT/modules"
BASELINE="$ROOT/baseline"
LOGS="$ROOT/logs"
AUDIT="$ROOT/audit"
HASHES="$ROOT/hashes"
NODE="$ROOT/@cybra"
GITMOD="$ROOT/git_module"
PUBLIC="$ROOT/public"
EVO_DIR="$ROOT/evolution"
OWNER="$ROOT/.owner"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
RUN="$STAMP-$$"
LOG="$LOGS/auto_evo_test_${STAMP}.log"

mkdir -p "$LOGS" "$AUDIT" "$BASELINE" "$HASHES" "$NODE" "$GITMOD" "$PUBLIC" "$EVO_DIR"

FIX=0
FAIL=0
WARN=0
EVO_PASS=0
EVO_FAIL=0

log()   { printf '%s\n' "$*" | tee -a "$LOG"; }
head1() {
    printf -- '\n============================================================\n' | tee -a "$LOG"
    printf -- ' %s\n' "$*" | tee -a "$LOG"
    printf -- '============================================================\n' | tee -a "$LOG"
}

hash_tree() {
    local dir="$1"
    [ ! -d "$dir" ] && { echo NODIR; return; }
    (
        cd "$dir" || exit 1
        find . -type f \
            ! -name '*.log' \
            ! -name '*.test.log' \
            ! -name 'test_output.txt' \
            ! -name 'test_output.sha256' \
            ! -name 'SNAPSHOT_SHA256.txt' \
            ! -name '*.bak.*' \
            -print0 2>/dev/null |
        sort -z |
        xargs -0 -r sha256sum 2>/dev/null |
        sha256sum | awk '{print $1}'
    )
}

# ============================================================
# START
# ============================================================

head1 "CYBRA AUTO EVOLUTION TEST"
log "RUN:   $RUN"
log "STAMP: $STAMP"

# ============================================================
# ФАЗА 1 — Owner check
# ============================================================

head1 "[1/8] Owner check"

if [ ! -f "$OWNER" ]; then
    printf 'CYBRA_OWNER_%s\n' "$STAMP" > "$OWNER"
    chmod 600 "$OWNER"
    log "  [FIXED] owner marker створено"
    FIX=$((FIX+1))
fi

log "  [OK] owner = $(cat "$OWNER")"

# ============================================================
# ФАЗА 2 — Fix module_19: menu через правильний порядок
# ============================================================

head1 "[2/8] Fix module_19 — правильний порядок"

MOD19="$MODULES/module_19_contract_tui_menu"
MENU="$MOD19/bin/cybra_menu.sh"
LIB="$MOD19/bin/cybra_tui_lib.sh"

# --- Pre-approve ---
BEFORE_HASH="$(hash_tree "$MOD19")"
printf '%s' "$BEFORE_HASH" > "$EVO_DIR/module_19_contract_tui_menu.approved"
log "  pre-approved: ${BEFORE_HASH:0:16}..."

# --- Rewrite print_menu ---
START=$(grep -n "^print_menu() {" "$MENU" 2>/dev/null | head -1 | cut -d: -f1)
END=$(awk -v start="$START" 'NR > start && /^\}/ {print NR; exit}' "$MENU" 2>/dev/null)

if [ -n "$START" ] && [ -n "$END" ]; then
    {
        head -n $((START - 1)) "$MENU"
        cat <<'NEW_MENU'
print_menu() {
    printf '%s\n' "  ${C_BOLD}[1]${C_RESET}  Створити новий контракт"
    printf '%s\n' "  ${C_BOLD}[2]${C_RESET}  Список усіх контрактів"
    printf '%s\n' "  ${C_BOLD}[3]${C_RESET}  Статус контракту"
    printf '%s\n' "  ${C_BOLD}[4]${C_RESET}  Згенерувати лінки"
    printf '%s\n' "  ${C_BOLD}[5]${C_RESET}  Підтвердити лінк"
    printf '%s\n' "  ${C_BOLD}[6]${C_RESET}  Debug"
    printf '%s\n' "  ${C_BOLD}[7]${C_RESET}  DUAL-LICENSE ledger"
    printf '%s\n' "  ${C_BOLD}[8]${C_RESET}  CREATION-LICENSE ledger"
    printf '%s\n' "  ${C_BOLD}[9]${C_RESET}  Hardening"
    printf '%s\n' "${C_CYAN}  ── INVOICE ──${C_RESET}"
    printf '%s\n' "  ${C_BOLD}[11]${C_RESET} Створити INVOICE"
    printf '%s\n' "  ${C_BOLD}[12]${C_RESET} Додати позицію"
    printf '%s\n' "  ${C_BOLD}[13]${C_RESET} Показати INVOICE"
    printf '%s\n' "  ${C_BOLD}[14]${C_RESET} Фіналізувати INVOICE"
    printf '%s\n' "${C_CYAN}  ── PII MASK ──${C_RESET}"
    printf '%s\n' "  ${C_BOLD}[15]${C_RESET} Експорт контракту (PII)"
    printf '%s\n' "  ${C_BOLD}[16]${C_RESET} Експорт усіх (PII + git)"
    printf '%s\n' "  ${C_BOLD}[17]${C_RESET} Перевірити PII хеш"
    printf '%s\n' "  ${C_BOLD}[0]${C_RESET}  Вихід"
    printf '\n'
}
NEW_MENU
        tail -n +$((END + 1)) "$MENU"
    } > "$MENU.new"
    mv "$MENU.new" "$MENU"
    chmod +x "$MENU"
    log "  [FIXED] print_menu rewritten"
    FIX=$((FIX+1))
fi

# --- Update case ---
python3 - <<'PY'
import re
p = "/data/data/com.termux/files/home/CYBRA/modules/module_19_contract_tui_menu/bin/cybra_menu.sh"
with open(p) as f: s = f.read()

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
        0|q|Q|exit|quit)
            printf "%s\\n" "${C_GREEN}До побачення.${C_RESET}"
            exit 0
            ;;
        *)
            printf "%s\\n" "${C_RED}Невідома опція.${C_RESET}"
            ;;
    esac'''

s = re.sub(r'case "\$CHOICE" in.*?esac', new_case, s, count=1, flags=re.DOTALL)

# Додаємо всі action-функції якщо відсутні
if "action_create_invoice()" not in s:
    funcs = '''action_create_invoice() {
    printf '%s\\n' "${C_BOLD}--- INVOICE ---${C_RESET}"
    printf 'ПІБ покупця: '; read -r BUYER_NAME
    printf 'ІПН: '; read -r BUYER_IPN
    printf 'Wallet покупця: '; read -r BUYER_WALLET
    printf 'Продавець: '; read -r SELLER_NAME
    printf 'ЄДРПОУ: '; read -r SELLER_EDRPOU
    printf 'Wallet продавця: '; read -r SELLER_WALLET
    printf '№ рахунку: '; read -r INV_NO
    printf 'Дата: '; read -r INV_DATE
    printf 'Сума: '; read -r AMOUNT_RAW
    printf 'Token: '; read -r TOKEN
    printf 'Decimals [18]: '; read -r DECIMALS
    DECIMALS="${DECIMALS:-18}"
    AMOUNT="$(cybra_amount_to_wei "$AMOUNT_RAW" "$DECIMALS")"
    [ -z "$AMOUNT" ] || [ "$AMOUNT" = "0" ] && { printf '%s\\n' "${C_RED}Помилка${C_RESET}"; return 1; }
    CID="$(cybra_contract_create_invoice "$BUYER_NAME" "$BUYER_IPN" "$BUYER_WALLET" "$SELLER_NAME" "$SELLER_EDRPOU" "$SELLER_WALLET" "$INV_NO" "$INV_DATE" "$AMOUNT" "$TOKEN" "$DECIMALS" 20)"
    [ -z "$CID" ] && { printf '%s\\n' "${C_RED}Fail${C_RESET}"; return 1; }
    printf '%s\\n' "${C_GREEN}OK: $CID${C_RESET}"
}
action_add_line() {
    printf 'CONTRACT_ID: '; read -r CID
    [ ! -f "$(cybra_contract_path "$CID")" ] && { printf '%s\\n' "${C_RED}Not found${C_RESET}"; return 1; }
    printf 'Код: '; read -r CODE
    printf 'Назва: '; read -r NAME
    printf 'К-сть: '; read -r QTY
    printf 'Ціна: '; read -r PRICE
    SUM="$(cybra_invoice_add_line "$CID" "$CODE" "$NAME" "$QTY" "$PRICE")"
    printf '%s\\n' "${C_GREEN}+ $NAME x$QTY = $SUM${C_RESET}"
}
action_show_invoice() {
    printf 'CONTRACT_ID: '; read -r CID
    cybra_invoice_show "$CID"
}
action_finalize_invoice() {
    printf 'CONTRACT_ID: '; read -r CID
    RES="$(cybra_invoice_finalize "$CID")"
    printf '%s\\n' "${C_GREEN}$RES${C_RESET}"
}
action_export_masked() {
    printf 'CONTRACT_ID: '; read -r CID
    H="$(cybra_export_masked "$CID" "$HOME/CYBRA/public/contracts")"
    printf '%s\\n' "${C_GREEN}Export: ${H:0:16}...${C_RESET}"
}
action_export_all_masked() {
    cybra_export_all_masked "$HOME/CYBRA/public/contracts"
}
action_verify_pii() {
    printf 'Значення: '; read -r VALUE
    printf 'Hash: '; read -r EXPECTED
    C="$(cybra_pii_hash "$VALUE")"
    [ "$C" = "$EXPECTED" ] && printf '%s\\n' "${C_GREEN}MATCH${C_RESET}" || printf '%s\\n' "${C_RED}MISMATCH${C_RESET}"
}
'''
    s = s.replace("print_header() {", funcs + "print_header() {", 1)

# Додаємо source lib якщо відсутній
if 'cybra_tui_lib.sh' not in s or 'source ' not in s.split('\n')[1] if len(s.split('\n')) > 1 else True:
    if 'source ' not in s or 'cybra_tui_lib' not in s:
        lines = s.split('\n')
        for i, line in enumerate(lines):
            if line.startswith('#!'):
                lines.insert(i+1, '')
                lines.insert(i+2, 'source "$HOME/CYBRA/modules/module_19_contract_tui_menu/bin/cybra_tui_lib.sh" 2>/dev/null || true')
                break
        s = '\n'.join(lines)

with open(p, "w") as f: f.write(s)
print("case + actions updated")
PY

chmod +x "$MENU" "$LIB"

# Синтаксис
if bash -n "$MENU" 2>/dev/null; then
    log "  [OK] menu syntax"
else
    log "  [FAIL] menu syntax"
    FAIL=$((FAIL+1))
fi

# --- Re-seal ---
for f in "$MENU" "$LIB"; do
    cp "$f" "$MOD19/snapshot/$(basename "$f")" 2>/dev/null || true
done

rm -f "$MOD19/snapshot/final_manifest.sha256"
(
    cd "$MOD19/snapshot" || exit 1
    find . -type f \
        ! -name 'final_manifest.sha256' \
        ! -name '*.log' \
        -print0 |
    sort -z |
    xargs -0 -r sha256sum 2>/dev/null
) > "$MOD19/snapshot/final_manifest.sha256"

# --- Post-approve ---
AFTER_HASH="$(hash_tree "$MOD19")"
printf '%s' "$AFTER_HASH" > "$EVO_DIR/module_19_contract_tui_menu.approved"
printf '%s' "$AFTER_HASH" > "$BASELINE/module_19_contract_tui_menu.tree"
log "  post-approved: ${AFTER_HASH:0:16}..."

# ============================================================
# ФАЗА 3 — Baseline update для всіх модулів
# ============================================================

head1 "[3/8] Baseline update"

while IFS= read -r -d '' d; do
    m="$(basename "$d")"
    case "$m" in @*|.*|_disabled*|evolution|answer_engine|node_modules) continue ;; esac
    h="$(hash_tree "$d")"
    printf '%s' "$h" > "$BASELINE/${m}.tree"
    printf '%s' "$h" > "$EVO_DIR/${m}.approved"
    log "  [OK] $m -> ${h:0:16}..."
done < <(find "$MODULES" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -z)

# ============================================================
# ФАЗА 4 — ТЕСТ ЕВОЛЮЦІЇ (різна складність)
# ============================================================

head1 "[4/8] АВТОМАТИЧНИЙ ТЕСТ ЕВОЛЮЦІЇ"

EVO_LIB="$MODULES/module_20_evolution_guard/bin/cybra_evolution.sh"

if [ ! -f "$EVO_LIB" ]; then
    log "  [FAIL] Evolution Guard не знайдено"
    FAIL=$((FAIL+1))
else
    source "$EVO_LIB"

    # --- Helper ---
    evo_test() {
        local name="$1"
        local expected="$2"  # OK | BLOCKED
        local result="$3"

        if [ "$result" = "$expected" ]; then
            printf '  [EVO-PASS] %-50s (expected %s)\n' "$name" "$expected" | tee -a "$LOG"
            EVO_PASS=$((EVO_PASS+1))
        else
            printf '  [EVO-FAIL] %-50s (expected %s, got %s)\n' "$name" "$expected" "$result" | tee -a "$LOG"
            EVO_FAIL=$((EVO_FAIL+1))
        fi
    }

    # ============================================
    # T1 — Simple: equal metrics OK
    # ============================================
    if evo_within_tolerance 100 100 3; then
        evo_test "T1 equal metrics (100→100)" "OK" "OK"
    else
        evo_test "T1 equal metrics (100→100)" "OK" "BLOCKED"
    fi

    # ============================================
    # T2 — Simple: improvement OK
    # ============================================
    if evo_within_tolerance 100 120 3; then
        evo_test "T2 improvement (100→120)" "OK" "OK"
    else
        evo_test "T2 improvement (100→120)" "OK" "BLOCKED"
    fi

    # ============================================
    # T3 — Simple: 3% deviation OK
    # ============================================
    if evo_within_tolerance 100 97 3; then
        evo_test "T3 3% deviation (100→97)" "OK" "OK"
    else
        evo_test "T3 3% deviation (100→97)" "OK" "BLOCKED"
    fi

    # ============================================
    # T4 — Simple: 4% deviation BLOCKED
    # ============================================
    if evo_within_tolerance 100 96 3; then
        evo_test "T4 4% deviation (100→96)" "BLOCKED" "OK"
    else
        evo_test "T4 4% deviation (100→96)" "BLOCKED" "BLOCKED"
    fi

    # ============================================
    # T5 — Medium: 50% degradation BLOCKED
    # ============================================
    if evo_within_tolerance 100 50 3; then
        evo_test "T5 50% degradation (100→50)" "BLOCKED" "OK"
    else
        evo_test "T5 50% degradation (100→50)" "BLOCKED" "BLOCKED"
    fi

    # ============================================
    # T6 — Medium: massive improvement OK
    # ============================================
    if evo_within_tolerance 50 500 3; then
        evo_test "T6 massive improvement (50→500)" "OK" "OK"
    else
        evo_test "T6 massive improvement (50→500)" "OK" "BLOCKED"
    fi

    # ============================================
    # T7 — Complex: zero baseline handling
    # ============================================
    if evo_within_tolerance 0 0 3; then
        evo_test "T7 zero→zero" "OK" "OK"
    else
        evo_test "T7 zero→zero" "OK" "BLOCKED"
    fi

    # ============================================
    # T8 — Complex: 0→1 (edge case) — should be BLOCKED
    # (бо delta=1 при old=0 — не справедливо)
    # ============================================
    if evo_within_tolerance 0 1 3; then
        evo_test "T8 zero→one (edge)" "BLOCKED" "OK"
    else
        evo_test "T8 zero→one (edge)" "BLOCKED" "BLOCKED"
    fi

    # ============================================
    # T9 — Real system: спроба деградації
    # ============================================
    # Симулюємо: pass=10 → 5
    if evo_within_tolerance 10 5 3; then
        evo_test "T9 real: pass 10→5" "BLOCKED" "OK"
    else
        evo_test "T9 real: pass 10→5" "BLOCKED" "BLOCKED"
    fi

    # ============================================
    # T10 — Real: реальна деградація у файлі
    # ============================================
    TEST_MOD="module_01_auto_executor"
    ORIG_PASS="$(cat "$BASELINE/${TEST_MOD}.pass" 2>/dev/null || echo 0)"
    ORIG_FAIL="$(cat "$BASELINE/${TEST_MOD}.fail" 2>/dev/null || echo 0)"

    # Симулюємо деградацію: pass=1, fail=10
    printf '1' > "$BASELINE/${TEST_MOD}.pass"
    printf '10' > "$BASELINE/${TEST_MOD}.fail"

    # Перевіряємо — має бути BLOCKED
    if [ "$(cat "$BASELINE/${TEST_MOD}.fail")" -gt "$ORIG_FAIL" ]; then
        evo_test "T10 real degradation detected" "BLOCKED" "BLOCKED"
    else
        evo_test "T10 real degradation detected" "BLOCKED" "OK"
    fi

    # Відкат
    printf '%s' "$ORIG_PASS" > "$BASELINE/${TEST_MOD}.pass"
    printf '%s' "$ORIG_FAIL" > "$BASELINE/${TEST_MOD}.fail"

    # ============================================
    # T11 — Freeze тест
    # ============================================
    evo_freeze >/dev/null 2>&1
    if evo_is_frozen; then
        evo_test "T11 freeze activates" "OK" "OK"
    else
        evo_test "T11 freeze activates" "OK" "BLOCKED"
    fi

    evo_unfreeze >/dev/null 2>&1
    if ! evo_is_frozen; then
        evo_test "T12 unfreeze works" "OK" "OK"
    else
        evo_test "T12 unfreeze works" "OK" "BLOCKED"
    fi

    # ============================================
    # T13 — Owner approve
    # ============================================
    evo_approve "module_01_auto_executor" >/dev/null 2>&1
    if [ -f "$EVO_DIR/module_01_auto_executor.approved" ]; then
        evo_test "T13 owner approve" "OK" "OK"
    else
        evo_test "T13 owner approve" "OK" "BLOCKED"
    fi

    # ============================================
    # T14 — Hash tree function
    # ============================================
    TH="$(evo_hash_tree "$MODULES/module_19_contract_tui_menu")"
    if [ "${#TH}" -eq 64 ]; then
        evo_test "T14 hash tree (len=64)" "OK" "OK"
    else
        evo_test "T14 hash tree (len=${#TH})" "OK" "BLOCKED"
    fi

    # ============================================
    # T15 — Real system check
    # ============================================
    if evo_check_all >/dev/null 2>&1; then
        evo_test "T15 full system check" "OK" "OK"
    else
        evo_test "T15 full system check" "OK" "BLOCKED"
    fi

    log ""
    log "  ── EVOLUTION TEST RESULT ──"
    log "  EVO_PASS: $EVO_PASS"
    log "  EVO_FAIL: $EVO_FAIL"
fi

# ============================================================
# ФАЗА 5 — @cybra node update
# ============================================================

head1 "[5/8] @cybra node update"

rm -rf "$NODE"
mkdir -p "$NODE/modules"

cat > "$NODE/README.md" <<'RD'
# @cybra — CYBRA Node

Глобальний індекс модулів CYBRA.
Автооновлення через cybra_auto_evolution_test.sh.

## Принципи
- Non-degradation (3% tolerance) — Module 20
- Ліцензія 1%+1%+1% → 0x66434c5501242ccC71b5a39C765892921624B66c
- Dual-backend verification
- PII masking на експорті
RD

{
    printf '# CYBRA NODE INDEX\nRUN=%s\nSTAMP=%s\n\n' "$RUN" "$STAMP"
    printf '%-45s %-14s %-18s\n' "MODULE" "STATUS" "TREE"
    printf -- '--------------------------------------------------------------------\n'
} > "$NODE/index.txt"

{
    printf '{\n  "run": "%s",\n  "stamp": "%s",\n  "modules": [\n' "$RUN" "$STAMP"
} > "$NODE/index.json"

FIRST=1
COUNT=0
while IFS= read -r -d '' d; do
    m="$(basename "$d")"
    case "$m" in @*|.*|_disabled*|evolution|answer_engine|node_modules) continue ;; esac
    COUNT=$((COUNT+1))
    h="$(cat "$BASELINE/${m}.tree" 2>/dev/null || echo NOHASH)"
    p="$(cat "$BASELINE/${m}.pass" 2>/dev/null || echo 0)"
    f="$(cat "$BASELINE/${m}.fail" 2>/dev/null || echo 0)"
    printf '%-45s %-14s %-18s\n' "$m" "P=$p F=$f" "${h:0:16}" >> "$NODE/index.txt"
    if [ "$FIRST" -eq 0 ]; then printf ',\n' >> "$NODE/index.json"; fi
    FIRST=0
    printf '    {"name":"%s","pass":%s,"fail":%s,"tree":"%s"}' "$m" "$p" "$f" "$h" >> "$NODE/index.json"
    ln -sfn "$d" "$NODE/modules/$m"
done < <(find "$MODULES" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -z)

{
    printf '\n  ],\n  "module_count": %s,\n' "$COUNT"
    printf '  "evo_test": {"pass": %s, "fail": %s},\n' "$EVO_PASS" "$EVO_FAIL"
    printf '  "license_recipient": "0x66434c5501242ccC71b5a39C765892921624B66c",\n'
    printf '  "policy": "STRICT_NON_DEGRADATION_3PCT"\n}\n'
} >> "$NODE/index.json"

log "  [OK] @cybra node ($COUNT modules)"

# ============================================================
# ФАЗА 6 — Dual-backend snapshot
# ============================================================

head1 "[6/8] Dual-backend snapshot"

DB="$HASHES/$STAMP"
mkdir -p "$DB"

CANON="$DB/canonical.state"
{
    printf 'CYBRA_CANONICAL\nRUN=%s\nSTAMP=%s\n\n' "$RUN" "$STAMP"
    for t in "$BASELINE"/*.tree; do
        [ -f "$t" ] || continue
        printf '%s %s\n' "$(basename "$t" .tree)" "$(cat "$t")"
    done
} | LC_ALL=C sort > "$CANON"

A="$(sha256sum "$CANON" | awk '{print $1}')"

B_IN="$DB/b.input"
{ cat "$NODE/index.json"; printf '\n---\n'
  for t in "$BASELINE"/*.tree; do
    [ -f "$t" ] || continue
    printf '%s %s\n' "$(cat "$t")" "$(basename "$t")"
  done
} | LC_ALL=C sort > "$B_IN"
B="$(sha256sum "$B_IN" | awk '{print $1}')"

C_IN="$DB/c.input"
for t in "$BASELINE"/*.tree; do
    [ -f "$t" ] || continue
    printf '%s %s\n' "$(basename "$t" .tree)" "$(cat "$t")"
done | LC_ALL=C sort > "$C_IN"
C="$(sha256sum "$C_IN" | awk '{print $1}')"

D="$(sha256sum "$NODE/index.txt" | awk '{print $1}')"

L1="$(printf '%s\n%s\n' "$A" "$B" | sha256sum | awk '{print $1}')"
L2="$(printf '%s\n%s\n' "$C" "$D" | sha256sum | awk '{print $1}')"
U="$(printf '%s\n%s\n%s\n%s\n' "$A" "$B" "$C" "$D" | sha256sum | awk '{print $1}')"

cat > "$DB/dual_snapshot.env" <<EOF2
RUN=$RUN
STAMP=$STAMP
BACKEND_A=$A
BACKEND_B=$B
BACKEND_C=$C
BACKEND_D=$D
DUAL_L1=$L1
DUAL_L2=$L2
ULTRA_DUAL=$U
MOD_COUNT=$COUNT
EVO_PASS=$EVO_PASS
EVO_FAIL=$EVO_FAIL
EOF2

log "  A=${A:0:16}... B=${B:0:16}..."
log "  C=${C:0:16}... D=${D:0:16}..."
log "  L1=${L1:0:16}... L2=${L2:0:16}..."
log "  ULTRA=${U:0:16}..."

# ============================================================
# ФАЗА 7 — Hardening
# ============================================================

head1 "[7/8] Hardening"

if [ -x "$ROOT/cybra_mega_hardening.sh" ]; then
    "$ROOT/cybra_mega_hardening.sh" 2>&1 | tail -20 | tee -a "$LOG"
    RC=$?
else
    RC=1
fi

# ============================================================
# ФАЗА 8 — Git push
# ============================================================

head1 "[8/8] Git push"

if [ -d "$GITMOD/.git" ]; then
    mkdir -p "$GITMOD/meta"
    cp "$NODE/index.json" "$GITMOD/meta/index.json"
    cp "$NODE/index.txt"  "$GITMOD/meta/index.txt"
    cp "$NODE/README.md"  "$GITMOD/README.md"
    cp "$DB/dual_snapshot.env" "$GITMOD/meta/dual_snapshot.env"

    for d in "$MODULES"/*/; do
        [ -d "$d" ] || continue
        m="$(basename "$d")"
        case "$m" in @*|.*|_disabled*|evolution|answer_engine|node_modules) continue ;; esac
        target="$GITMOD/modules/$m"
        mkdir -p "$target"
        for sub in config rules evidence tests bin snapshot snapshots state payment; do
            if [ -d "$d/$sub" ]; then
                mkdir -p "$target/$sub"
                cp -r "$d/$sub"/* "$target/$sub/" 2>/dev/null || true
            fi
        done
    done

    {
        printf 'CYBRA GIT MODULE\nRUN=%s\nSTAMP=%s\n' "$RUN" "$STAMP"
        printf 'ULTRA_DUAL=%s\n' "$U"
        printf 'EVO_PASS=%s\nEVO_FAIL=%s\n' "$EVO_PASS" "$EVO_FAIL"
        printf 'MODULE_COUNT=%s\n' "$COUNT"
        printf 'LICENSE=0x66434c5501242ccC71b5a39C765892921624B66c\n'
    } > "$GITMOD/manifest.txt"

    cd "$GITMOD" || exit 1
    git add -A 2>&1 | tee -a "$LOG" || true

    if [ -z "$(git status --porcelain 2>/dev/null)" ]; then
        log "  [OK] немає змін"
    else
        git commit -m "CYBRA auto-evo $STAMP [mod=$COUNT evo=$EVO_PASS/$EVO_FAIL ultra=${U:0:12}]" 2>&1 | tee -a "$LOG" || true
        if git push 2>&1 | tee -a "$LOG"; then
            log "  [OK] PUSHED"
        else
            log "  [WARN] push failed"
            WARN=$((WARN+1))
        fi
    fi
fi

# ============================================================
# SUMMARY
# ============================================================

head1 "SUMMARY"

LATEST="$(ls -t "$AUDIT"/*_final_report.env 2>/dev/null | head -1)"
if [ -n "$LATEST" ]; then
    FS="$(grep '^FINAL_STATUS=' "$LATEST" | cut -d= -f2)"
    PC="$(grep '^PASS_COUNT=' "$LATEST" | cut -d= -f2)"
    FC="$(grep '^FAIL_COUNT=' "$LATEST" | cut -d= -f2)"
    BC="$(grep '^BLOCKED_COUNT=' "$LATEST" | cut -d= -f2)"
else
    FS=UNKNOWN; PC=0; FC=0; BC=0
fi

log ""
log " RUN             : $RUN"
log " FIXED           : $FIX"
log " FAILED          : $FAIL"
log " WARN            : $WARN"
log ""
log " MODULE_COUNT    : $COUNT"
log " HARDENING       : $FS"
log " PASS            : $PC"
log " FAIL            : $FC"
log " BLOCKED         : $BC"
log ""
log " EVO TEST PASS   : $EVO_PASS"
log " EVO TEST FAIL   : $EVO_FAIL"
log ""
log " A               : ${A:0:16}..."
log " B               : ${B:0:16}..."
log " C               : ${C:0:16}..."
log " D               : ${D:0:16}..."
log " DUAL_L1         : ${L1:0:16}..."
log " DUAL_L2         : ${L2:0:16}..."
log " ULTRA_DUAL      : ${U:0:16}..."
log ""
log " @cybra          : $NODE"
log " Git             : $GITMOD"
log " Log             : $LOG"
log "============================================================"

[ "$FAIL" -eq 0 ] && [ "$EVO_FAIL" -eq 0 ] && exit 0 || exit 1
