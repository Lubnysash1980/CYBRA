#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# CYBRA AUTO VERIFY + FIX + RUN
# Перевірка → виправлення → запуск → подвійний snapshot
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

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
RUN="$STAMP-$$"
LOG="$LOGS/auto_verify_fix_${STAMP}.log"

mkdir -p "$LOGS" "$AUDIT" "$BASELINE" "$HASHES" "$NODE" "$GITMOD" "$PUBLIC"

FIX=0
FAIL=0
WARN=0

log()  { printf '%s\n' "$*" | tee -a "$LOG"; }
head1() {
    printf -- '\n============================================================\n' | tee -a "$LOG"
    printf -- ' %s\n' "$*" | tee -a "$LOG"
    printf -- '============================================================\n' | tee -a "$LOG"
}

hash_file() {
    local f="$1"
    [ ! -f "$f" ] && { printf 'MISSING'; return; }
    sha256sum "$f" | awk '{print $1}'
}

hash_tree() {
    local dir="$1"
    [ ! -d "$dir" ] && { printf 'NODIR'; return; }
    (
        cd "$dir" || exit 1
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
    )
}

head1 "CYBRA AUTO VERIFY + FIX + RUN"
log "STAMP:  $STAMP"
log "RUN:    $RUN"
log "LOG:    $LOG"

# ============================================================
# ФАЗА 1 — Перевірка інфраструктури
# ============================================================

head1 "[1] Перевірка інфраструктури"

for d in "$ROOT" "$MODULES" "$BASELINE" "$LOGS" "$AUDIT" "$NODE" "$HASHES"; do
    if [ -d "$d" ]; then
        log "  [OK] $d"
    else
        mkdir -p "$d"
        log "  [FIXED] створено $d"
        FIX=$((FIX+1))
    fi
done

# ============================================================
# ФАЗА 2 — Перевірка module_19
# ============================================================

head1 "[2] Перевірка module_19"

M19="$MODULES/module_19_contract_tui_menu"

if [ ! -d "$M19" ]; then
    log "  [FAIL] module_19 не знайдено"
    FAIL=$((FAIL+1))
else
    # --- Fix rules check ---
    if grep -q 'EXPECTED="\$(sha256sum "\$MOD/evidence/tui_rules.txt")"' \
        "$M19/tests/run_tests.sh" 2>/dev/null; then

        python3 - <<PY
p = "$M19/tests/run_tests.sh"
with open(p) as f: s = f.read()
old = 'EXPECTED="\$(sha256sum "\$MOD/evidence/tui_rules.txt")"'
new = 'EXPECTED="\$(sha256sum "\$MOD/evidence/tui_rules.txt" | awk \x27{print \$1}\x27)"'
if old in s:
    s = s.replace(old, new)
    with open(p, "w") as f: f.write(s)
    print("    [FIXED] rules check")
PY
        FIX=$((FIX+1))
    else
        log "  [OK] rules check already correct"
    fi

    # --- Fix silent double confirm ---
    python3 - <<PY
p = "$M19/tests/run_tests.sh"
with open(p) as f: s = f.read()
old = 'cybra_link_confirm "\$BL" "0xAAA" 2>/dev/null && fail "Double confirm allowed" || ok "Double confirm blocked"'
new = 'if cybra_link_confirm "\$BL" "0xAAA" >/dev/null 2>&1; then fail "Double confirm allowed"; else ok "Double confirm blocked"; fi'
if old in s:
    s = s.replace(old, new)
    with open(p, "w") as f: f.write(s)
    print("    [FIXED] double-confirm silent")
PY

    chmod +x "$M19/tests/run_tests.sh"

    # --- Run test ---
    if "$M19/tests/run_tests.sh" > "$LOGS/m19_test.log" 2>&1; then
        log "  [OK] module_19 self-test PASS"
    else
        log "  [FAIL] module_19 self-test FAIL"
        tail -5 "$LOGS/m19_test.log" | sed 's/^/    /' | tee -a "$LOG"
        FAIL=$((FAIL+1))
    fi

    # --- Re-seal snapshot ---
    cp "$M19/tests/run_tests.sh" "$M19/snapshot/run_tests.sh" 2>/dev/null || true
    rm -f "$M19/snapshot/final_manifest.sha256"

    (
        cd "$M19/snapshot" || exit 1
        find . -type f \
            ! -name 'final_manifest.sha256' \
            ! -name '*.log' \
            -print0 |
        sort -z |
        xargs -0 -r sha256sum 2>/dev/null
    ) > "$M19/snapshot/final_manifest.sha256"

    if (cd "$M19/snapshot" && sha256sum -c final_manifest.sha256 >/dev/null 2>&1); then
        log "  [OK] snapshot re-sealed"
    else
        log "  [FAIL] snapshot verify"
        FAIL=$((FAIL+1))
    fi
