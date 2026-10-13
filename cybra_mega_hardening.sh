#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# CYBRA MEGA HARDENING SCRIPT v2
# ============================================================

export LC_ALL=C
export LANG=C

# ВАЖЛИВО: вимикаємо set -e на весь скрипт.
# Використовуємо явні перевірки return codes.
set -uo pipefail

CYBRA_ROOT="$HOME/CYBRA"
MODULES_DIR="$CYBRA_ROOT/modules"
AUDIT_DIR="$CYBRA_ROOT/audit"
BASELINE_DIR="$CYBRA_ROOT/baseline"
EVOLUTION_DIR="$CYBRA_ROOT/evolution"
LOG_DIR="$CYBRA_ROOT/logs"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_ID="RUN-${STAMP}-$$"

TOLERANCE_PCT=3

OWNER_MARKER="$CYBRA_ROOT/.owner"

mkdir -p "$AUDIT_DIR" "$BASELINE_DIR" "$EVOLUTION_DIR" "$LOG_DIR"

LOG_FILE="$LOG_DIR/mega_hardening_${STAMP}.log"

PASS_COUNT=0
FAIL_COUNT=0
BLOCKED_COUNT=0
WARN_COUNT=0
SKIP_COUNT=0

TOTAL_MODULES=0
VERIFIED_MODULES=0

# ------------------------------------------------------------
# Logging
# ------------------------------------------------------------

log() {
    printf '%s | %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >> "$LOG_FILE"
    printf '%s | %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"
}

log_section() {
    {
        printf '\n'
        printf -- '============================================================\n'
        printf ' %s\n' "$*"
        printf -- '============================================================\n'
    } | tee -a "$LOG_FILE"
}

ok() {
    PASS_COUNT=$((PASS_COUNT + 1))
    printf '  [OK]      %s\n' "$*" | tee -a "$LOG_FILE"
}

fail() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf '  [FAIL]    %s\n' "$*" | tee -a "$LOG_FILE"
}

warn() {
    WARN_COUNT=$((WARN_COUNT + 1))
    printf '  [WARN]    %s\n' "$*" | tee -a "$LOG_FILE"
}

blocked() {
    BLOCKED_COUNT=$((BLOCKED_COUNT + 1))
    printf '  [BLOCKED] %s\n' "$*" | tee -a "$LOG_FILE"
}

skip() {
    SKIP_COUNT=$((SKIP_COUNT + 1))
    printf '  [SKIP]    %s\n' "$*" | tee -a "$LOG_FILE"
}

die() {
    printf '  [FATAL]   %s\n' "$*" | tee -a "$LOG_FILE"
    exit 1
}

# ------------------------------------------------------------
# Safe helpers
# ------------------------------------------------------------

safe_hash_file() {
    local f="$1"
    [ ! -e "$f" ] && { printf 'MISSING'; return 0; }
    [ ! -f "$f" ] && { printf 'NOTFILE'; return 0; }
    sha256sum "$f" 2>/dev/null | awk '{print $1}'
}

safe_hash_tree() {
    local dir="$1"
    [ ! -d "$dir" ] && { printf 'NODIR'; return 0; }
    (
        cd "$dir" 2>/dev/null || { printf 'CD_FAIL'; exit 0; }
        find . -type f \
            ! -name '*.log' \
            ! -name '*.test.log' \
            ! -name 'SNAPSHOT_SHA256.txt' \
            ! -name 'test_output.txt' \
            ! -name 'test_output.sha256' \
            -print0 2>/dev/null |
        sort -z |
        xargs -0 -r sha256sum 2>/dev/null |
        sha256sum 2>/dev/null | awk '{print $1}'
    )
}

# ------------------------------------------------------------
# 3% tolerance
# ------------------------------------------------------------

pct_within_tolerance() {
    local old="$1"
    local new="$2"
    local tol="$3"

    [ -z "$old" ] || [ -z "$new" ] && return 1
    [ "$old" = "0" ] && [ "$new" = "0" ] && return 0

    local diff abs_diff
    diff=$(( new - old ))
    abs_diff=$diff
    [ "$diff" -lt 0 ] && abs_diff=$(( -diff ))

    if [ "$old" -eq 0 ]; then
        [ "$abs_diff" -eq 0 ] && return 0
        return 1
    fi

    local allowed
    allowed=$(( old * tol / 100 ))
    [ "$allowed" -lt 1 ] && allowed=1

    [ "$abs_diff" -le "$allowed" ] && return 0
    return 1
}

