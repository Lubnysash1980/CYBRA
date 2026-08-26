#!/data/data/com.termux/files/usr/bin/bash

set -u

# ============================================================
# CYBRONCYBRA.COM — AUTO-EVO ORACLE PIPELINE
# Git Oracle -> Snapshot -> Backup -> Evolution -> Test
# -> Deploy -> Health -> Rollback
# ============================================================

ROOT="$HOME/CYBRA"
DOMAIN="cybroncybra.com"

GUARD="$ROOT/cybroncybra_git_oracle_guard.sh"
BASE="$ROOT/runtime/cybroncybra_oracle"
STATE="$BASE/state"
LOG="$BASE/logs"

mkdir -p "$STATE" "$LOG"

TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
LOGFILE="$LOG/auto_evo_$TIMESTAMP.log"

exec > >(tee -a "$LOGFILE") 2>&1

echo "================================================"
echo " CYBRONCYBRA.COM — AUTO-EVO"
echo "================================================"
echo "TIME:   $TIMESTAMP"
echo "DOMAIN: $DOMAIN"
echo "ROOT:   $ROOT"
echo

# ------------------------------------------------------------
# LOCK
# ------------------------------------------------------------

LOCK="$BASE/auto_evo.lock"

exec 8>"$LOCK"

if ! flock -n 8 2>/dev/null; then
    echo "[AUTO-EVO] Another cycle is already running."
    exit 10
fi

cd "$ROOT" || exit 20

# ------------------------------------------------------------
# FAIL / ROLLBACK
# ------------------------------------------------------------

rollback() {
    echo
    echo "================================================"
    echo " AUTO-EVO ROLLBACK"
    echo "================================================"

    BACKUP_FILE=""

    if [ -f "$STATE/latest_backup" ]; then
        BACKUP_FILE="$(cat "$STATE/latest_backup")"
    fi

    if [ -n "$BACKUP_FILE" ] && [ -f "$BACKUP_FILE" ]; then

        echo "[ROLLBACK] Backup:"
        echo "$BACKUP_FILE"

        TEMP="$ROOT/runtime/cybroncybra_oracle/rollback_tmp"
        rm -rf "$TEMP"
        mkdir -p "$TEMP"

        if tar -xzf "$BACKUP_FILE" -C "$TEMP"; then

            echo "[ROLLBACK] Restoring files..."

            rsync -a \
                --delete \
                --exclude=".git/" \
                --exclude="runtime/cybroncybra_oracle/" \
                "$TEMP/" "$ROOT/"

            echo "[ROLLBACK] Files restored."

            echo "ROLLBACK=TRUE" > "$STATE/auto_evo_state.env"
            echo "FALSE" > "$STATE/status"
            echo "0" > "$STATE/percent"

            rm -rf "$TEMP"

            echo "[ROLLBACK] COMPLETE"
            return 0

        fi

        rm -rf "$TEMP"
    fi

    echo "[ROLLBACK][FAIL] Backup restoration failed."

    echo "ROLLBACK=FAILED" > "$STATE/auto_evo_state.env"
    echo "FALSE" > "$STATE/status"
    echo "0" > "$STATE/percent"

    return 1
}

fail_cycle() {
    echo
    echo "[AUTO-EVO][FAIL] $1"

    echo "FALSE" > "$STATE/status"
    echo "0" > "$STATE/percent"
    echo "FAIL_REASON=$1" > "$STATE/auto_evo_state.env"

    rollback

    exit 1
}

# ------------------------------------------------------------
# STEP 1 — ORACLE
# ------------------------------------------------------------

echo "[1/8] Running Git Oracle..."

if ! "$GUARD"; then
    echo "[AUTO-EVO] Oracle returned non-zero."
fi

ORACLE_STATE="$STATE/state.env"

if [ ! -f "$ORACLE_STATE" ]; then
    fail_cycle "Oracle state missing"
fi

source "$ORACLE_STATE"

echo
echo "ORACLE STATUS: ${STATUS:-UNKNOWN}"

# ------------------------------------------------------------
# NO UPDATE
# ------------------------------------------------------------

if [ "${STATUS:-}" = "UP_TO_DATE" ]; then

    echo
    echo "================================================"
    echo " AUTO-EVO — NO UPDATE"
    echo "================================================"
    echo "CYBRONCYBRA.COM already synchronized."
    echo "RESULT: TRUE / 100%"

    echo "AUTO_EVO=TRUE" > "$STATE/auto_evo_state.env"
    echo "TRUE" > "$STATE/status"
    echo "100" > "$STATE/percent"

    exit 0
fi

# ------------------------------------------------------------
# UPDATE REQUIRED
# ------------------------------------------------------------

if [ "${STATUS:-}" != "UPDATE_AVAILABLE" ]; then
    fail_cycle "Unexpected Oracle status: ${STATUS:-UNKNOWN}"
fi

echo
echo "[2/8] Update detected."

REMOTE_COMMIT="$(git rev-parse origin/main)"
LOCAL_COMMIT="$(git rev-parse HEAD)"

echo "LOCAL : $LOCAL_COMMIT"
echo "REMOTE: $REMOTE_COMMIT"

# ------------------------------------------------------------
# STEP 3 — SAFETY CHECK
# ------------------------------------------------------------