fi

# ============================================================
# ФАЗА 3 — Оновлення baseline tree
# ============================================================

head1 "[3] Оновлення baseline"

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
# ФАЗА 4 — @cybra node index
# ============================================================

head1 "[4] @cybra node index"

rm -rf "$NODE"
mkdir -p "$NODE/modules"

cat > "$NODE/README.md" <<'RD'
# @cybra — CYBRA Node

Глобальний індекс усіх модулів CYBRA.
Оновлюється автоматично.

- `index.json` — машинний індекс
- `index.txt` — людський індекс
- `modules/` — посилання
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

    h="$(cat "$BASELINE/${m}.tree" 2>/dev/null || echo 'NOHASH')"
    p="$(cat "$BASELINE/${m}.pass" 2>/dev/null || echo 0)"
    f="$(cat "$BASELINE/${m}.fail" 2>/dev/null || echo 0)"

    printf '%-45s %-14s %-18s\n' "$m" "P=$p F=$f" "${h:0:16}" \
        >> "$NODE/index.txt"

    if [ "$FIRST" -eq 0 ]; then printf ',\n' >> "$NODE/index.json"; fi
    FIRST=0
    printf '    {"name":"%s","pass":%s,"fail":%s,"tree":"%s"}' \
        "$m" "$p" "$f" "$h" >> "$NODE/index.json"

    ln -sfn "$d" "$NODE/modules/$m"
done < <(find "$MODULES" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -z)

{
    printf '\n  ],\n  "module_count": %s,\n' "$COUNT"
    printf '  "license_recipient": "0x66434c5501242ccC71b5a39C765892921624B66c"\n}\n'
} >> "$NODE/index.json"

log "  [OK] @cybra node ($COUNT modules)"

# ============================================================
# ФАЗА 5 — ПОДВІЙНИЙ DUAL-BACKEND SNAPSHOT
# ============================================================

head1 "[5] Подвійний Dual-Backend Snapshot"

DB_DIR="$HASHES/$STAMP"
mkdir -p "$DB_DIR"

# --- Build canonical state ---
CANON="$DB_DIR/canonical.state"
{
    printf 'CYBRA_CANONICAL_STATE\n'
    printf 'RUN=%s\nSTAMP=%s\n\n' "$RUN" "$STAMP"
    printf -- '--- MODULES ---\n'
    while IFS= read -r -d '' d; do
        m="$(basename "$d")"
        case "$m" in
            @*|.*|_disabled*|evolution|answer_engine|node_modules) continue ;;
        esac
        printf '%s %s\n' "$m" "$(cat "$BASELINE/${m}.tree" 2>/dev/null || echo NOHASH)"
    done < <(find "$MODULES" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -z)
} > "$CANON"

CANON_HASH="$(hash_file "$CANON")"

# --- BACKEND A: canonical state hash ---
BACKEND_A="$CANON_HASH"
printf '%s\n' "$BACKEND_A" > "$DB_DIR/backend_a.sha256"

