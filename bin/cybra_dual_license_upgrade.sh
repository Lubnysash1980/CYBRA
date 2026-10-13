#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# CYBRA DUAL-LICENSE UPGRADE
# Додає подвійну ліцензію до Module 19
# Автоперевірка + автотест + автопуш
# ============================================================

set -u
export LC_ALL=C

ROOT="$HOME/CYBRA"
MOD="$ROOT/modules/module_19_contract_tui_menu"
LOGS="$ROOT/logs"
HASHES="$ROOT/hashes"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
LOG="$LOGS/dual_license_${STAMP}.log"

mkdir -p "$LOGS" "$HASHES"

FIX=0
FAIL=0

log()   { printf '%s\n' "$*" | tee -a "$LOG"; }
head1() {
    printf -- '\n============================================================\n' | tee -a "$LOG"
    printf -- ' %s\n' "$*" | tee -a "$LOG"
    printf -- '============================================================\n' | tee -a "$LOG"
}

head1 "CYBRA DUAL-LICENSE UPGRADE"
log "STAMP: $STAMP"
log "MOD:   $MOD"

if [ ! -d "$MOD" ]; then
    log "  [FAIL] module_19 не знайдено"
    exit 1
fi

# ============================================================
# 1. Оновлюємо config.env — додаємо другий ліцензійний отримувач
# ============================================================

head1 "[1] Оновлення config.env"

CFG="$MOD/state/config.env"

if grep -q '^LICENSE_B_RECIPIENT=' "$CFG"; then
    log "  [OK] dual-license вже в config"
else
    {
        printf '\n'
        printf '# ============================================================\n'
        printf '# DUAL-LICENSE v2\n'
        printf '# ============================================================\n'
        printf 'LICENSE_A_PERCENT=1\n'
        printf 'LICENSE_A_BPS=100\n'
        printf 'LICENSE_A_RECIPIENT=0x66434c5501242ccC71b5a39C765892921624B66c\n'
        printf '\n'
        printf 'LICENSE_B_PERCENT=1\n'
        printf 'LICENSE_B_BPS=100\n'
        printf 'LICENSE_B_RECIPIENT=0x66434c5501242ccC71b5a39C765892921624B66c\n'
        printf '\n'
        printf 'DUAL_LICENSE_ENABLED=TRUE\n'
        printf 'DUAL_LICENSE_FROZEN=TRUE\n'
    } >> "$CFG"
    log "  [FIXED] dual-license config додано"
    FIX=$((FIX+1))
fi

# ============================================================
# 2. Оновлюємо cybra_tui_lib.sh — dual-license функції
# ============================================================

head1 "[2] Оновлення cybra_tui_lib.sh"

LIB="$MOD/bin/cybra_tui_lib.sh"

# Backup
cp "$LIB" "$LIB.bak.$STAMP"

# Замінюємо стару логіку ліцензії на dual-license

# ---- 2.1: константи ----
python3 - <<PY
p = "$LIB"
with open(p) as f: s = f.read()

old_block = '''LICENSE_RECIPIENT="0x66434c5501242ccC71b5a39C765892921624B66c"
LICENSE_PERCENT=1'''

new_block = '''# DUAL-LICENSE v2
LICENSE_A_RECIPIENT="0x66434c5501242ccC71b5a39C765892921624B66c"
LICENSE_A_PERCENT=1

LICENSE_B_RECIPIENT="0x66434c5501242ccC71b5a39C765892921624B66c"
LICENSE_B_PERCENT=1

DUAL_LICENSE_ENABLED=TRUE

# Legacy alias (для сумісності)
LICENSE_RECIPIENT="$LICENSE_A_RECIPIENT"
LICENSE_PERCENT="$LICENSE_A_PERCENT"'''

if "DUAL_LICENSE_ENABLED" in s:
    print("    [OK] constants already dual")
elif old_block in s:
    s = s.replace(old_block, new_block)
    with open(p, "w") as f: f.write(s)
    print("    [FIXED] constants updated")
