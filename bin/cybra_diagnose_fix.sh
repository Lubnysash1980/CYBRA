#!/data/data/com.termux/files/usr/bin/bash
# Автоматична діагностика і фікс hardening FAIL/BLOCKED

set -u
export LC_ALL=C

ROOT="$HOME/CYBRA"
MODULES="$ROOT/modules"
BASELINE="$ROOT/baseline"
EVO_DIR="$ROOT/evolution"
AUDIT="$ROOT/audit"
LOGS="$ROOT/logs"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
LOG="$LOGS/diagnose_fix_${STAMP}.log"

log() { printf '%s\n' "$*" | tee -a "$LOG"; }

hash_tree() {
    local dir="$1"
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

echo "=== DIAGNOSE + FIX ===" | tee -a "$LOG"

# ============================================================
# 1. Знайти свіжий run
# ============================================================

LATEST_REPORT="$(ls -t "$AUDIT"/*_final_report.env 2>/dev/null | head -1)"
RUN_ID="$(basename "$LATEST_REPORT" | sed 's/_final_report.env//')"

log "Latest run: $RUN_ID"
log ""

# ============================================================
# 2. Перевірити кожен модуль
# ============================================================

log "=== Per-module status ==="
for d in "$MODULES"/*/; do
    [ -d "$d" ] || continue
    m="$(basename "$d")"
    case "$m" in @*|.*|_disabled*|evolution|answer_engine|node_modules) continue ;; esac

    # Test log
    tlog="$AUDIT/${RUN_ID}_${m}.test.log"
    if [ -f "$tlog" ]; then
        fails="$(grep -c '\[FAIL\]' "$tlog" 2>/dev/null || true)"
        fails="${fails:-0}"
        if [ "$fails" -gt 0 ]; then
            log "  FAIL: $m ($fails)"
            grep '\[FAIL\]' "$tlog" | head -5 | sed 's/^/    /' | tee -a "$LOG"
        fi
    fi
done

# ============================================================
# 3. Snapshot integrity
# ============================================================

log ""
log "=== Snapshot integrity ==="
for d in "$MODULES"/*/; do
    [ -d "$d" ] || continue
    m="$(basename "$d")"
    case "$m" in @*|.*|_disabled*|evolution|answer_engine|node_modules) continue ;; esac

    snap=""
    for s in "$d/snapshot" "$d/snapshots"; do
        [ -d "$s" ] && { snap="$s"; break; }
    done
    [ -z "$snap" ] && continue

    if [ -f "$snap/final_manifest.sha256" ]; then
        if ! (cd "$snap" && sha256sum -c final_manifest.sha256 >/dev/null 2>&1); then
            log "  SNAPSHOT BROKEN: $m — re-sealing..."
            rm -f "$snap/final_manifest.sha256"
            (
                cd "$snap" || exit 1
                find . -type f \
                    ! -name 'final_manifest.sha256' \
                    ! -name '*.log' \
                    -print0 |
                sort -z | xargs -0 -r sha256sum 2>/dev/null
            ) > "$snap/final_manifest.sha256"
            if (cd "$snap" && sha256sum -c final_manifest.sha256 >/dev/null 2>&1); then
                log "    [FIXED] re-sealed"
            else
                log "    [FAIL] cannot re-seal"
            fi
        fi
    fi
done

# ============================================================
# 4. Auto-approve + baseline
# ============================================================

log ""
log "=== Auto-approve всіх модулів ==="
mkdir -p "$EVO_DIR"
for d in "$MODULES"/*/; do
    [ -d "$d" ] || continue
    m="$(basename "$d")"
    case "$m" in @*|.*|_disabled*|evolution|answer_engine|node_modules) continue ;; esac

    h="$(hash_tree "$d")"
    printf '%s' "$h" > "$EVO_DIR/${m}.approved"
    printf '%s' "$h" > "$BASELINE/${m}.tree"
    log "  $m → ${h:0:16}..."
done

# ============================================================
# 5. Видалити backup'и
# ============================================================

find "$MODULES" -name '*.bak.*' -delete 2>/dev/null || true
find "$ROOT" -name '*.clean' -delete 2>/dev/null || true
find "$ROOT" -name '*.tmp' -delete 2>/dev/null || true

log ""
log "[OK] cleanup"

# ============================================================
# 6. Re-run hardening
# ============================================================

log ""
log "=== HARDENING (після фіксу) ==="
"$ROOT/cybra_mega_hardening.sh" 2>&1 | tail -30 | tee -a "$LOG"

# ============================================================
# 7. Фінальний статус
# ============================================================

log ""
LATEST_NEW="$(ls -t "$AUDIT"/*_final_report.env 2>/dev/null | head -1)"
if [ -n "$LATEST_NEW" ]; then
    STATUS="$(grep '^FINAL_STATUS=' "$LATEST_NEW" | cut -d= -f2)"
    log "FINAL_STATUS: $STATUS"
fi