check_non_degradation() {
    local module="$1"
    local metric="$2"
    local old_val="$3"
    local new_val="$4"

    if [ -z "$old_val" ] || [ -z "$new_val" ]; then
        warn "$module/$metric: no baseline (old='$old_val' new='$new_val')"
        return 0
    fi

    if pct_within_tolerance "$old_val" "$new_val" "$TOLERANCE_PCT"; then
        ok "$module/$metric stable (old=$old_val new=$new_val)"
        return 0
    fi

    if [ "$new_val" -lt "$old_val" ]; then
        blocked "$module/$metric DEGRADED (old=$old_val new=$new_val > ${TOLERANCE_PCT}%)"
        return 1
    fi

    ok "$module/$metric improved (old=$old_val new=$new_val)"
    return 0
}

# ------------------------------------------------------------
# Baseline
# ------------------------------------------------------------

load_baseline() {
    local module="$1"
    local key="$2"
    local f="$BASELINE_DIR/${module}.${key}"
    [ -f "$f" ] && cat "$f" || printf ''
}

save_baseline() {
    local module="$1"
    local key="$2"
    local val="$3"
    printf '%s' "$val" > "$BASELINE_DIR/${module}.${key}"
}

# ------------------------------------------------------------
# Owner check
# ------------------------------------------------------------

require_owner() {
    if [ ! -f "$OWNER_MARKER" ]; then
        printf 'CYBRA_OWNER_%s\n' "$STAMP" > "$OWNER_MARKER"
        chmod 600 "$OWNER_MARKER"
        log "Created owner marker: $OWNER_MARKER"
    fi
    local val
    val="$(cat "$OWNER_MARKER" 2>/dev/null || true)"
    [ -z "$val" ] && die "Owner marker empty"
    ok "Owner verified ($val)"
}

# ------------------------------------------------------------
# Module exclusion rule
# ------------------------------------------------------------

is_module_dir() {
    local name="$1"
    case "$name" in
        @*) return 1 ;;
        .*) return 1 ;;
        _disabled*) return 1 ;;
        evolution) return 1 ;;
        answer_engine) return 1 ;;
        node_modules) return 1 ;;
        audit) return 1 ;;
        baseline) return 1 ;;
        logs) return 1 ;;
        out) return 1 ;;
        *) return 0 ;;
    esac
}

# ------------------------------------------------------------
# Module checks
# ------------------------------------------------------------

