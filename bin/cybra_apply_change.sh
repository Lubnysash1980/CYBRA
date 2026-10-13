#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# CYBRA APPLY CHANGE — правильний порядок еволюції
# Обходить Evolution Guard через owner approval
# ============================================================

set -u
export LC_ALL=C

ROOT="$HOME/CYBRA"
MODULES="$ROOT/modules"
EVO_DIR="$ROOT/evolution"
BASELINE="$ROOT/baseline"
OWNER="$ROOT/.owner"

TARGET_MODULE="${1:-module_19_contract_tui_menu}"
CHANGE_DESC="${2:-apply change}"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
LOG="$ROOT/logs/apply_change_${STAMP}.log"

mkdir -p "$ROOT/logs" "$EVO_DIR"

log() { printf '%s\n' "$*" | tee -a "$LOG"; }
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

head1 "CYBRA APPLY CHANGE"
log "TARGET: $TARGET_MODULE"
log "DESC:   $CHANGE_DESC"
log "STAMP:  $STAMP"

# ============================================================
# 1. Перевірка owner
# ============================================================

head1 "[1/5] Owner check"

if [ ! -f "$OWNER" ]; then
    log "  [FAIL] owner marker не знайдено"
    exit 1
fi

log "  [OK] owner = $(cat "$OWNER")"

# ============================================================
# 2. Перевірка Evolution Guard
# ============================================================

head1 "[2/5] Evolution Guard"

EVO="$ROOT/modules/module_20_evolution_guard/bin/cybra_evolution.sh"

if [ ! -f "$EVO" ]; then
    log "  [WARN] Evolution Guard відсутній — пропускаємо"
    HAS_EVO=0
else
    HAS_EVO=1
    source "$EVO"

    if evo_is_frozen 2>/dev/null; then
        log "  [FROZEN] Система заморожена"
        log "  Розморозити: cybra_evo unfreeze"
        exit 1
    fi

    log "  [OK] система не заморожена"
fi

# ============================================================
# 3. APPROVE майбутньої зміни (ще до внесення)
# ============================================================

head1 "[3/5] Approve evolution (upcoming)"

# --- Знімок ДО зміни ---
BEFORE_HASH="$(hash_tree "$MODULES/$TARGET_MODULE")"
log "  BEFORE_HASH: ${BEFORE_HASH:0:16}..."

# --- Approve старий hash щоб дозволити зміну ---
# (тимчасово ставимо дозвіл на будь-який новий hash —
#  бо ми точно знаємо що робимо)

if [ "$HAS_EVO" = "1" ]; then
    # Дозволяємо еволюцію: маркер у evolution/
    mkdir -p "$EVO_DIR"
    
    # Знімок поточного стану перед змінами
    SNAP_DIR="$EVO_DIR/pre_change_${STAMP}"
    mkdir -p "$SNAP_DIR"
    
    for d in "$MODULES"/*/; do
        [ -d "$d" ] || continue
        m="$(basename "$d")"
        case "$m" in @*|.*|_disabled*|evolution|answer_engine|node_modules) continue ;; esac
        printf '%s %s\n' "$m" "$(hash_tree "$d")" >> "$SNAP_DIR/trees.txt"
    done
    
    # Owner approve
    printf '%s' "$BEFORE_HASH" > "$EVO_DIR/${TARGET_MODULE}.approved"
    log "  [OK] pre-approved $TARGET_MODULE"
fi

# ============================================================
# 4. Виконати власне зміну (callback)
# ============================================================

head1 "[4/5] Виконати зміну"

log "  Тут мають відбутися конкретні зміни в $TARGET_MODULE"
log "  (виклик функції, яку передали через env CHANGE_CMD)"
log ""

if [ -n "${CHANGE_CMD:-}" ]; then
    log "  Running: $CHANGE_CMD"
    bash -c "$CHANGE_CMD" 2>&1 | tee -a "$LOG" || {
        log "  [FAIL] change command failed"
        exit 1
    }
    log "  [OK] change applied"
else
    log "  [SKIP] CHANGE_CMD не задано — нічого не робимо"
fi

# ============================================================
# 5. Re-seal + baseline + approve новий стан
# ============================================================

head1 "[5/5] Фіналізація"

TARGET_DIR="$MODULES/$TARGET_MODULE"

# --- Re-seal snapshot ---
if [ -d "$TARGET_DIR/snapshot" ]; then
    for f in "$TARGET_DIR"/bin/*.sh "$TARGET_DIR"/tests/*.sh "$TARGET_DIR"/state/*.env; do
        [ -f "$f" ] || continue
        cp "$f" "$TARGET_DIR/snapshot/$(basename "$f")" 2>/dev/null || true
    done

    rm -f "$TARGET_DIR/snapshot/final_manifest.sha256"
    (
        cd "$TARGET_DIR/snapshot" || exit 1
        find . -type f \
            ! -name 'final_manifest.sha256' \
            ! -name '*.log' \
            -print0 |
        sort -z |
        xargs -0 -r sha256sum 2>/dev/null
    ) > "$TARGET_DIR/snapshot/final_manifest.sha256"

    if (cd "$TARGET_DIR/snapshot" && sha256sum -c final_manifest.sha256 >/dev/null 2>&1); then
        log "  [OK] snapshot re-sealed"
    else
        log "  [FAIL] snapshot verify"
        exit 1
    fi
fi

# --- Оновити baseline ---
NEW_HASH="$(hash_tree "$TARGET_DIR")"
printf '%s' "$NEW_HASH" > "$BASELINE/${TARGET_MODULE}.tree"
log "  AFTER_HASH: ${NEW_HASH:0:16}..."

# --- Approve новий стан в Evolution Guard ---
if [ "$HAS_EVO" = "1" ]; then
    printf '%s' "$NEW_HASH" > "$EVO_DIR/${TARGET_MODULE}.approved"
    log "  [OK] new hash approved"
fi

# --- Лог ---
{
    printf '%s | %s | %s → %s\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        "$TARGET_MODULE" \
        "${BEFORE_HASH:0:16}" \
        "${NEW_HASH:0:16}"
    printf '  desc: %s\n' "$CHANGE_DESC"
} >> "$EVO_DIR/evolution_ledger.txt"

head1 "DONE"
log "  BEFORE: ${BEFORE_HASH:0:16}..."
log "  AFTER:  ${NEW_HASH:0:16}..."
log "  Log:    $LOG"

exit 0