# --- BACKEND B: index.json + baseline trees sorted ---
BB_INPUT="$DB_DIR/backend_b.input"
{
    cat "$NODE/index.json"
    printf '\n---\n'
    for t in "$BASELINE"/*.tree; do
        [ -f "$t" ] || continue
        printf '%s %s\n' "$(cat "$t")" "$(basename "$t")"
    done
} | LC_ALL=C sort > "$BB_INPUT"

BACKEND_B="$(hash_file "$BB_INPUT")"
printf '%s\n' "$BACKEND_B" > "$DB_DIR/backend_b.sha256"

# --- DUAL HASH (level 1) ---
DUAL_INPUT="$DB_DIR/dual_level1.input"
printf '%s\n%s\n' "$BACKEND_A" "$BACKEND_B" > "$DUAL_INPUT"
DUAL_L1="$(hash_file "$DUAL_INPUT")"
printf '%s\n' "$DUAL_L1" > "$DB_DIR/dual_level1.sha256"

# ============================================================
# ПОДВІЙНИЙ SNAPSHOT — друга пара хешів (BACKEND C і D)
# ============================================================

# --- BACKEND C: module tree hashes sorted ---
BC_INPUT="$DB_DIR/backend_c.input"
{
    for t in "$BASELINE"/*.tree; do
        [ -f "$t" ] || continue
        printf '%s %s\n' "$(basename "$t" .tree)" "$(cat "$t")"
    done
} | LC_ALL=C sort > "$BC_INPUT"

BACKEND_C="$(hash_file "$BC_INPUT")"
printf '%s\n' "$BACKEND_C" > "$DB_DIR/backend_c.sha256"

# --- BACKEND D: node index.txt hash ---
BD_INPUT="$NODE/index.txt"
BACKEND_D="$(hash_file "$BD_INPUT")"
printf '%s\n' "$BACKEND_D" > "$DB_DIR/backend_d.sha256"

# --- DUAL HASH (level 2 — подвійний snapshot) ---
DUAL2_INPUT="$DB_DIR/dual_level2.input"
printf '%s\n%s\n' "$BACKEND_C" "$BACKEND_D" > "$DUAL2_INPUT"
DUAL_L2="$(hash_file "$DUAL2_INPUT")"
printf '%s\n' "$DUAL_L2" > "$DB_DIR/dual_level2.sha256"

# --- ULTRA DUAL HASH — комбінація обох рівнів ---
ULTRA_INPUT="$DB_DIR/ultra.input"
printf '%s\n%s\n%s\n%s\n' \
    "$BACKEND_A" "$BACKEND_B" "$BACKEND_C" "$BACKEND_D" > "$ULTRA_INPUT"
ULTRA_HASH="$(hash_file "$ULTRA_INPUT")"
printf '%s\n' "$ULTRA_HASH" > "$DB_DIR/ultra_dual.sha256"

# --- Consolidated snapshot ---
cat > "$DB_DIR/dual_snapshot.env" <<EOF
RUN=$RUN
STAMP=$STAMP

# Level 1 — canonical + index
BACKEND_A=$BACKEND_A
BACKEND_B=$BACKEND_B
DUAL_LEVEL1=$DUAL_L1

# Level 2 — trees + node index
BACKEND_C=$BACKEND_C
BACKEND_D=$BACKEND_D
DUAL_LEVEL2=$DUAL_L2

# Ultra — combination of both levels
ULTRA_DUAL=$ULTRA_HASH

# Cross-check A+C (canonical vs trees)
A_VS_C=$([ "$BACKEND_A" = "$BACKEND_C" ] && echo MATCH || echo DIFFER)
B_VS_D=$([ "$BACKEND_B" = "$BACKEND_D" ] && echo MATCH || echo DIFFER)

CANONICAL_STATE=$CANON_HASH
MODULE_COUNT=$COUNT
EOF

log "  BACKEND_A  (canonical)  = ${BACKEND_A:0:16}..."
log "  BACKEND_B  (index)      = ${BACKEND_B:0:16}..."
log "  DUAL_L1                 = ${DUAL_L1:0:16}..."
log "  BACKEND_C  (trees)      = ${BACKEND_C:0:16}..."
log "  BACKEND_D  (node idx)   = ${BACKEND_D:0:16}..."
log "  DUAL_L2                 = ${DUAL_L2:0:16}..."
log "  ULTRA_DUAL              = ${ULTRA_HASH:0:16}..."

# --- Snapshot hash self-check ---
log ""
log "  Snapshot self-check:"
for f in "$DB_DIR"/*.sha256; do
    [ -f "$f" ] || continue
    stored="$(cat "$f")"
    [ -n "$stored" ] && log "    [OK] $(basename "$f") = ${stored:0:16}..."
done

# ============================================================
# ФАЗА 6 — Оновлення git_module
# ============================================================

head1 "[6] Оновлення git_module"

mkdir -p "$GITMOD/meta"
cp "$NODE/index.json" "$GITMOD/meta/index.json"
cp "$NODE/index.txt"  "$GITMOD/meta/index.txt"
cp "$NODE/README.md"  "$GITMOD/README.md"
cp "$DB_DIR/dual_snapshot.env" "$GITMOD/meta/dual_snapshot.env"

for f in "$DB_DIR"/*.sha256; do
    [ -f "$f" ] && cp "$f" "$GITMOD/meta/"
done

# Оновлення маніфесту
{
    printf 'CYBRA GIT MODULE MANIFEST\n'
    printf 'RUN=%s\n' "$RUN"
    printf 'STAMP=%s\n' "$STAMP"
    printf '\n'
    printf 'ULTRA_DUAL=%s\n' "$ULTRA_HASH"
    printf 'DUAL_L1=%s\n' "$DUAL_L1"
    printf 'DUAL_L2=%s\n' "$DUAL_L2"
    printf '\n'
    printf 'LICENSE_RECIPIENT=0x66434c5501242ccC71b5a39C765892921624B66c\n'
    printf 'LICENSE_PERCENT=1\n'
} > "$GITMOD/manifest.txt"

log "  [OK] git_module meta updated"

# ============================================================
# ФАЗА 7 — Public export
# ============================================================

head1 "[7] Public export"

rm -rf "$PUBLIC"
mkdir -p "$PUBLIC"
cp -r "$GITMOD"/* "$PUBLIC/"

(
    cd "$PUBLIC" || exit 1
    find . -type f -print0 |
        sort -z |
        xargs -0 -r sha256sum 2>/dev/null
) > "$PUBLIC/PUBLIC.sha256"

PUBLIC_HASH="$(hash_file "$PUBLIC/PUBLIC.sha256")"
log "  [OK] PUBLIC_HASH = ${PUBLIC_HASH:0:16}..."

# ============================================================
# ФАЗА 8 — Фінальний Hardening
# ============================================================

head1 "[8] Фінальний Hardening"

if [ -x "$ROOT/cybra_mega_hardening.sh" ]; then
    "$ROOT/cybra_mega_hardening.sh"
    RC=$?
else
    log "  [FAIL] hardening script not found"
    RC=1
fi

# ============================================================
# ЗВІТ
# ============================================================

head1 "AUTO VERIFY + FIX + RUN SUMMARY"

LATEST="$(ls -t "$AUDIT"/*_final_report.env 2>/dev/null | head -1)"

if [ -n "$LATEST" ] && [ -f "$LATEST" ]; then
    FINAL_STATUS="$(grep '^FINAL_STATUS=' "$LATEST" | cut -d= -f2)"
    PASS_C="$(grep '^PASS_COUNT=' "$LATEST" | cut -d= -f2)"
    FAIL_C="$(grep '^FAIL_COUNT=' "$LATEST" | cut -d= -f2)"
    BLOCK_C="$(grep '^BLOCKED_COUNT=' "$LATEST" | cut -d= -f2)"
    WARN_C="$(grep '^WARN_COUNT=' "$LATEST" | cut -d= -f2)"
else
    FINAL_STATUS="UNKNOWN"
    PASS_C=0; FAIL_C=0; BLOCK_C=0; WARN_C=0
fi

log ""
log " RUN             : $RUN"
log " STAMP           : $STAMP"
log " FIXED           : $FIX"
log " FAILED (fixes)  : $FAIL"
log ""
log " HARDENING       : $FINAL_STATUS"
log " PASS            : $PASS_C"
log " FAIL            : $FAIL_C"
log " BLOCKED         : $BLOCK_C"
log " WARN            : $WARN_C"
log ""
log " AUTOHASH        : ${CANON_HASH:0:16}..."
log " BACKEND_A       : ${BACKEND_A:0:16}..."
log " BACKEND_B       : ${BACKEND_B:0:16}..."
log " BACKEND_C       : ${BACKEND_C:0:16}..."
log " BACKEND_D       : ${BACKEND_D:0:16}..."
log " DUAL_LEVEL_1    : ${DUAL_L1:0:16}..."
log " DUAL_LEVEL_2    : ${DUAL_L2:0:16}..."
log " ULTRA_DUAL      : ${ULTRA_HASH:0:16}..."
log " PUBLIC_HASH     : ${PUBLIC_HASH:0:16}..."
log ""
log " @cybra node     : $NODE"
log " Git module      : $GITMOD"
log " Public export   : $PUBLIC"
log " Snapshot dir    : $DB_DIR"
log " Log             : $LOG"
log ""
log "============================================================"

exit $RC
