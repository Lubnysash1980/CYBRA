#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# CYBRA CREATION LICENSE
# Ліцензія за створення контракту:
#   - фіксована плата за факт створення
#   - відсоток від суми контракту
#   - все пишеться в git (для публічності)
# ============================================================

set -u
export LC_ALL=C

ROOT="$HOME/CYBRA"
MOD="$ROOT/modules/module_19_contract_tui_menu"
LOGS="$ROOT/logs"
GITMOD="$ROOT/git_module"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
LOG="$LOGS/creation_license_${STAMP}.log"

mkdir -p "$LOGS"

FIX=0
FAIL=0

log()   { printf '%s\n' "$*" | tee -a "$LOG"; }
head1() {
    printf -- '\n============================================================\n' | tee -a "$LOG"
    printf -- ' %s\n' "$*" | tee -a "$LOG"
    printf -- '============================================================\n' | tee -a "$LOG"
}

head1 "CYBRA CREATION LICENSE UPGRADE"
log "STAMP: $STAMP"

if [ ! -d "$MOD" ]; then
    log "  [FAIL] module_19 не знайдено"
    exit 1
fi

# ============================================================
# 1. Config — параметри creation license
# ============================================================

head1 "[1] Config creation license"

CFG="$MOD/state/config.env"

if grep -q '^CREATION_FEE_ENABLED=' "$CFG"; then
    log "  [OK] creation license вже налаштована"
else
    cat >> "$CFG" <<'CFG_ADD'

# ============================================================
# CREATION LICENSE v1
# Плата за сам факт створення контракту
# ============================================================

CREATION_FEE_ENABLED=TRUE
CREATION_FEE_RECIPIENT=0x66434c5501242ccC71b5a39C765892921624B66c

# Фіксована плата за створення (у wei)
CREATION_FEE_FIXED_WEI=0

# Відсоток від суми контракту як плата за створення
CREATION_FEE_PERCENT=1

# Мінімальна плата за створення (у wei)
CREATION_FEE_MIN_WEI=0

# Максимальна плата за створення (0 = без ліміту)
CREATION_FEE_MAX_WEI=0

# Ліцензія на створення фіксується в git
CREATION_LICENSE_LOGGED_TO_GIT=TRUE
CFG_ADD
    log "  [FIXED] creation license config"
    FIX=$((FIX+1))
fi

# ============================================================
# 2. Lib — функції creation license
# ============================================================

head1 "[2] Cybra TUI lib — creation license"

LIB="$MOD/bin/cybra_tui_lib.sh"
cp "$LIB" "$LIB.bak.$STAMP"

# --- 2.1: константи creation fee ---
python3 - <<PY
p = "$LIB"
with open(p) as f: s = f.read()

if "CREATION_FEE_ENABLED" in s:
    print("    [OK] constants already present")
else:
    marker = "# DUAL-LICENSE v2"
    insert = '''# CREATION LICENSE v1
CREATION_FEE_ENABLED=TRUE
CREATION_FEE_RECIPIENT="0x66434c5501242ccC71b5a39C765892921624B66c"
CREATION_FEE_PERCENT=1
CREATION_FEE_FIXED_WEI=0
CREATION_FEE_MIN_WEI=0
CREATION_FEE_MAX_WEI=0

CREATION_LICENSE_LEDGER="\$CYBRA_MOD19_ROOT/evidence/creation_license_ledger.txt"
CREATION_LICENSE_LOG="\$CYBRA_MOD19_ROOT/evidence/creation_license.log"

# DUAL-LICENSE v2'''

    if marker in s:
        s = s.replace(marker, insert, 1)
        with open(p, "w") as f: f.write(s)
        print("    [FIXED] constants added")
    else:
        print("    [WARN] marker not found — skipping")
PY

# --- 2.2: функція розрахунку creation fee ---
python3 - <<PY
p = "$LIB"
with open(p) as f: s = f.read()

if "cybra_calc_creation_fee" in s:
    print("    [OK] calc function exists")
