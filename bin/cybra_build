#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# BUILD MODULE 20 → TEST → @cybra NODE → GIT PUSH
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
MOD20="$MODULES/module_20_evolution_guard"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
RUN="$STAMP-$$"
LOG="$LOGS/build_m20_${STAMP}.log"

mkdir -p "$LOGS" "$AUDIT" "$BASELINE" "$HASHES" "$NODE" "$GITMOD" "$PUBLIC"

FIX=0
FAIL=0
WARN=0

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

head1 "BUILD MODULE 20"
log "STAMP: $STAMP"
log "RUN:   $RUN"

# ============================================================
# 1. Перевірка структури module_20
# ============================================================

head1 "[1/7] Перевірка структури"

if [ ! -d "$MOD20" ]; then
    log "  [FAIL] module_20 не знайдено: $MOD20"
    exit 1
fi

for sub in bin state rules evidence tests snapshot; do
    if [ -d "$MOD20/$sub" ]; then
        log "  [OK] $sub/"
    else
        mkdir -p "$MOD20/$sub"
        log "  [FIXED] $sub/ створено"
        FIX=$((FIX+1))
    fi
done

# ============================================================
# 2. Прогін тестів
# ============================================================

head1 "[2/7] Прогін тестів"

TESTS="$MOD20/tests/run_tests.sh"
TESTLOG="$LOGS/m20_test.log"

if [ ! -x "$TESTS" ]; then
    chmod +x "$TESTS" 2>/dev/null
fi

if [ ! -f "$TESTS" ]; then
    log "  [FAIL] тестів немає"
    exit 1
fi

if "$TESTS" > "$TESTLOG" 2>&1; then
    log "  [OK] MODULE_20 TEST PASS"
    grep -E 'PASS=|FAIL=' "$TESTLOG" | tail -2 | sed 's/^/    /' | tee -a "$LOG"
    M20_PASS=1
else
    log "  [FAIL] MODULE_20 TEST FAIL"
    tail -20 "$TESTLOG" | sed 's/^/    /' | tee -a "$LOG"
    M20_PASS=0
    FAIL=$((FAIL+1))
fi

# ============================================================
# 3. Re-seal snapshot
# ============================================================

head1 "[3/7] Re-seal snapshot"

if [ -f "$MOD20/bin/cybra_evolution.sh" ]; then
    cp "$MOD20/bin/cybra_evolution.sh" "$MOD20/snapshot/"
fi
if [ -f "$MOD20/state/config.env" ]; then
    cp "$MOD20/state/config.env" "$MOD20/snapshot/"
fi
if [ -f "$MOD20/rules/evolution_rules.canonical" ]; then
    cp "$MOD20/rules/evolution_rules.canonical" "$MOD20/snapshot/"
fi
if [ -f "$MOD20/evidence/rules.sha256" ]; then
    cp "$MOD20/evidence/rules.sha256" "$MOD20/snapshot/"
fi
if [ -f "$TESTS" ]; then
    cp "$TESTS" "$MOD20/snapshot/run_tests.sh"
fi

rm -f "$MOD20/snapshot/final_manifest.sha256"
(
    cd "$MOD20/snapshot" || exit 1
    find . -type f \
        ! -name 'final_manifest.sha256' \
        ! -name '*.log' \
        -print0 |
    sort -z |
    xargs -0 -r sha256sum 2>/dev/null
) > "$MOD20/snapshot/final_manifest.sha256"

if (cd "$MOD20/snapshot" && sha256sum -c final_manifest.sha256 >/dev/null 2>&1); then
    log "  [OK] snapshot sealed ($(wc -l < "$MOD20/snapshot/final_manifest.sha256") files)"
else
    log "  [FAIL] snapshot verify"
    FAIL=$((FAIL+1))
fi

# ============================================================
# 4. Baseline
# ============================================================

head1 "[4/7] Baseline update"

while IFS= read -r -d '' d; do
    m="$(basename "$d")"
    case "$m" in
        @*|.*|_disabled*|evolution|answer_engine|node_modules) continue ;;
    esac
    h="$(hash_tree "$d")"
    printf '%s' "$h" > "$BASELINE/${m}.tree"
    log "  [OK] $m -> ${h:0:16}..."
done < <(find "$MODULES" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -z)

# ============================================================
# 5. @cybra NODE — індекс
# ============================================================

head1 "[5/7] @cybra node index"

rm -rf "$NODE"
mkdir -p "$NODE/modules"

cat > "$NODE/README.md" <<'RD'
# @cybra — CYBRA Node Index

Автоматично оновлюється через `cybra_build_m20.sh` / `cybra_auto_all.sh`.

## Модулі
Кожен модуль — окрема ланка верифікації контрактів.

## Принципи
1. Жодних auto-money дій
2. Ліцензія 1%+1%+1% (dual + creation) → `0x66434c5501242ccC71b5a39C765892921624B66c`
3. Тільки покращення (3% tolerance) — Module 20 Evolution Guard
4. Dual-backend hash для верифікації
RD

