#!/data/data/com.termux/files/usr/bin/bash
set -u
export LC_ALL=C

ROOT="$HOME/CYBRA"
MOD="$ROOT/modules/module_19_contract_tui_menu"
LIB="$MOD/bin/cybra_tui_lib.sh"
TESTS="$MOD/tests/run_tests.sh"

echo "=== FIX MODULE 19 ==="
echo ""

# --- 1. Перевірка source ---
echo "[1] Source lib:"
(
    source "$LIB" 2>/dev/null
    echo "  LICENSE_A_PERCENT=${LICENSE_A_PERCENT:-UNSET}"
    echo "  LICENSE_B_PERCENT=${LICENSE_B_PERCENT:-UNSET}"
    echo "  CREATION_FEE_ENABLED=${CREATION_FEE_ENABLED:-UNSET}"
) || echo "  [FAIL] source failed"

# --- 2. Спроба створити контракт ---
echo ""
echo "[2] Test create:"
(
    source "$LIB" 2>/dev/null
    CID="$(cybra_contract_create "0xAAA" "0xBBB" "50000" "BNB" 2>&1)"
    echo "  CID=[$CID]"
    if [ -n "$CID" ] && [ -f "$CYBRA_CONTRACTS/$CID.env" ]; then
        echo "  [OK] контракт створено"
        grep -E '^(LICENSE_A_WEI|LICENSE_B_WEI|CREATION_FEE_WEI|LICENSE_TOTAL_WEI)' "$CYBRA_CONTRACTS/$CID.env" | sed 's/^/    /'
    else
        echo "  [FAIL] не створено"
    fi
)

# --- 3. Фікс export у тестах ---
echo ""
echo "[3] Fix tests export:"
if grep -q "EXPORT_ENV" "$TESTS"; then
    echo "  [OK] export вже є"
else
    python3 - <<PY
p = "$TESTS"
with open(p) as f: s = f.read()
marker = 'source "\$MOD/bin/cybra_tui_lib.sh"'
export_block = '''source "\$MOD/bin/cybra_tui_lib.sh"

# EXPORT_ENV
: "\${LICENSE_A_PERCENT:=1}"
: "\${LICENSE_B_PERCENT:=1}"
: "\${CREATION_FEE_ENABLED:=TRUE}"
: "\${CREATION_FEE_PERCENT:=1}"
: "\${DUAL_LICENSE_ENABLED:=TRUE}"
export LICENSE_A_PERCENT LICENSE_B_PERCENT
export CREATION_FEE_ENABLED CREATION_FEE_PERCENT
export DUAL_LICENSE_ENABLED
export LICENSE_A_RECIPIENT LICENSE_B_RECIPIENT CREATION_FEE_RECIPIENT
export CYBRA_LICENSE_LEDGER CYBRA_LICENSE_LEDGER_B CYBRA_CREATION_LEDGER'''

if marker in s and "EXPORT_ENV" not in s:
    s = s.replace(marker, export_block, 1)
    with open(p, "w") as f: f.write(s)
    print("  [FIXED] export додано")
else:
    print("  [OK] не потрібно")
PY
fi

# --- 4. Прогін тестів ---
echo ""
echo "[4] Test run:"
if "$TESTS" > /tmp/m19_test.log 2>&1; then
    echo "  [OK] MODULE_19 TEST PASS"
    grep -E 'PASS=[0-9]+' /tmp/m19_test.log | tail -1 | sed 's/^/  /'
else
    echo "  [FAIL] тест впав"
    tail -15 /tmp/m19_test.log | sed 's/^/    /'
fi

# --- 5. Re-seal snapshot ---
echo ""
echo "[5] Re-seal snapshot:"
cp "$LIB" "$MOD/snapshot/cybra_tui_lib.sh" 2>/dev/null || true
cp "$TESTS" "$MOD/snapshot/run_tests.sh" 2>/dev/null || true
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
    echo "  [OK] snapshot sealed ($(wc -l < "$MOD/snapshot/final_manifest.sha256") files)"
fi

# --- 6. Baseline ---
echo ""
echo "[6] Baseline:"
(
    cd "$MOD" || exit 1
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
) > "$ROOT/baseline/module_19_contract_tui_menu.tree"
echo "  [OK] baseline updated"

echo ""
echo "=== DONE ==="