else:
    print("    [WARN] old constants not found — appending manually")
    s = s + "\n\n" + new_block + "\n"
    with open(p, "w") as f: f.write(s)
PY

# ---- 2.2: cybra_calc_license — лишаємо як є (1%) ----

# ---- 2.3: cybra_license_record — дублюємо для A і B ----
python3 - <<PY
p = "$LIB"
with open(p) as f: s = f.read()

old = '''cybra_license_record() {
    local contract_id="\$1"
    local amount="\$2"
    local license="\$3"

    printf '%s | %s | %s | %s | %s\\n' \\
        "\$(cybra_now)" \\
        "\$contract_id" \\
        "\$amount" \\
        "\$license" \\
        "\$LICENSE_RECIPIENT" \\
        >> "\$CYBRA_LICENSE_LEDGER"

    cybra_log "LICENSE_RECORDED contract=\$contract_id amount=\$amount license=\$license"
}'''

new = '''cybra_license_record() {
    local contract_id="\$1"
    local amount="\$2"
    local license_a="\$3"
    local license_b="\$4"

    # --- LEDGER A ---
    printf '%s | %s | A | %s | %s | %s\\n' \\
        "\$(cybra_now)" \\
        "\$contract_id" \\
        "\$amount" \\
        "\$license_a" \\
        "\$LICENSE_A_RECIPIENT" \\
        >> "\$CYBRA_LICENSE_LEDGER"

    # --- LEDGER B ---
    printf '%s | %s | B | %s | %s | %s\\n' \\
        "\$(cybra_now)" \\
        "\$contract_id" \\
        "\$amount" \\
        "\$license_b" \\
        "\$LICENSE_B_RECIPIENT" \\
        >> "\$CYBRA_LICENSE_LEDGER_B"

    cybra_log "DUAL_LICENSE_RECORDED contract=\$contract_id amount=\$amount A=\$license_a B=\$license_b"
}'''

if 'license_b="\$4"' in s:
    print("    [OK] record already dual")
elif old in s:
    s = s.replace(old, new)
    with open(p, "w") as f: f.write(s)
    print("    [FIXED] cybra_license_record dual")
else:
    print("    [WARN] cybra_license_record not matched")
PY

# ---- 2.4: LEDGER_B константа ----
python3 - <<PY
p = "$LIB"
with open(p) as f: s = f.read()

old = 'CYBRA_LICENSE_LEDGER="\$CYBRA_MOD19_ROOT/evidence/license_ledger.txt"'
new = 'CYBRA_LICENSE_LEDGER="\$CYBRA_MOD19_ROOT/evidence/license_ledger.txt"\nCYBRA_LICENSE_LEDGER_B="\$CYBRA_MOD19_ROOT/evidence/license_ledger_b.txt"'

if "CYBRA_LICENSE_LEDGER_B" in s:
    print("    [OK] LEDGER_B exists")
elif old in s:
    s = s.replace(old, new)
    with open(p, "w") as f: f.write(s)
    print("    [FIXED] LEDGER_B added")
else:
    print("    [WARN] LEDGER line not found")
PY

# ---- 2.5: cybra_contract_create — додаємо B-ліцензію ----
python3 - <<PY
p = "$LIB"
with open(p) as f: s = f.read()

old = '''    local contract_id="C-\$(date -u +%Y%m%d%H%M%S)-\$(cybra_rand_id)"
    local license="\$(cybra_calc_license "\$amount")"
    local net=\$(( amount - license ))
    local now="\$(cybra_now)"'''

new = '''    local contract_id="C-\$(date -u +%Y%m%d%H%M%S)-\$(cybra_rand_id)"
    local license_a="\$(cybra_calc_license "\$amount")"
    local license_b="\$(cybra_calc_license "\$amount")"
    local license_total=\$(( license_a + license_b ))
    local net=\$(( amount - license_total ))
    local now="\$(cybra_now)"'''

if "license_b=" in s and "license_total=" in s:
    print("    [OK] create already dual")