else:
    func = '''
# ------------------------------------------------------------
# CREATION FEE
# ------------------------------------------------------------

cybra_calc_creation_fee() {
    local amount="\$1"

    if ! [[ "\$amount" =~ ^[0-9]+\$ ]]; then
        echo "0"
        return 1
    fi

    local fixed="\${CREATION_FEE_FIXED_WEI:-0}"
    local percent="\${CREATION_FEE_PERCENT:-1}"
    local minf="\${CREATION_FEE_MIN_WEI:-0}"
    local maxf="\${CREATION_FEE_MAX_WEI:-0}"

    local var_fee=\$(( amount * percent / 100 ))
    local total=\$(( fixed + var_fee ))

    if [ "\$minf" -gt 0 ] && [ "\$total" -lt "\$minf" ]; then
        total="\$minf"
    fi
    if [ "\$maxf" -gt 0 ] && [ "\$total" -gt "\$maxf" ]; then
        total="\$maxf"
    fi

    echo "\$total"
}

cybra_creation_license_record() {
    local contract_id="\$1"
    local amount="\$2"
    local creation_fee="\$3"
    local buyer="\$4"

    printf '%s | %s | %s | %s | %s | %s\\n' \\
        "\$(cybra_now)" \\
        "\$contract_id" \\
        "\$buyer" \\
        "\$amount" \\
        "\$creation_fee" \\
        "\$CREATION_FEE_RECIPIENT" \\
        >> "\$CREATION_LICENSE_LEDGER"

    printf '%s | contract=%s buyer=%s amount=%s fee=%s recipient=%s\\n' \\
        "\$(cybra_now)" \\
        "\$contract_id" \\
        "\$buyer" \\
        "\$amount" \\
        "\$creation_fee" \\
        "\$CREATION_FEE_RECIPIENT" \\
        >> "\$CREATION_LICENSE_LOG"

    cybra_log "CREATION_LICENSE contract=\$contract_id fee=\$creation_fee"

    # --- Git export ---
    if [ "\${CREATION_LICENSE_LOGGED_TO_GIT:-FALSE}" = "TRUE" ]; then
        local gdir="\$HOME/CYBRA/git_module/meta/creation_licenses"
        mkdir -p "\$gdir"
        cp "\$CREATION_LICENSE_LEDGER" "\$gdir/ledger.txt"
        printf '%s\\n' "\$(sha256sum "\$CREATION_LICENSE_LEDGER" | awk '{print \$1}')" \\
            > "\$gdir/ledger.sha256"
    fi
}
'''

    marker = "cybra_license_record() {"
    if marker in s:
        s = s.replace(marker, func + "\n" + marker, 1)
        with open(p, "w") as f: f.write(s)
        print("    [FIXED] creation fee functions")
    else:
        s += "\n" + func
        with open(p, "w") as f: f.write(s)
        print("    [WARN] appended at end")
PY

# --- 2.3: cybra_contract_create — виклик creation fee ---
python3 - <<PY
p = "$LIB"
with open(p) as f: s = f.read()

if "cybra_calc_creation_fee" in s and "CREATION_FEE_WEI" in s:
    print("    [OK] create already charges creation fee")