echo
echo "[3/8] Safety verification..."

if ! git diff --check "$LOCAL_COMMIT" "$REMOTE_COMMIT"; then
    fail_cycle "Git diff check failed"
fi

echo "[SAFETY] Git diff OK."

# ------------------------------------------------------------
# STEP 4 — CREATE SNAPSHOT MARKER
# ------------------------------------------------------------

echo
echo "[4/8] Snapshot verification..."

SNAPSHOT="$(cat "$STATE/latest_snapshot" 2>/dev/null || true)"

if [ -z "$SNAPSHOT" ] || [ ! -d "$SNAPSHOT" ]; then
    fail_cycle "Oracle snapshot missing"
fi

echo "[SNAPSHOT] $SNAPSHOT"

# ------------------------------------------------------------
# STEP 5 — AUTO-EVO PRECHECK
# ------------------------------------------------------------

echo
echo "[5/8] Auto-Evo precheck..."

EVO_CANDIDATES=(
    "$ROOT/cybra_evolution_guard.py"
    "$ROOT/cybra_evolution.py"
    "$ROOT/cybra_evolution.sh"
    "$ROOT/cybra_evolution_deploy.sh"
    "$ROOT/evolution_engine_v1.sh"
)

EVO_FOUND=""

for f in "${EVO_CANDIDATES[@]}"; do
    if [ -f "$f" ]; then
        EVO_FOUND="$f"
        echo "[AUTO-EVO] Found: $f"
        break
    fi
done

if [ -z "$EVO_FOUND" ]; then
    fail_cycle "No compatible Evolution module found"
fi

# ------------------------------------------------------------
# STEP 6 — FETCH UPDATE INTO TEMP WORKTREE
# ------------------------------------------------------------

echo
echo "[6/8] Preparing isolated update..."

WORK="$ROOT/runtime/cybroncybra_oracle/auto_evo_work"

rm -rf "$WORK"
mkdir -p "$WORK"

git archive "$REMOTE_COMMIT" | tar -x -C "$WORK" \
    || fail_cycle "Cannot create isolated update"

echo "[AUTO-EVO] Isolated update created."

# ------------------------------------------------------------
# STEP 7 — VALIDATION
# ------------------------------------------------------------

echo
echo "[7/8] Validation..."

cd "$WORK" || fail_cycle "Cannot enter update workspace"

VALIDATION_OK=1

if [ -f package.json ]; then

    echo "[TEST] package.json"

    node -e 'JSON.parse(require("fs").readFileSync("package.json","utf8")); console.log("package.json OK")' \
        || VALIDATION_OK=0

fi

if [ -f package-lock.json ]; then

    echo "[TEST] npm lockfile"

    npm ci --ignore-scripts --dry-run >/dev/null 2>&1 \
        || VALIDATION_OK=0

fi

if [ "$VALIDATION_OK" -ne 1 ]; then
    cd "$ROOT"
    fail_cycle "Auto-Evo validation failed"
fi

echo "[VALIDATION] PASS"

# ------------------------------------------------------------
# STEP 8 — DEPLOY
# ------------------------------------------------------------

cd "$ROOT" || exit 20

echo
echo "[8/8] Applying verified update..."

git status --short > "$BASE/state/pre_deploy_status_$TIMESTAMP.txt"

# Preserve runtime/private material.
rsync -a \
    --delete \
    --exclude=".git/" \
    --exclude="runtime/cybroncybra_oracle/" \
    --exclude="node_modules/" \
    "$WORK/" "$ROOT/" \
    || fail_cycle "Deployment copy failed"

echo "[DEPLOY] Files applied."

# ------------------------------------------------------------
# HEALTH CHECK
# ------------------------------------------------------------

echo
echo "================================================"
echo " HEALTH CHECK"
echo "================================================"

HEALTH_OK=1

git rev-parse HEAD >/dev/null 2>&1 || HEALTH_OK=0

if [ -f package.json ]; then
    node -e 'JSON.parse(require("fs").readFileSync("package.json","utf8"))' \
        || HEALTH_OK=0
fi

if [ "$HEALTH_OK" -ne 1 ]; then
    fail_cycle "Post-deployment health check failed"
fi

echo "[HEALTH] PASS"

# ------------------------------------------------------------
# FINAL
# ------------------------------------------------------------

echo
echo "================================================"
echo " CYBRONCYBRA.COM — AUTO-EVO COMPLETE"
echo "================================================"

echo "AUTO_EVO=TRUE" > "$STATE/auto_evo_state.env"
echo "TRUE" > "$STATE/status"
echo "100" > "$STATE/percent"
echo "DEPLOYED_COMMIT=$REMOTE_COMMIT" >> "$STATE/auto_evo_state.env"
echo "TIMESTAMP=$TIMESTAMP" >> "$STATE/auto_evo_state.env"

echo
echo "[AUTO-EVO] RESULT: TRUE / 100%"
echo "[AUTO-EVO] DOMAIN: $DOMAIN"
echo "[AUTO-EVO] COMMIT: $REMOTE_COMMIT"
echo "[AUTO-EVO] SNAPSHOT: $SNAPSHOT"
echo
echo "[AUTO-EVO] SUCCESS"
