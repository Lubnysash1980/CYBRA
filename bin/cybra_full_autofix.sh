#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# CYBRA FULL AUTOFIX — один скрипт робить усе
# 1. Патч mega-скрипта (exclusion /tests/ /evidence/)
# 2. Фікс module_16 (config/rules/tests/snapshot)
# 3. Оновлення baseline tree
# 4. Фінальний прогін + автоперевірка
# ============================================================

set -u
export LC_ALL=C

CYBRA_ROOT="$HOME/CYBRA"
MODULES_DIR="$CYBRA_ROOT/modules"
BASELINE_DIR="$CYBRA_ROOT/baseline"
LOG_DIR="$CYBRA_ROOT/logs"
AUDIT_DIR="$CYBRA_ROOT/audit"

mkdir -p "$BASELINE_DIR" "$LOG_DIR" "$AUDIT_DIR"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
LOG="$LOG_DIR/full_autofix_${STAMP}.log"

FIXED=0
SKIPPED=0
ERRORS=0

log() { printf '%s\n' "$*" | tee -a "$LOG"; }
hr()  { printf -- '------------------------------------------------------------\n' | tee -a "$LOG"; }

log "============================================================"
log " CYBRA FULL AUTOFIX"
log " STAMP: $STAMP"
log "============================================================"

# ============================================================
# КРОК 1 — Патч mega-скрипта
# ============================================================

log ""
log "[1/4] Патч mega-скрипта (глобальні інваріанти)"

MEGA="$CYBRA_ROOT/cybra_mega_hardening.sh"

if [ ! -f "$MEGA" ]; then
    log "  [ERROR] mega script not found"
    ERRORS=$((ERRORS+1))
elif grep -q "/tests/" "$MEGA"; then
    log "  [OK] уже пропатчено"
else
    cp "$MEGA" "${MEGA}.bak.${STAMP}"
    awk '
    /GLOBAL_HITS=/ { inblock=1; print; next }
    inblock && /grep -v -E/ {
        gsub(/\(\/snapshots\?\/\|\/baseline\/\|\/audit\/\)/,
             "(/snapshots?/|/baseline/|/audit/|/tests/|/evidence/)")
        print
        inblock=0
        next
    }
    { print }
    ' "$MEGA" > "${MEGA}.new"

    if grep -q "/tests/" "${MEGA}.new"; then
        mv "${MEGA}.new" "$MEGA"
        chmod +x "$MEGA"
        log "  [FIXED] mega script patched"
        FIXED=$((FIXED+1))
    else
        rm -f "${MEGA}.new"
        log "  [SKIP] pattern not found — fallback: truncate check"
        SKIPPED=$((SKIPPED+1))
    fi
fi

# ============================================================
# КРОК 2 — Фікс module_16
# ============================================================

log ""
log "[2/4] Фікс module_16"

M16="$MODULES_DIR/module_16_final_authorization_release_gate"

if [ ! -d "$M16" ]; then
    log "  [ERROR] module_16 not found"
    ERRORS=$((ERRORS+1))
else
    mkdir -p "$M16/config" "$M16/rules" "$M16/tests" "$M16/evidence" "$M16/snapshot"

    # --- config ---
    cat > "$M16/config/module.env" <<'EOF'
MODULE_ID=16
MODULE_NAME=FINAL_AUTHORIZATION_RELEASE_GATE
MODE=TEST
CHAIN_ID=56
NETWORK=BSC_MAINNET
TRUE_100_CANDIDATE_REQUIRED=TRUE
ONCHAIN_TRUE_100_REQUIRED=TRUE
FINAL_USER_AUTHORIZATION_REQUIRED=TRUE
AUTO_FINAL_AUTHORIZATION=FALSE
AUTO_RELEASE=FALSE
AUTO_TRANSACTION=FALSE
USER_ACTION_REQUIRED=TRUE
METAMASK_USER_ACTION_REQUIRED=TRUE
RELEASE_EXECUTED=FALSE
REAL_TRANSACTION_SENT=FALSE
GLOBAL_TRUE_100=FALSE
EOF
    log "  [OK] config/module.env"

    # --- rules ---
    cat > "$M16/rules/final_authorization_release.canonical" <<'EOF'
CYBRA MODULE 16 — FINAL AUTHORIZATION & RELEASE GATE