else:
    # Замінюємо блок у create — додаємо creation fee
    old = '''    local contract_id="C-\$(date -u +%Y%m%d%H%M%S)-\$(cybra_rand_id)"
    local license_a="\$(cybra_calc_license "\$amount")"
    local license_b="\$(cybra_calc_license "\$amount")"
    local license_total=\$(( license_a + license_b ))
    local net=\$(( amount - license_total ))
    local now="\$(cybra_now)"'''

    new = '''    local contract_id="C-\$(date -u +%Y%m%d%H%M%S)-\$(cybra_rand_id)"
    local license_a="\$(cybra_calc_license "\$amount")"
    local license_b="\$(cybra_calc_license "\$amount")"
    local creation_fee="\$(cybra_calc_creation_fee "\$amount")"
    local license_total=\$(( license_a + license_b + creation_fee ))
    local net=\$(( amount - license_total ))
    local now="\$(cybra_now)"'''

    if old in s:
        s = s.replace(old, new)
        print("    [FIXED] create calc creation fee")
    else:
        print("    [WARN] create block not matched — trying alternative")

    # Додаємо CREATION_FEE_WEI в contract template
    old_tpl = '''LICENSE_TOTAL_WEI=\$license_total
NET_WEI=\$net
DUAL_LICENSE_FROZEN=TRUE'''

    new_tpl = '''# === CREATION LICENSE ===
CREATION_FEE_WEI=\$creation_fee
CREATION_FEE_PERCENT=\${CREATION_FEE_PERCENT:-1}
CREATION_FEE_FIXED_WEI=\${CREATION_FEE_FIXED_WEI:-0}
CREATION_FEE_RECIPIENT=\$CREATION_FEE_RECIPIENT
CREATION_FEE_BUYER=\$buyer
CREATION_FEE_FROZEN=TRUE

LICENSE_TOTAL_WEI=\$license_total
NET_WEI=\$net
DUAL_LICENSE_FROZEN=TRUE'''

    if old_tpl in s:
        s = s.replace(old_tpl, new_tpl)
        print("    [FIXED] contract template creation fee")

    # Виклик record
    old_call = '''    # Подвійна ліцензія — в два ledger-и
    cybra_license_record "\$contract_id" "\$amount" "\$license_a" "\$license_b"

    cybra_log "CONTRACT_CREATED id=\$contract_id buyer=\$buyer seller=\$seller amount=\$amount license_A=\$license_a license_B=\$license_b"'''

    new_call = '''    # Подвійна ліцензія — в два ledger-и
    cybra_license_record "\$contract_id" "\$amount" "\$license_a" "\$license_b"

    # Creation license
    cybra_creation_license_record "\$contract_id" "\$amount" "\$creation_fee" "\$buyer"

    cybra_log "CONTRACT_CREATED id=\$contract_id buyer=\$buyer seller=\$seller amount=\$amount license_A=\$license_a license_B=\$license_b creation_fee=\$creation_fee"'''

    if old_call in s:
        s = s.replace(old_call, new_call)
        print("    [FIXED] create record call")

    with open(p, "w") as f: f.write(s)
PY

chmod +x "$LIB"

# ============================================================
# 3. TUI menu — пункт [10] Creation License
# ============================================================

head1 "[3] TUI menu — Creation License"

MENU="$MOD/bin/cybra_menu.sh"

if grep -q "action_creation_license" "$MENU"; then
    log "  [OK] creation menu вже є"
else
    python3 - <<PY
p = "$MENU"
with open(p) as f: s = f.read()

new_func = '''action_creation_license() {
    printf '%s\\n' "\${C_BOLD}--- CREATION LICENSE LEDGER ---\${C_RESET}"
    printf '%s\\n' "\${C_GREY}Плата за створення контракту:\${C_RESET}"
    printf '%s\\n' "\${C_GREY}  Фіксована: \${CREATION_FEE_FIXED_WEI:-0} wei\${C_RESET}"
    printf '%s\\n' "\${C_GREY}  Відсоток: \${CREATION_FEE_PERCENT:-1}%%\${C_RESET}"
    printf '%s\\n' "\${C_GREY}  Отримувач: \${CREATION_FEE_RECIPIENT:0:10}...\${C_RESET}"
    printf '\\n'

    if [ -f "\$CREATION_LICENSE_LEDGER" ]; then
        cat "\$CREATION_LICENSE_LEDGER"
        printf '\\n%s\\n' "\${C_BOLD}Всього контрактів:\${C_RESET} \$(wc -l < "\$CREATION_LICENSE_LEDGER")"
    else
        printf '%s\\n' "\${C_YELLOW}(порожньо)\${C_RESET}"
    fi
}

'''

if "action_creation_license()" not in s:
    s = s.replace("action_dual_license_ledger() {",
                  new_func + "action_dual_license_ledger() {")