{
    printf '# CYBRA NODE INDEX\n'
    printf '# RUN=%s\n' "$RUN"
    printf '# STAMP=%s\n' "$STAMP"
    printf '#\n'
    printf '%-45s %-14s %-18s\n' "MODULE" "STATUS" "TREE_HASH"
    printf -- '--------------------------------------------------------------------\n'
} > "$NODE/index.txt"

{
    printf '{\n  "run": "%s",\n  "stamp": "%s",\n  "modules": [\n' "$RUN" "$STAMP"
} > "$NODE/index.json"

FIRST=1
COUNT=0

while IFS= read -r -d '' d; do
    m="$(basename "$d")"
    case "$m" in
        @*|.*|_disabled*|evolution|answer_engine|node_modules) continue ;;
    esac
    COUNT=$((COUNT+1))
    h="$(cat "$BASELINE/${m}.tree" 2>/dev/null || echo NOHASH)"
    p="$(cat "$BASELINE/${m}.pass" 2>/dev/null || echo 0)"
    f="$(cat "$BASELINE/${m}.fail" 2>/dev/null || echo 0)"

    printf '%-45s %-14s %-18s\n' "$m" "P=$p F=$f" "${h:0:16}" >> "$NODE/index.txt"

    if [ "$FIRST" -eq 0 ]; then printf ',\n' >> "$NODE/index.json"; fi
    FIRST=0
    printf '    {"name":"%s","pass":%s,"fail":%s,"tree":"%s"}' \
        "$m" "$p" "$f" "$h" >> "$NODE/index.json"

    ln -sfn "$d" "$NODE/modules/$m"
done < <(find "$MODULES" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -z)

{
    printf '\n  ],\n  "module_count": %s,\n' "$COUNT"
    printf '  "license_recipient": "0x66434c5501242ccC71b5a39C765892921624B66c",\n'
    printf '  "policy": "STRICT_NON_DEGRADATION_3PCT"\n}\n'
} >> "$NODE/index.json"

log "  [OK] @cybra node ($COUNT modules)"

# ============================================================
# 6. Dual-backend snapshot
# ============================================================

head1 "[6/7] Dual-backend snapshot"

DB_DIR="$HASHES/$STAMP"
mkdir -p "$DB_DIR"