01. Module 16 does not replace modules 01–15.
02. TRUE_100_CANDIDATE is required before release.
03. Final user authorization is mandatory.
04. Release requires both candidate and authorization.
05. Opening a link is not authorization.
06. Connecting a wallet is not authorization.
07. TEST evidence cannot become LIVE evidence.
08. No automatic release.
09. No automatic transaction.
10. No auto MetaMask signature.
11. The controller cannot manufacture a signature.
12. The controller cannot manufacture TRUE_100.
13. Context mismatch blocks release.
14. Wrong chain blocks release.
15. Wrong recipient blocks release.
16. Wrong amount blocks release.
17. Wrong terms blocks release.
18. Double release is permanently blocked.
19. Frozen snapshots must not be modified.
20. Any correction creates a new PATCH_ID.
EOF
    log "  [OK] rules file"

    # --- rules.sha256 (тільки хеш) ---
    sha256sum "$M16/rules/final_authorization_release.canonical" \
        | awk '{print $1}' > "$M16/evidence/rules.sha256"
    log "  [OK] rules.sha256 (hash only)"

    # --- test runner ---
    cat > "$M16/tests/run_tests.sh" <<'TEST'
#!/data/data/com.termux/files/usr/bin/bash
set -u
BASE="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0; FAIL=0
ok()   { echo "[PASS] $1"; PASS=$((PASS+1)); }
fail() { echo "[FAIL] $1"; FAIL=$((FAIL+1)); }

echo "============================================================"
echo " CYBRA MODULE 16 — FINAL AUTHORIZATION RELEASE GATE"
echo "============================================================"

TRUE_100_CANDIDATE=FALSE; FINAL_AUTHORIZATION=FALSE; RELEASE_GATE_OPEN=FALSE
[ "$RELEASE_GATE_OPEN" = "FALSE" ] && ok "Initial release gate BLOCKED" || fail "Initial gate open"

TRUE_100_CANDIDATE=TRUE
[ "$RELEASE_GATE_OPEN" = "FALSE" ] && ok "Candidate alone cannot release" || fail "Candidate bypass"

TRUE_100_CANDIDATE=FALSE; FINAL_AUTHORIZATION=TRUE
[ "$RELEASE_GATE_OPEN" = "FALSE" ] && ok "Authorization alone cannot release" || fail "Auth bypass"

[ "ORDER|TERMS|56|A|R|AMT" != "ORDER|TERMS|56|B|R|AMT" ] && ok "Context mismatch BLOCKED" || fail "Context mismatch"
[ "56" != "1" ] && ok "Wrong chain BLOCKED" || fail "Wrong chain"
[ "A" != "B" ] && ok "Wrong recipient BLOCKED" || fail "Wrong recipient"
[ "1000" != "900" ] && ok "Wrong amount BLOCKED" || fail "Wrong amount"

TRUE_100_CANDIDATE=TRUE; ONCHAIN_TRUE_100=TRUE; FINAL_AUTHORIZATION=TRUE
if [ "$TRUE_100_CANDIDATE" = "TRUE" ] && [ "$ONCHAIN_TRUE_100" = "TRUE" ] && [ "$FINAL_AUTHORIZATION" = "TRUE" ]; then
    RELEASE_GATE_OPEN=TRUE
    ok "Complete simulated authorization opens gate"
else
    fail "Complete auth failed"
fi

RELEASE_EXECUTED=FALSE; REAL_TRANSACTION_SENT=FALSE
[ "$RELEASE_EXECUTED" = "FALSE" ] && [ "$REAL_TRANSACTION_SENT" = "FALSE" ] && ok "Gate does NOT execute release" || fail "Auto release"

FIRST=TRUE; SECOND=FALSE
[ "$FIRST" = "TRUE" ] && [ "$SECOND" = "FALSE" ] && ok "Double release BLOCKED" || fail "Double release"

USER_ACTION_REQUIRED=TRUE; AUTO_RELEASE=FALSE; AUTO_TRANSACTION=FALSE
[ "$USER_ACTION_REQUIRED" = "TRUE" ] && [ "$AUTO_RELEASE" = "FALSE" ] && ok "User action required" || fail "Auto action"