elif old in s:
    s = s.replace(old, new)
    with open(p, "w") as f: f.write(s)
    print("    [FIXED] create dual license calc")
else:
    print("    [WARN] create block not matched")
PY

# ---- 2.6: contract file template — dual fields ----
python3 - <<PY
p = "$LIB"
with open(p) as f: s = f.read()

old = '''AMOUNT_WEI=\$amount
LICENSE_WEI=\$license
NET_WEI=\$net

LICENSE_PERCENT=1
LICENSE_BPS=100
LICENSE_RECIPIENT=\$LICENSE_RECIPIENT
LICENSE_FROZEN=TRUE'''

new = '''AMOUNT_WEI=\$amount

# === DUAL-LICENSE v2 ===
LICENSE_A_WEI=\$license_a
LICENSE_A_PERCENT=1
LICENSE_A_BPS=100
LICENSE_A_RECIPIENT=\$LICENSE_A_RECIPIENT

LICENSE_B_WEI=\$license_b
LICENSE_B_PERCENT=1
LICENSE_B_BPS=100
LICENSE_B_RECIPIENT=\$LICENSE_B_RECIPIENT

LICENSE_TOTAL_WEI=\$license_total
NET_WEI=\$net
DUAL_LICENSE_FROZEN=TRUE

# Legacy
LICENSE_WEI=\$license_a
LICENSE_PERCENT=1
LICENSE_BPS=100
LICENSE_RECIPIENT=\$LICENSE_A_RECIPIENT
LICENSE_FROZEN=TRUE'''

if "LICENSE_A_WEI=" in s:
    print("    [OK] contract template dual")
elif old in s:
    s = s.replace(old, new)
    with open(p, "w") as f: f.write(s)
    print("    [FIXED] contract template dual")
else:
    print("    [WARN] contract template not matched")
PY

# ---- 2.7: замінюємо виклик record у create ----
python3 - <<PY
p = "$LIB"
with open(p) as f: s = f.read()

old = '''    # Ліцензія — в ledger
    cybra_license_record "\$contract_id" "\$amount" "\$license"

    cybra_log "CONTRACT_CREATED id=\$contract_id buyer=\$buyer seller=\$seller amount=\$amount license=\$license"'''

new = '''    # Подвійна ліцензія — в два ledger-и
    cybra_license_record "\$contract_id" "\$amount" "\$license_a" "\$license_b"

    cybra_log "CONTRACT_CREATED id=\$contract_id buyer=\$buyer seller=\$seller amount=\$amount license_A=\$license_a license_B=\$license_b"'''

if "license_A=" in s and "license_B=" in s:
    print("    [OK] create log dual")
elif old in s:
    s = s.replace(old, new)
    with open(p, "w") as f: f.write(s)
    print("    [FIXED] create log dual")
else:
    print("    [WARN] create log not matched")
PY

chmod +x "$LIB"

# ============================================================
# 3. Оновлюємо TUI меню — додаємо пункт [9] Dual-License Ledger
# ============================================================

head1 "[3] Оновлення TUI меню"

MENU="$MOD/bin/cybra_menu.sh"

# --- Функція для dual-license ledger ---
if grep -q "action_dual_license_ledger" "$MENU"; then
    log "  [OK] dual-license menu вже є"
else
    python3 - <<PY
p = "$MENU"
with open(p) as f: s = f.read()