check_no_auto_money() {
    local module_path="$1"
    local module="$2"
    local hits=""

    # Скануємо ТІЛЬКИ .env файли і ТІЛЬКИ assignments на початку рядка
    while IFS= read -r envf; do
        [ -z "$envf" ] && continue
        case "$envf" in
            *.bak.*|*test_output*|*.log) continue ;;
            */snapshot/*|*/snapshots/*|*/tests/*) continue ;;
        esac
        if grep -qE '^(AUTO_TRANSACTION|AUTO_RELEASE|AUTO_PAYMENT|REAL_TRANSACTION_SENT|LIVE_AUTHORIZATION)=TRUE$' "$envf" 2>/dev/null; then
            hits="$hits $envf"
        fi
    done < <(find "$module_path" -name '*.env' -type f 2>/dev/null)

    if [ -n "$hits" ]; then
        blocked "$module auto-money rule violations:$hits"
        return 1
    fi
    ok "$module no auto-money rules"
    return 0
}

run_module_test() {
    local module_path="$1"
    local module="$2"
    local runner=""

    # знаходимо перший виконуваний тест
    for candidate in \
        "$module_path/tests/run_tests.sh" \
        "$module_path/tests/test_module_04.sh" \
        "$module_path/tests/test_module_05.sh" \
        "$module_path/tests/test_module_06.sh" \
        "$module_path/tests/test_module_07.sh" \
        "$module_path/tests/test_module_08.sh" \
        "$module_path/tests/test_module_09.sh" \
        "$module_path/tests/test_module_10.sh" \
        "$module_path/tests/test_module_11.sh" \
        "$module_path/tests/test_executor.sh" \
        "$module_path/tests/test_contract_builder.sh" \
        "$module_path/tests/test_escrow_controller.sh"
    do
        if [ -f "$candidate" ] && [ -x "$candidate" ]; then
            runner="$candidate"
            break
        fi
    done

    if [ -z "$runner" ]; then
        warn "$module: no executable test runner"
        return 2
    fi

    local out="$AUDIT_DIR/${RUN_ID}_${module}.test.log"

    # явно глушимо set -e вплив
    if bash "$runner" > "$out" 2>&1; then
        ok "$module self-test PASS"
        return 0
    fi

    fail "$module self-test FAIL (log: $out)"
    return 1
}

extract_pass_fail() {
    local file="$1"
    [ ! -f "$file" ] && { printf '0 0'; return; }
    local p f
    # Формат 1: MODULE_XX_PASS=N / MODULE_XX_FAIL=N
    p="$(grep -oE 'MODULE_[0-9]+_PASS=[0-9]+' "$file" 2>/dev/null | tail -1 | cut -d= -f2 || true)"
    f="$(grep -oE 'MODULE_[0-9]+_FAIL=[0-9]+' "$file" 2>/dev/null | tail -1 | cut -d= -f2 || true)"

    # Формат 2: P=[0-9]+ в summary
    if [ -z "$p" ]; then
        p="$(grep -oE 'PASS=[0-9]+' "$file" 2>/dev/null | tail -1 | cut -d= -f2 || true)"
    fi
    if [ -z "$f" ]; then
        f="$(grep -oE 'FAIL=[0-9]+' "$file" 2>/dev/null | tail -1 | cut -d= -f2 || true)"
    fi

    # Формат 3: рахуємо рядки [PASS] / [FAIL]
    if [ -z "$p" ] && [ -z "$f" ]; then
        p="$(grep -c '\[PASS\]' "$file" 2>/dev/null || true)"
        f="$(grep -c '\[FAIL\]' "$file" 2>/dev/null || true)"
    fi

    p="${p:-0}"
    f="${f:-0}"
    printf '%s %s' "$p" "$f"
}

check_snapshot_integrity() {
    local module_path="$1"
    local module="$2"

    local snapshot_dir=""
    for d in "$module_path/snapshot" "$module_path/snapshots"; do
        if [ -d "$d" ]; then
            snapshot_dir="$d"
            break
        fi
    done

    if [ -z "$snapshot_dir" ]; then
        warn "$module no snapshot dir"
        return 2
    fi

    # шукаємо маніфест
    local manifest=""
    for m in \
        "$snapshot_dir/final_manifest.sha256" \
        "$snapshot_dir/SNAPSHOT_SHA256.txt"
    do
        if [ -f "$m" ]; then
            manifest="$m"
            break
        fi
    done

    if [ -z "$manifest" ]; then
        warn "$module snapshot dir exists but no manifest"
        return 2
    fi

    if (cd "$snapshot_dir" && sha256sum -c "$(basename "$manifest")" >/dev/null 2>&1); then
        ok "$module snapshot integrity OK"
        return 0
    fi

    blocked "$module snapshot integrity FAILED"
    return 1
}

# ============================================================
# MAIN
# ============================================================

log_section "CYBRA MEGA HARDENING v2"
log "RUN_ID=$RUN_ID"
log "TOLERANCE_PCT=$TOLERANCE_PCT"
log "MODULES_DIR=$MODULES_DIR"
log "LOG_FILE=$LOG_FILE"
log ""

require_owner

# ------------------------------------------------------------
# Discovery
# ------------------------------------------------------------

log_section "MODULE DISCOVERY"

MODULE_LIST=()
while IFS= read -r -d '' d; do
    name="$(basename "$d")"
    if is_module_dir "$name"; then
        MODULE_LIST+=("$name")
    else
        skip "excluded: $name"
    fi
done < <(find "$MODULES_DIR" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -z)

TOTAL_MODULES="${#MODULE_LIST[@]}"
log "Modules to verify: $TOTAL_MODULES"

if [ "$TOTAL_MODULES" -eq 0 ]; then
    die "No valid modules found"
fi

# ------------------------------------------------------------
# Per-module loop
# ------------------------------------------------------------

for module in "${MODULE_LIST[@]}"; do
    module_path="$MODULES_DIR/$module"

    log_section "MODULE: $module"

    # 1) auto-money
    check_no_auto_money "$module_path" "$module" || true

    # 2) snapshot
    check_snapshot_integrity "$module_path" "$module" || true

    # 3) self-test
    run_module_test "$module_path" "$module"
    test_rc=$?

    # 4) pass/fail extraction
    test_log="$AUDIT_DIR/${RUN_ID}_${module}.test.log"
    read -r mod_pass mod_fail < <(extract_pass_fail "$test_log")
    mod_pass="${mod_pass:-0}"
    mod_fail="${mod_fail:-0}"

    # якщо тест-раннер відсутній — не караємо
    if [ "$test_rc" -eq 2 ]; then
        mod_pass=0
        mod_fail=0
    fi

    # 5) non-degradation
    old_pass="$(load_baseline "$module" pass)"
    old_fail="$(load_baseline "$module" fail)"
    old_pass="${old_pass:-0}"
    old_fail="${old_fail:-0}"

    check_non_degradation "$module" pass "$old_pass" "$mod_pass" || true

    # Fail count: блокуємо тільки якщо baseline > 0 (не false-positive на першому запуску)
    if [ "$old_fail" -gt 0 ] && [ "$mod_fail" -gt "$old_fail" ]; then
        blocked "$module fail count increased ($old_fail -> $mod_fail)"
    fi

    save_baseline "$module" pass "$mod_pass"
    save_baseline "$module" fail "$mod_fail"

    # 6) tree hash
    tree_hash="$(safe_hash_tree "$module_path")"
    old_tree="$(load_baseline "$module" tree)"

    if [ -n "$old_tree" ] && [ "$old_tree" != "$tree_hash" ]; then
        warn "$module tree changed since last run"
    fi

    save_baseline "$module" tree "$tree_hash"

    VERIFIED_MODULES=$((VERIFIED_MODULES + 1))
done

# ------------------------------------------------------------
# Global invariants
# ------------------------------------------------------------

log_section "GLOBAL INVARIANTS"

GLOBAL_HITS="$(
    grep -rIl -e 'GLOBAL_TRUE_100=TRUE' -e 'TRUE_100=TRUE' \
        "$MODULES_DIR" 2>/dev/null |
        grep -v -E '(/snapshots?/|/baseline/|/audit/|/tests/|/evidence/|/bin/|/*\.sh)' || true
)"

if [ -n "$GLOBAL_HITS" ]; then
    warn "TRUE_100=TRUE found outside snapshots:"
    printf '%s\n' "$GLOBAL_HITS" | tee -a "$LOG_FILE"
else
    ok "No premature TRUE_100=TRUE in live module files"
fi

# ------------------------------------------------------------
# Report
# ------------------------------------------------------------

log_section "FINAL REPORT"

TOTAL_CHECKS=$((PASS_COUNT + FAIL_COUNT + BLOCKED_COUNT))

FINAL_STATUS="TRUE_100"
if [ "$FAIL_COUNT" -gt 0 ] || [ "$BLOCKED_COUNT" -gt 0 ]; then
    FINAL_STATUS="FALSE_RETRY"
fi

REPORT="$AUDIT_DIR/${RUN_ID}_final_report.env"

cat > "$REPORT" <<REP
RUN_ID=$RUN_ID
STAMP=$STAMP
TOTAL_MODULES=$TOTAL_MODULES
VERIFIED_MODULES=$VERIFIED_MODULES
TOLERANCE_PCT=$TOLERANCE_PCT
PASS_COUNT=$PASS_COUNT
FAIL_COUNT=$FAIL_COUNT
BLOCKED_COUNT=$BLOCKED_COUNT
WARN_COUNT=$WARN_COUNT
SKIP_COUNT=$SKIP_COUNT
TOTAL_CHECKS=$TOTAL_CHECKS
FINAL_STATUS=$FINAL_STATUS
REAL_TRANSACTION=NOT_PERFORMED
AUTO_MONEY_ACTIONS=BLOCKED
DEGRADATION=BLOCKED
EVOLUTION=OWNER_ONLY
REP

sha256sum "$REPORT" > "$REPORT.sha256"

log "RUN_ID              : $RUN_ID"
log "MODULES_FOUND       : $TOTAL_MODULES"
log "MODULES_VERIFIED    : $VERIFIED_MODULES"
log "TOLERANCE           : ${TOLERANCE_PCT}%"
log ""
log "PASS                : $PASS_COUNT"
log "FAIL                : $FAIL_COUNT"
log "BLOCKED             : $BLOCKED_COUNT"
log "WARN                : $WARN_COUNT"
log "SKIP                : $SKIP_COUNT"
log ""
log "FINAL_STATUS        : $FINAL_STATUS"
log "REPORT              : $REPORT"
log "REPORT_HASH         : $(cat "$REPORT.sha256")"
log "LOG                 : $LOG_FILE"

[ "$FINAL_STATUS" = "TRUE_100" ] && exit 0 || exit 1