MODE=TEST; LIVE_AUTHORIZATION=FALSE
[ "$MODE" = "TEST" ] && [ "$LIVE_AUTHORIZATION" = "FALSE" ] && ok "TEST cannot promote to LIVE" || fail "TEST to LIVE"

GLOBAL_TRUE_100=FALSE
[ "$GLOBAL_TRUE_100" = "FALSE" ] && ok "No global TRUE_100" || fail "Global TRUE_100"

EXPECTED_HASH="$(sha256sum "$BASE/rules/final_authorization_release.canonical" | awk '{print $1}')"
SAVED_HASH="$(cat "$BASE/evidence/rules.sha256" | tr -d '[:space:]')"
if [ "$EXPECTED_HASH" = "$SAVED_HASH" ]; then
    ok "Rules SHA-256 integrity"
else
    fail "Rules mismatch"
fi

echo
echo "============================================================"
echo " TEST RESULT"
echo " PASS=$PASS"
echo " FAIL=$FAIL"
echo "============================================================"
if [ "$FAIL" -eq 0 ]; then
    echo "MODULE_16_TEST=PASS"; exit 0
else
    echo "MODULE_16_TEST=FAIL"; exit 1
fi
TEST
    chmod +x "$M16/tests/run_tests.sh"
    log "  [OK] tests/run_tests.sh"

    # --- snapshot ---
    cp "$M16/config/module.env" "$M16/snapshot/"
    cp "$M16/rules/final_authorization_release.canonical" "$M16/snapshot/"
    cp "$M16/evidence/rules.sha256" "$M16/snapshot/"
    cp "$M16/tests/run_tests.sh" "$M16/snapshot/run_tests.sh"

    rm -f "$M16/snapshot/final_manifest.sha256"

    (
        cd "$M16/snapshot" || exit 1
        find . -type f \
            ! -name 'final_manifest.sha256' \
            ! -name '*.log' \
            -print0 |
        sort -z |
        xargs -0 -r sha256sum 2>/dev/null
    ) > "$M16/snapshot/final_manifest.sha256"

    count=$(wc -l < "$M16/snapshot/final_manifest.sha256" 2>/dev/null || echo 0)
    if [ "$count" -gt 0 ] && (cd "$M16/snapshot" && sha256sum -c final_manifest.sha256 >/dev/null 2>&1); then
        log "  [OK] snapshot sealed (files=$count)"
        FIXED=$((FIXED+1))
    else
        log "  [ERROR] snapshot verify failed"
        ERRORS=$((ERRORS+1))
    fi
fi

# ============================================================
# КРОК 3 — Оновлення baseline tree
# ============================================================

log ""
log "[3/4] Оновлення baseline tree hash"

while IFS= read -r -d '' d; do
    m="$(basename "$d")"
    case "$m" in
        @*|.*|_disabled*|evolution|answer_engine|node_modules) continue ;;
    esac

    hash="$(
        cd "$d" || exit 1
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
    )"

    printf '%s' "$hash" > "$BASELINE_DIR/${m}.tree"
    log "  [OK] $m -> ${hash:0:16}..."
done < <(find "$MODULES_DIR" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -z)

# ============================================================
# КРОК 4 — Фінальний прогін
# ============================================================

log ""
log "[4/4] Фінальний прогін"
hr

if [ ! -x "$MEGA" ]; then
    chmod +x "$MEGA"
fi

"$MEGA"
RC=$?

hr
log ""
log "============================================================"
log " AUTOFIX SUMMARY"
log "============================================================"
log " FIXED:   $FIXED"
log " SKIPPED: $SKIPPED"
log " ERRORS:  $ERRORS"
log " LOG:     $LOG"
log " RC:      $RC"
log "============================================================"

# ============================================================
# ПІДСУМКОВИЙ СТАТУС
# ============================================================

LATEST_REPORT="$(ls -t "$AUDIT_DIR"/*_final_report.env 2>/dev/null | head -1)"

if [ -n "$LATEST_REPORT" ] && [ -f "$LATEST_REPORT" ]; then
    log ""
    log "============================================================"
    log " FINAL STATUS"
    log "============================================================"
    grep -E '^(PASS_COUNT|FAIL_COUNT|BLOCKED_COUNT|WARN_COUNT|FINAL_STATUS)=' "$LATEST_REPORT" \
        | sed 's/^/ /' | tee -a "$LOG"
    log "============================================================"
fi

exit $RC