old_menu = '''    printf '%s\\n' "  \${C_BOLD}[9]\${C_RESET} DUAL-LICENSE ledger (A + B)"
    printf '%s\\n' "  \${C_BOLD}[0]\${C_RESET} Вихід"'''

new_menu = '''    printf '%s\\n' "  \${C_BOLD}[9]\${C_RESET} DUAL-LICENSE ledger (A + B)"
    printf '%s\\n' "  \${C_BOLD}[10]\${C_RESET} CREATION-LICENSE ledger"
    printf '%s\\n' "  \${C_BOLD}[0]\${C_RESET} Вихід"'''

if "[10]" not in s:
    s = s.replace(old_menu, new_menu)

old_case = '''        9) action_dual_license_ledger ;;'''
new_case = '''        9) action_dual_license_ledger ;;
        10) action_creation_license ;;'''

if "10) action_creation_license" not in s:
    s = s.replace(old_case, new_case)

with open(p, "w") as f: f.write(s)
print("    [FIXED] TUI creation menu")
PY
    chmod +x "$MENU"
    FIX=$((FIX+1))
fi

# ============================================================
# 4. Тести — додаємо creation license тести
# ============================================================

head1 "[4] Тести — creation license"

TESTS="$MOD/tests/run_tests.sh"
cp "$TESTS" "$TESTS.bak.$STAMP"

if grep -q "CREATION_FEE_WEI" "$TESTS"; then
    log "  [OK] creation тести вже є"
else
    python3 - <<PY
p = "$TESTS"
with open(p) as f: s = f.read()

extra = '''# 28 — creation fee enabled
[ "\$CREATION_FEE_ENABLED" = "TRUE" ] \\
    && ok "Creation fee enabled" || fail "Creation fee"

# 29 — creation recipient
[ "\$CREATION_FEE_RECIPIENT" = "0x66434c5501242ccC71b5a39C765892921624B66c" ] \\
    && ok "Creation recipient" || fail "Creation recipient"

# 30 — creation fee calc (1% від 10000 = 100)
[ "\$(cybra_calc_creation_fee 10000)" = "100" ] \\
    && ok "Creation fee calc 10000 → 100" || fail "Creation fee calc"

# 31 — creation ledger exists
[ -f "\$CREATION_LICENSE_LEDGER" ] \\
    && ok "Creation ledger exists" || fail "Creation ledger"

# 32 — contract has CREATION_FEE_WEI
grep -q '^CREATION_FEE_WEI=' "\$CF" \\
    && ok "Contract CREATION_FEE_WEI" || fail "CREATION_FEE_WEI"

# 33 — contract has CREATION_FEE_RECIPIENT
grep -q '^CREATION_FEE_RECIPIENT=' "\$CF" \\
    && ok "Contract CREATION_FEE_RECIPIENT" || fail "CREATION_FEE_RECIPIENT"

# 34 — contract has CREATION_FEE_FROZEN
grep -q '^CREATION_FEE_FROZEN=TRUE' "\$CF" \\
    && ok "Contract CREATION_FEE_FROZEN" || fail "CREATION_FEE_FROZEN"

# 35 — git export creation ledger
[ -d "\$HOME/CYBRA/git_module/meta/creation_licenses" ] \\
    && ok "Git export creation licenses" || warn "Git export not done yet"

'''

marker = "# 15 — rules hash"
if marker in s:
    s = s.replace(marker, extra + marker)
    with open(p, "w") as f: f.write(s)
    print("    [FIXED] creation tests added")
PY
    chmod +x "$TESTS"
    FIX=$((FIX+1))
fi

# ============================================================
# 5. Прогін тестів
# ============================================================

head1 "[5] Прогін тестів"

if "$TESTS" > "$LOGS/m19_creation_test.log" 2>&1; then
    log "  [OK] self-test PASS"
    tail -8 "$LOGS/m19_creation_test.log" | sed 's/^/    /'
else
    log "  [FAIL] self-test FAIL"
    tail -20 "$LOGS/m19_creation_test.log" | sed 's/^/    /' | tee -a "$LOG"
    FAIL=$((FAIL+1))
fi

# ============================================================
# 6. Re-seal snapshot
# ============================================================