CANON="$DB_DIR/canonical.state"
{
    printf 'CYBRA_CANONICAL_STATE\nRUN=%s\nSTAMP=%s\n\n' "$RUN" "$STAMP"
    for t in "$BASELINE"/*.tree; do
        [ -f "$t" ] || continue
        printf '%s %s\n' "$(basename "$t" .tree)" "$(cat "$t")"
    done
} | LC_ALL=C sort > "$CANON"

BACKEND_A="$(sha256sum "$CANON" | awk '{print $1}')"

BB_INPUT="$DB_DIR/backend_b.input"
{
    cat "$NODE/index.json" 2>/dev/null || echo ""
    printf '\n---\n'
    for t in "$BASELINE"/*.tree; do
        [ -f "$t" ] || continue
        printf '%s %s\n' "$(cat "$t")" "$(basename "$t")"
    done
} | LC_ALL=C sort > "$BB_INPUT"

BACKEND_B="$(sha256sum "$BB_INPUT" | awk '{print $1}')"

BC_INPUT="$DB_DIR/backend_c.input"
for t in "$BASELINE"/*.tree; do
    [ -f "$t" ] || continue
    printf '%s %s\n' "$(basename "$t" .tree)" "$(cat "$t")"
done | LC_ALL=C sort > "$BC_INPUT"

BACKEND_C="$(sha256sum "$BC_INPUT" | awk '{print $1}')"
BACKEND_D="$(sha256sum "$NODE/index.txt" | awk '{print $1}')"

DUAL_L1="$(printf '%s\n%s\n' "$BACKEND_A" "$BACKEND_B" | sha256sum | awk '{print $1}')"
DUAL_L2="$(printf '%s\n%s\n' "$BACKEND_C" "$BACKEND_D" | sha256sum | awk '{print $1}')"
ULTRA="$(printf '%s\n%s\n%s\n%s\n' "$BACKEND_A" "$BACKEND_B" "$BACKEND_C" "$BACKEND_D" | sha256sum | awk '{print $1}')"

cat > "$DB_DIR/dual_snapshot.env" <<EOF
RUN=$RUN
STAMP=$STAMP
BACKEND_A=$BACKEND_A
BACKEND_B=$BACKEND_B
BACKEND_C=$BACKEND_C
BACKEND_D=$BACKEND_D
DUAL_L1=$DUAL_L1
DUAL_L2=$DUAL_L2
ULTRA_DUAL=$ULTRA
MOD_COUNT=$COUNT
EOF

log "  BACKEND_A = ${BACKEND_A:0:16}..."
log "  BACKEND_B = ${BACKEND_B:0:16}..."
log "  BACKEND_C = ${BACKEND_C:0:16}..."
log "  BACKEND_D = ${BACKEND_D:0:16}..."
log "  DUAL_L1   = ${DUAL_L1:0:16}..."
log "  DUAL_L2   = ${DUAL_L2:0:16}..."
log "  ULTRA     = ${ULTRA:0:16}..."

# ============================================================
# 7. GIT PUSH
# ============================================================

head1 "[7/7] Git push"

if [ -d "$GITMOD/.git" ]; then
    # --- meta ---
    mkdir -p "$GITMOD/meta"
    cp "$NODE/index.json" "$GITMOD/meta/index.json"
    cp "$NODE/index.txt"  "$GITMOD/meta/index.txt"
    cp "$NODE/README.md"  "$GITMOD/README.md"
    cp "$DB_DIR/dual_snapshot.env" "$GITMOD/meta/dual_snapshot.env"

    for f in "$DB_DIR"/*; do
        [ -f "$f" ] && cp "$f" "$GITMOD/meta/"
    done

    # --- manifest ---
    {
        printf 'CYBRA GIT MODULE MANIFEST\n'
        printf 'RUN=%s\nSTAMP=%s\n\n' "$RUN" "$STAMP"
        printf 'ULTRA_DUAL=%s\n' "$ULTRA"
        printf 'DUAL_L1=%s\n' "$DUAL_L1"
        printf 'DUAL_L2=%s\n' "$DUAL_L2"
        printf '\nMODULE_COUNT=%s\n' "$COUNT"
        printf 'POLICY=STRICT_NON_DEGRADATION_3PCT\n'
        printf 'LICENSE_RECIPIENT=0x66434c5501242ccC71b5a39C765892921624B66c\n'
    } > "$GITMOD/manifest.txt"

    # --- modules export ---
    for d in "$MODULES"/*/; do
        [ -d "$d" ] || continue
        m="$(basename "$d")"
        case "$m" in
            @*|.*|_disabled*|evolution|answer_engine|node_modules) continue ;;
        esac

        target="$GITMOD/modules/$m"
        mkdir -p "$target"

        for sub in config rules evidence tests bin snapshot snapshots state payment; do
            if [ -d "$d/$sub" ]; then
                mkdir -p "$target/$sub"
                cp -r "$d/$sub"/* "$target/$sub/" 2>/dev/null || true
            fi
        done

        cat > "$target/README.md" <<EOF2
# Module: $m

- Tree: $(cat "$BASELINE/${m}.tree" 2>/dev/null || echo NOHASH)
- Pass: $(cat "$BASELINE/${m}.pass" 2>/dev/null || echo 0)
- Fail: $(cat "$BASELINE/${m}.fail" 2>/dev/null || echo 0)
EOF2
    done

    # --- git ops ---
    cd "$GITMOD" || exit 1
    git add -A 2>&1 | tee -a "$LOG" || true

    if [ -z "$(git status --porcelain 2>/dev/null)" ]; then
        log "  [OK] немає змін для push"
    else
        git commit -m "CYBRA build m20 $STAMP [mod=$COUNT ultra=${ULTRA:0:12}]" 2>&1 | tee -a "$LOG" || true

        if git push 2>&1 | tee -a "$LOG"; then
            log "  [OK] PUSHED to $(git remote get-url origin 2>/dev/null || echo NONE)"
        else
            log "  [WARN] push failed"
            WARN=$((WARN+1))
        fi
    fi
else
    log "  [FAIL] git repo відсутній"
    FAIL=$((FAIL+1))
fi

# ============================================================
# SUMMARY
# ============================================================

head1 "BUILD M20 — SUMMARY"

log ""
log " RUN             : $RUN"
log " STAMP           : $STAMP"
log " FIXED           : $FIX"
log " FAILED          : $FAIL"
log " WARN            : $WARN"
log ""
log " MODULE_20_TEST  : $([ "$M20_PASS" = "1" ] && echo PASS || echo FAIL)"
log " MODULE_COUNT    : $COUNT"
log ""
log " BACKEND_A       : ${BACKEND_A:0:16}..."
log " BACKEND_B       : ${BACKEND_B:0:16}..."
log " BACKEND_C       : ${BACKEND_C:0:16}..."
log " BACKEND_D       : ${BACKEND_D:0:16}..."
log " DUAL_L1         : ${DUAL_L1:0:16}..."
log " DUAL_L2         : ${DUAL_L2:0:16}..."
log " ULTRA_DUAL      : ${ULTRA:0:16}..."
log ""
log " @cybra node     : $NODE"
log " Git module      : $GITMOD"
log " Snapshot        : $DB_DIR"
log " Log             : $LOG"
log ""
log "============================================================"

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
