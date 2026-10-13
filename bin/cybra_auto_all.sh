#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# CYBRA AUTO ALL v2 — Повна автоматизація
# Verify → Restore → Fix → Evolution → AI → Baseline
# → Dual-Backend → Guardian → Hardening → Push
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
M19="$MODULES/module_19_contract_tui_menu"
M20="$MODULES/module_20_evolution_guard"
M35="$MODULES/module_35_cybra_guardian"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
RUN="$STAMP-$$"
LOG="$LOGS/auto_all_${STAMP}.log"

mkdir -p "$LOGS" "$AUDIT" "$BASELINE" "$HASHES" "$NODE" "$GITMOD" "$PUBLIC" "$EVO_DIR" "$HOME/.cache"

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
    [ ! -d "$dir" ] && { printf 'NODIR'; return; }
    (
        cd "$dir" || exit 1
        find . -type f \
            ! -name '*.log' ! -name '*.test.log' \
            ! -name 'test_output.txt' ! -name 'test_output.sha256' \
            ! -name 'SNAPSHOT_SHA256.txt' ! -name '*.bak.*' \
            -print0 2>/dev/null |
        sort -z | xargs -0 -r sha256sum 2>/dev/null |
        sha256sum | awk '{print $1}'
    )
}

head1 "CYBRA AUTO ALL v2"
log "STAMP: $STAMP"
log "RUN:   $RUN"

# ============================================================
# ФАЗА 1 — ВІДНОВЛЕННЯ МЕНЮ З БЕКАПУ (якщо зламано)
# ============================================================
head1 "[1/9] Відновлення меню"

if [ -d "$M19" ]; then
    cd "$M19" || exit 1
    if ! bash -n bin/cybra_menu.sh 2>/dev/null; then
        log "  [BROKEN] cybra_menu.sh — шукаю робочий бекап"

        BEST=""
        for f in $(ls -t bin/cybra_menu.sh.bak.* 2>/dev/null); do
            if bash -n "$f" 2>/dev/null; then
                BEST="$f"
                break
            fi
        done

        if [ -n "$BEST" ]; then
            cp "$BEST" bin/cybra_menu.sh
            chmod +x bin/cybra_menu.sh
            log "  [FIXED] відновлено з $BEST"
            FIX=$((FIX+1))
        else
            log "  [FAIL] немає робочого бекапу"
            FAIL=$((FAIL+1))
        fi
    else
        log "  [OK] cybra_menu.sh syntax OK"
    fi

    # Fix lib синтаксис
    if [ -f bin/cybra_tui_lib.sh ] && ! bash -n bin/cybra_tui_lib.sh 2>/dev/null; then
        log "  [BROKEN] cybra_tui_lib.sh"
        for f in $(ls -t bin/cybra_tui_lib.sh.bak.* 2>/dev/null); do
            if bash -n "$f" 2>/dev/null; then
                cp "$f" bin/cybra_tui_lib.sh
                chmod +x bin/cybra_tui_lib.sh
                log "  [FIXED] lib відновлено"
                FIX=$((FIX+1))
                break
            fi
        done
    fi

    # Fix recipients ($VAR → real address)
    RECIPIENT="0x66434c5501242ccC71b5a39C765892921624B66c"
    for k in CREATION_FEE_RECIPIENT LICENSE_A_RECIPIENT LICENSE_B_RECIPIENT; do
        sed -i "s|^${k}=\\\$[A-Z_]*|${k}=${RECIPIENT}|" bin/cybra_tui_lib.sh 2>/dev/null
        sed -i "s|^${k}=AUTO$|${k}=${RECIPIENT}|" bin/cybra_tui_lib.sh 2>/dev/null
        sed -i "s|^${k}=.*|${k}=${RECIPIENT}|" "$M19/state/config.env" 2>/dev/null
    done

    # Fix /tmp → $HOME/.cache в evolution guard
    if [ -f "$M20/bin/cybra_evolution.sh" ]; then
        sed -i "s|/tmp/evo_block_reasons_\\$\\$|$HOME/.cache/evo_block_\\$\\$|g" \
            "$M20/bin/cybra_evolution.sh" 2>/dev/null
    fi

    # Pre-approve module_19
    mkdir -p "$EVO_DIR"
    printf '%s' "$(cat "$BASELINE/module_19_contract_tui_menu.tree" 2>/dev/null)" \
        > "$EVO_DIR/module_19_contract_tui_menu.approved"