# Додаємо функцію перед "action_hardening"
new_func = '''action_dual_license_ledger() {
    printf '%s\\n' "\${C_BOLD}--- DUAL-LICENSE LEDGER ---\${C_RESET}"
    printf '%s\\n' "\${C_GREY}LICENSE_A: 1% → \${LICENSE_A_RECIPIENT:0:10}...\${C_RESET}"
    printf '%s\\n' "\${C_GREY}LICENSE_B: 1% → \${LICENSE_B_RECIPIENT:0:10}...\${C_RESET}"
    printf '\\n'

    if [ -f "\$CYBRA_LICENSE_LEDGER" ]; then
        printf '%s\\n' "\${C_BOLD}--- LEDGER A ---\${C_RESET}"
        cat "\$CYBRA_LICENSE_LEDGER"
        printf '\\n%s\\n' "\${C_BOLD}Записів A:\${C_RESET} \$(wc -l < "\$CYBRA_LICENSE_LEDGER")"
    fi

    if [ -f "\$CYBRA_LICENSE_LEDGER_B" ]; then
        printf '\\n%s\\n' "\${C_BOLD}--- LEDGER B ---\${C_RESET}"
        cat "\$CYBRA_LICENSE_LEDGER_B"
        printf '\\n%s\\n' "\${C_BOLD}Записів B:\${C_RESET} \$(wc -l < "\$CYBRA_LICENSE_LEDGER_B")"
    fi
}

'''

if "action_dual_license_ledger()" not in s:
    s = s.replace("action_hardening() {", new_func + "action_hardening() {")

# Додаємо пункт у меню
old_menu = '''    printf '%s\\n' "  \${C_BOLD}[8]\${C_RESET} Hardening — перевірка системи"
    printf '%s\\n' "  \${C_BOLD}[0]\${C_RESET} Вихід"'''

new_menu = '''    printf '%s\\n' "  \${C_BOLD}[8]\${C_RESET} Hardening — перевірка системи"
    printf '%s\\n' "  \${C_BOLD}[9]\${C_RESET} DUAL-LICENSE ledger (A + B)"
    printf '%s\\n' "  \${C_BOLD}[0]\${C_RESET} Вихід"'''

if "[9]" not in s:
    s = s.replace(old_menu, new_menu)

# Додаємо обробку вибору 9
old_case = '''        8) action_hardening ;;'''
new_case = '''        8) action_hardening ;;
        9) action_dual_license_ledger ;;'''

if "9) action_dual_license_ledger" not in s:
    s = s.replace(old_case, new_case)

with open(p, "w") as f: f.write(s)
print("    [FIXED] TUI menu dual-license")
PY
    chmod +x "$MENU"
    FIX=$((FIX+1))
fi

# ============================================================
# 4. Оновлюємо тести
# ============================================================

head1 "[4] Оновлення тестів"

TESTS="$MOD/tests/run_tests.sh"
cp "$TESTS" "$TESTS.bak.$STAMP"

if grep -q "DUAL_LICENSE" "$TESTS"; then
    log "  [OK] dual-license test вже є"
else
    python3 - <<PY
p = "$TESTS"
with open(p) as f: s = f.read()

# Додаємо dual-license тести перед фінальним "Rules SHA-256"
extra_tests = '''# 16 — dual license A percent
[ "\$LICENSE_A_PERCENT" = "1" ] \\
    && ok "License A = 1%" || fail "License A percent"

# 17 — dual license B percent
[ "\$LICENSE_B_PERCENT" = "1" ] \\
    && ok "License B = 1%" || fail "License B percent"

# 18 — recipient A
[ "\$LICENSE_A_RECIPIENT" = "0x66434c5501242ccC71b5a39C765892921624B66c" ] \\
    && ok "License A recipient" || fail "License A recipient"

# 19 — recipient B
[ "\$LICENSE_B_RECIPIENT" = "0x66434c5501242ccC71b5a39C765892921624B66c" ] \\
    && ok "License B recipient" || fail "License B recipient"

# 20 — dual license enabled
[ "\$DUAL_LICENSE_ENABLED" = "TRUE" ] \\
    && ok "Dual-license enabled" || fail "Dual-license flag"

# 21 — dual ledger A exists
[ -f "\$CYBRA_LICENSE_LEDGER" ] \\
    && ok "Ledger A exists" || fail "Ledger A"

# 22 — dual ledger B exists
[ -f "\$CYBRA_LICENSE_LEDGER_B" ] \\
    && ok "Ledger B exists" || fail "Ledger B"

# 23 — contract має LICENSE_A_WEI
CF="\$(cybra_contract_path "\$CID")"
grep -q '^LICENSE_A_WEI=' "\$CF" \\
    && ok "Contract has LICENSE_A_WEI" || fail "LICENSE_A_WEI"

# 24 — contract має LICENSE_B_WEI
grep -q '^LICENSE_B_WEI=' "\$CF" \\
    && ok "Contract has LICENSE_B_WEI" || fail "LICENSE_B_WEI"

# 25 — contract має LICENSE_TOTAL
grep -q '^LICENSE_TOTAL_WEI=' "\$CF" \\
    && ok "Contract has LICENSE_TOTAL_WEI" || fail "LICENSE_TOTAL_WEI"

# 26 — contract dual frozen
grep -q '^DUAL_LICENSE_FROZEN=TRUE' "\$CF" \\
    && ok "Dual-license frozen" || fail "Dual frozen"

# 27 — 2% total on example
TOTAL_TEST="\$(cybra_calc_license 10000)"
[ "\$TOTAL_TEST" = "100" ] \\
    && ok "Single calc 10000 → 100" || fail "Single calc"

'''