head1 "[6] Re-seal snapshot"

cp "$MENU"  "$MOD/snapshot/cybra_menu.sh"  2>/dev/null || true
cp "$LIB"   "$MOD/snapshot/cybra_tui_lib.sh" 2>/dev/null || true
cp "$TESTS" "$MOD/snapshot/run_tests.sh" 2>/dev/null || true
cp "$CFG"   "$MOD/snapshot/config.env" 2>/dev/null || true

rm -f "$MOD/snapshot/final_manifest.sha256"

(
    cd "$MOD/snapshot" || exit 1
    find . -type f \
        ! -name 'final_manifest.sha256' \
        ! -name '*.log' \
        -print0 |
    sort -z |
    xargs -0 -r sha256sum 2>/dev/null
) > "$MOD/snapshot/final_manifest.sha256"

if (cd "$MOD/snapshot" && sha256sum -c final_manifest.sha256 >/dev/null 2>&1); then
    log "  [OK] snapshot re-sealed"
else
    log "  [FAIL] snapshot verify"
    FAIL=$((FAIL+1))
fi

# ============================================================
# 7. Baseline
# ============================================================

head1 "[7] Baseline update"

(
    cd "$MOD" || exit 1
    find . -type f \
        ! -name '*.log' \
        ! -name '*.test.log' \
        ! -name 'test_output.txt' \
        ! -name 'test_output.sha256' \
        ! -name 'SNAPSHOT_SHA256.txt' \
        -print0 2>/dev/null |
    sort -z |
    xargs -0 -r sha256sum 2>/dev/null |
    sha256sum | awk '{print $1}'
) > "$ROOT/baseline/module_19_contract_tui_menu.tree"

log "  [OK] baseline updated"

# ============================================================
# 8. Hardening
# ============================================================

head1 "[8] Hardening"

if [ -x "$ROOT/cybra_mega_hardening.sh" ]; then
    "$ROOT/cybra_mega_hardening.sh"
    RC=$?
else
    RC=1
fi

# ============================================================
# 9. Git push
# ============================================================

head1 "[9] Git push"

if [ -d "$GITMOD/.git" ]; then
    # Експорт creation ledger в git
    mkdir -p "$GITMOD/meta/creation_licenses"
    cp "$MOD/evidence/creation_license_ledger.txt" \
       "$GITMOD/meta/creation_licenses/ledger.txt" 2>/dev/null || true

    if [ -f "$GITMOD/meta/creation_licenses/ledger.txt" ]; then
        sha256sum "$GITMOD/meta/creation_licenses/ledger.txt" \
            | awk '{print $1}' \
            > "$GITMOD/meta/creation_licenses/ledger.sha256"
    fi

    cd "$GITMOD" || exit 1
    git add -A 2>/dev/null || true

    if git commit -m "CYBRA creation-license $STAMP" 2>&1 | tee -a "$LOG"; then
        if git push 2>&1 | tee -a "$LOG"; then
            log "  [OK] pushed"
        else
            log "  [WARN] push failed"
        fi
    fi
fi

# ============================================================
# SUMMARY
# ============================================================

head1 "CREATION LICENSE SUMMARY"

log " STAMP          : $STAMP"
log " FIXED          : $FIX"
log " FAILED         : $FAIL"
log ""
log " CREATION_FEE   :"
log "   Fixed        : $(grep '^CREATION_FEE_FIXED_WEI=' "$CFG" | cut -d= -f2)"
log "   Percent      : $(grep '^CREATION_FEE_PERCENT=' "$CFG" | cut -d= -f2)%"
log "   Recipient    : $(grep '^CREATION_FEE_RECIPIENT=' "$CFG" | cut -d= -f2)"
log ""
log " Ledger         : $MOD/evidence/creation_license_ledger.txt"
log " Log            : $MOD/evidence/creation_license.log"
log " Git export     : $GITMOD/meta/creation_licenses/"
log ""
log " Hardening      : $RC"
log " Log            : $LOG"
log "============================================================"

exit $RC