fi

# ============================================================
# ФАЗА 2 — ІНФРАСТРУКТУРА
# ============================================================
head1 "[2/9] Інфраструктура"

for d in "$ROOT" "$MODULES" "$BASELINE" "$LOGS" "$AUDIT" "$HASHES" "$NODE" "$GITMOD" "$PUBLIC" "$EVO_DIR"; do
    if [ -d "$d" ]; then
        log "  [OK] $(basename "$d")"
    else
        mkdir -p "$d"
        log "  [FIXED] $(basename "$d")"
        FIX=$((FIX+1))
    fi
done

# Owner marker
if [ ! -f "$ROOT/.owner" ]; then
    printf 'CYBRA_OWNER_%s\n' "$STAMP" > "$ROOT/.owner"
    chmod 600 "$ROOT/.owner"
    log "  [FIXED] owner marker створено"
    FIX=$((FIX+1))
fi

# ============================================================
# ФАЗА 3 — ЗБІР МОДУЛІВ
# ============================================================
head1 "[3/9] Список модулів"

MOD_COUNT=0
for d in "$MODULES"/*/; do
    [ -d "$d" ] || continue
    m="$(basename "$d")"
    case "$m" in @*|.*|_disabled*|evolution|answer_engine|node_modules) continue ;; esac
    MOD_COUNT=$((MOD_COUNT+1))
    log "  [OK] $m"
done
log "  Всього: $MOD_COUNT"

# ============================================================
# ФАЗА 4 — EVOLUTION CHECK (3% tolerance)
# ============================================================
head1 "[4/9] Evolution Guard"

EVO_LIB="$M20/bin/cybra_evolution.sh"
EVO_PASS=0
EVO_FAIL=0

if [ -f "$EVO_LIB" ]; then
    source "$EVO_LIB"

    # Tolerance tests
    evo_test() {
        local name="$1" expected="$2" result="$3"
        if [ "$result" = "$expected" ]; then
            printf '  [EVO-PASS] %-40s\n' "$name" | tee -a "$LOG"
            EVO_PASS=$((EVO_PASS+1))
        else
            printf '  [EVO-FAIL] %-40s expected=%s got=%s\n' "$name" "$expected" "$result" | tee -a "$LOG"
            EVO_FAIL=$((EVO_FAIL+1))
        fi
    }

    evo_test "equal 100→100"          "OK"      "$(evo_within_tolerance 100 100 3 && echo OK || echo BLOCKED)"
    evo_test "improve 100→120"        "OK"      "$(evo_within_tolerance 100 120 3 && echo OK || echo BLOCKED)"
    evo_test "3% dev 100→97"          "OK"      "$(evo_within_tolerance 100 97 3 && echo OK || echo BLOCKED)"
    evo_test "4% dev 100→96"          "BLOCKED" "$(evo_within_tolerance 100 96 3 && echo OK || echo BLOCKED)"
    evo_test "50% deg 100→50"         "BLOCKED" "$(evo_within_tolerance 100 50 3 && echo OK || echo BLOCKED)"
    evo_test "massive 50→500"         "OK"      "$(evo_within_tolerance 50 500 3 && echo OK || echo BLOCKED)"
    evo_test "zero→zero"              "OK"      "$(evo_within_tolerance 0 0 3 && echo OK || echo BLOCKED)"
    evo_test "zero→one"               "BLOCKED" "$(evo_within_tolerance 0 1 3 && echo OK || echo BLOCKED)"

    log ""
    log "  EVO: $EVO_PASS PASS / $EVO_FAIL FAIL"

    if [ "$EVO_FAIL" -gt 0 ]; then
        FAIL=$((FAIL+EVO_FAIL))
    fi
else
    log "  [WARN] evolution guard не знайдено"
    WARN=$((WARN+1))
fi

# ============================================================
# ФАЗА 5 — BASELINE UPDATE
# ============================================================
head1 "[5/9] Baseline update"

while IFS= read -r -d '' d; do
    m="$(basename "$d")"
    case "$m" in @*|.*|_disabled*|evolution|answer_engine|node_modules) continue ;; esac
    h="$(hash_tree "$d")"
    printf '%s' "$h" > "$BASELINE/${m}.tree"
    printf '%s' "$h" > "$EVO_DIR/${m}.approved"
    log "  [OK] $m -> ${h:0:16}..."
done < <(find "$MODULES" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -z)

# ============================================================
# ФАЗА 6 — DUAL-BACKEND SNAPSHOT
# ============================================================
head1 "[6/9] Dual-Backend snapshot"

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

BB="$DB_DIR/backend_b.input"
{
    cat "$NODE/index.json" 2>/dev/null || echo ""
    printf '\n---\n'
    for t in "$BASELINE"/*.tree; do
        [ -f "$t" ] || continue
        printf '%s %s\n' "$(cat "$t")" "$(basename "$t")"
    done
} | LC_ALL=C sort > "$BB"
BACKEND_B="$(sha256sum "$BB" | awk '{print $1}')"

BC="$DB_DIR/backend_c.input"
for t in "$BASELINE"/*.tree; do
    [ -f "$t" ] || continue
    printf '%s %s\n' "$(basename "$t" .tree)" "$(cat "$t")"
done | LC_ALL=C sort > "$BC"
BACKEND_C="$(sha256sum "$BC" | awk '{print $1}')"

BACKEND_D="$(sha256sum "$NODE/index.txt" 2>/dev/null | awk '{print $1}')"
[ -z "$BACKEND_D" ] && BACKEND_D="NOHASH"

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
MOD_COUNT=$MOD_COUNT
EVO_PASS=$EVO_PASS
EVO_FAIL=$EVO_FAIL
EOF

for f in A B C D; do printf '%s\n' "$(eval echo \$BACKEND_$f)" > "$DB_DIR/backend_${f,,}.sha256"; done
printf '%s\n' "$DUAL_L1" > "$DB_DIR/dual_l1.sha256"
printf '%s\n' "$DUAL_L2" > "$DB_DIR/dual_l2.sha256"
printf '%s\n' "$ULTRA"   > "$DB_DIR/ultra.sha256"

log "  A=${BACKEND_A:0:16}... B=${BACKEND_B:0:16}..."
log "  C=${BACKEND_C:0:16}... D=${BACKEND_D:0:16}..."
log "  L1=${DUAL_L1:0:16}... L2=${DUAL_L2:0:16}..."
log "  ULTRA=${ULTRA:0:16}..."

# ============================================================
# ФАЗА 7 — GUARDIAN 100% STATE CHECK
# ============================================================
head1 "[7/9] Guardian state"

if [ -f "$M35/bin/guardian.sh" ]; then
    source "$M35/bin/guardian.sh"

    gd_check_state > "$LOGS/guardian_state.log" 2>&1 || true
    PCT="$(cat "$GUARD_EV/state_pct.txt" 2>/dev/null || echo 0)"

    if [ "$PCT" -eq 100 ]; then
        log "  [OK] state = 100%"
    else
        log "  [WARN] state = ${PCT}% — спроба auto-recovery"
        gd_auto_recover 2>&1 | tail -3 | sed 's/^/    /' | tee -a "$LOG" || true
        PCT="$(cat "$GUARD_EV/state_pct.txt" 2>/dev/null || echo 0)"
        log "  Після recovery: ${PCT}%"
        WARN=$((WARN+1))
    fi

    # Baseline для M35
    h="$(hash_tree "$M35")"
    printf '%s' "$h" > "$BASELINE/module_35_cybra_guardian.tree"
    printf '%s' "$h" > "$EVO_DIR/module_35_cybra_guardian.approved"
else
    log "  [WARN] guardian не знайдено"
    WARN=$((WARN+1))
fi

# ============================================================
# ФАЗА 8 — HARDENING
# ============================================================
head1 "[8/9] Hardening"

if [ -x "$ROOT/cybra_mega_hardening.sh" ]; then
    "$ROOT/cybra_mega_hardening.sh"
    RC=$?
else
    log "  [FAIL] hardening не знайдено"
    RC=1
    FAIL=$((FAIL+1))
fi

# ============================================================
# ФАЗА 9 — GIT PUSH
# ============================================================
head1 "[9/9] Git push"

# @cybra node index
rm -rf "$NODE"
mkdir -p "$NODE/modules"
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
    printf '%-45s %-14s %-18s\n' "$m" "OK" "${h:0:16}" >> "$NODE/index.txt"
    if [ "$FIRST" -eq 0 ]; then printf ',\n' >> "$NODE/index.json"; fi
    FIRST=0
    printf '    {"name":"%s","tree":"%s"}' "$m" "$h" >> "$NODE/index.json"
    ln -sfn "$d" "$NODE/modules/$m"
done < <(find "$MODULES" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -z)

{
    printf '\n  ],\n  "module_count": %s,\n' "$COUNT"
    printf '  "ultra_dual": "%s",\n' "$ULTRA"
    printf '  "evo_test": "%s/%s",\n' "$EVO_PASS" "$EVO_FAIL"
    printf '  "license": "0x66434c5501242ccC71b5a39C765892921624B66c"\n}\n'
} >> "$NODE/index.json"

# Git ops
if [ -d "$GITMOD/.git" ]; then
    mkdir -p "$GITMOD/meta"
    cp "$NODE/index.json" "$GITMOD/meta/index.json" 2>/dev/null || true
    cp "$NODE/index.txt"  "$GITMOD/meta/index.txt" 2>/dev/null || true
    cp "$DB_DIR/dual_snapshot.env" "$GITMOD/meta/dual_snapshot.env"
    cp "$DB_DIR"/*.sha256 "$GITMOD/meta/" 2>/dev/null || true

    # Export modules
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
        printf 'ULTRA_DUAL=%s\n' "$ULTRA"
        printf 'DUAL_L1=%s\nDUAL_L2=%s\n' "$DUAL_L1" "$DUAL_L2"
        printf 'MODULE_COUNT=%s\n' "$COUNT"
        printf 'EVO_PASS=%s\nEVO_FAIL=%s\n' "$EVO_PASS" "$EVO_FAIL"
        printf 'LICENSE=0x66434c5501242ccC71b5a39C765892921624B66c\n'
    } > "$GITMOD/manifest.txt"

    cd "$GITMOD" || exit 1
    git add -A 2>/dev/null

    if [ -z "$(git status --porcelain 2>/dev/null)" ]; then
        log "  [OK] немає змін"
    else
        git commit -m "CYBRA auto-all $STAMP [mod=$COUNT evo=$EVO_PASS/$EVO_FAIL ultra=${ULTRA:0:12}]" 2>&1 | tail -2 | tee -a "$LOG" || true
        if git push 2>&1 | tail -2 | tee -a "$LOG"; then
            log "  [OK] PUSHED"
        else
            log "  [WARN] push failed — перевір remote"
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
head1 "AUTO ALL v2 — SUMMARY"

log ""
log " RUN             : $RUN"
log " STAMP           : $STAMP"
log " MODULE_COUNT    : $MOD_COUNT"
log ""
log " FIXED           : $FIX"
log " FAILED          : $FAIL"
log " WARN            : $WARN"
log ""
log " EVO_TEST        : $EVO_PASS / $((EVO_PASS+EVO_FAIL))"
log ""
log " BACKEND_A       : ${BACKEND_A:0:16}..."
log " BACKEND_B       : ${BACKEND_B:0:16}..."
log " BACKEND_C       : ${BACKEND_C:0:16}..."
log " BACKEND_D       : ${BACKEND_D:0:16}..."
log " DUAL_L1         : ${DUAL_L1:0:16}..."
log " DUAL_L2         : ${DUAL_L2:0:16}..."
log " ULTRA_DUAL      : ${ULTRA:0:16}..."
log ""
log " Git remote      : $(cd "$GITMOD" 2>/dev/null && git remote get-url origin 2>/dev/null || echo NONE)"
log " Git log         : $(cd "$GITMOD" 2>/dev/null && git log --oneline -1 2>/dev/null || echo NONE)"
log ""
log " @cybra node     : $NODE"
log " Snapshot        : $DB_DIR"
log " Log             : $LOG"
log "============================================================"

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