marker = "# 15 — rules hash"
if marker in s:
    s = s.replace(marker, extra_tests + marker)
    with open(p, "w") as f: f.write(s)
    print("    [FIXED] test extended")
else:
    print("    [WARN] marker not found")
PY

    chmod +x "$TESTS"
    FIX=$((FIX+1))
fi

# ============================================================
# 5. Прогін тестів
# ============================================================

head1 "[5] Прогін тестів module_19"

if "$TESTS" > "$LOGS/m19_dual_test.log" 2>&1; then
    log "  [OK] module_19 dual-license self-test PASS"
    tail -6 "$LOGS/m19_dual_test.log" | sed 's/^/    /'
else
    log "  [FAIL] module_19 dual-license self-test FAIL"
    tail -20 "$LOGS/m19_dual_test.log" | sed 's/^/    /' | tee -a "$LOG"
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
    log "  [OK] snapshot re-sealed ($(wc -l < "$MOD/snapshot/final_manifest.sha256") files)"
else
    log "  [FAIL] snapshot verify"
    FAIL=$((FAIL+1))
fi

# ============================================================
# 7. Оновлення baseline
# ============================================================

head1 "[7] Оновлення baseline"

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

log "  [OK] baseline tree updated"

# ============================================================
# 8. Фінальний hardening
# ============================================================

head1 "[8] Фінальний hardening"

if [ -x "$ROOT/cybra_mega_hardening.sh" ]; then
    "$ROOT/cybra_mega_hardening.sh"
    RC=$?
else
    log "  [FAIL] hardening script not found"
    RC=1
fi

# ============================================================
# 9. Git push
# ============================================================

head1 "[9] Git push"

if [ -d "$ROOT/git_module" ]; then
    cd "$ROOT/git_module" || exit 1

    if [ -d .git ]; then
        git add -A 2>/dev/null || true
        git commit -m "CYBRA dual-license v2 $STAMP" 2>/dev/null || true
        if git push 2>&1 | tee -a "$LOG"; then
            log "  [OK] pushed"
        else
            log "  [WARN] push failed (може, немає змін або remote)"
        fi
    fi
fi

# ============================================================
# ЗВІТ
# ============================================================

head1 "DUAL-LICENSE UPGRADE SUMMARY"

log " STAMP      : $STAMP"
log " FIXED      : $FIX"
log " FAILED     : $FAIL"
log ""
log " LICENSE_A  : 1% → $LICENSE_A_RECIPIENT" 2>/dev/null || true
log " LICENSE_B  : 1% → $LICENSE_B_RECIPIENT" 2>/dev/null || true
log ""
log " Ledger A   : $MOD/evidence/license_ledger.txt"
log " Ledger B   : $MOD/evidence/license_ledger_b.txt"
log ""
log " Hardening  : $RC"
log " Log        : $LOG"
log ""
log "============================================================"

exit $RC
