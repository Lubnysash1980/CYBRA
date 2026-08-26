#!/data/data/com.termux/files/usr/bin/bash

set -u

ROOT="$HOME/CYBRA"
DOMAIN="cybroncybra.com"
REMOTE="origin"
BRANCH="main"

BASE="$ROOT/runtime/cybroncybra_oracle"
CONFIG="$BASE/domain.env"
STATE="$BASE/state"
LOG="$BASE/logs"
INTEGRATION="$ROOT/runtime/cybroncybra_integration"

mkdir -p "$BASE" "$STATE" "$LOG" "$INTEGRATION"

cd "$ROOT" || exit 1

TS="$(date -u +%Y%m%dT%H%M%SZ)"
RUN="$INTEGRATION/$TS"
mkdir -p "$RUN"

LOGFILE="$LOG/integrator_$TS.log"
exec > >(tee -a "$LOGFILE") 2>&1

echo "================================================"
echo " CYBRONCYBRA.COM — AUTO GIT + ORACLE + EVO"
echo "================================================"
echo "TIME:   $TS"
echo "ROOT:   $ROOT"
echo "DOMAIN: $DOMAIN"
echo

fail() {
    echo "[FAIL] $1"
    echo "FALSE" > "$STATE/status"
    echo "0" > "$STATE/percent"
    echo "$1" > "$STATE/error"
    exit 1
}

# ============================================================
# 1. DOMAIN
# ============================================================

echo "[1] DOMAIN"

cat > "$CONFIG" <<ENV
CYBRON_DOMAIN=$DOMAIN
CYBRA_DOMAIN=$DOMAIN
DOMAIN=$DOMAIN
CYBRONCYBRA_DOMAIN=$DOMAIN
CYBRONCYBRA_ROOT=$ROOT
CYBRONCYBRA_GIT_REMOTE=$REMOTE
CYBRONCYBRA_GIT_BRANCH=$BRANCH
ENV

export DOMAIN
export CYBRA_DOMAIN="$DOMAIN"
export CYBRON_DOMAIN="$DOMAIN"
export CYBRONCYBRA_DOMAIN="$DOMAIN"
export CYBRONCYBRA_ROOT="$ROOT"

cat > "$ROOT/cybroncybra_domain.env" <<ENV
export DOMAIN="$DOMAIN"
export CYBRA_DOMAIN="$DOMAIN"
export CYBRON_DOMAIN="$DOMAIN"
export CYBRONCYBRA_DOMAIN="$DOMAIN"
export CYBRONCYBRA_ROOT="$ROOT"
ENV

chmod 600 "$ROOT/cybroncybra_domain.env"

# ============================================================
# 2. GIT
# ============================================================

echo "[2] GIT"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || fail "Not a Git repository"

REMOTE_URL="$(git remote get-url "$REMOTE" 2>/dev/null || true)"

[ -n "$REMOTE_URL" ] \
    || fail "Git remote missing"

echo "REMOTE: $REMOTE_URL"

LOCAL_BEFORE="$(git rev-parse HEAD)" \
    || fail "Cannot read local commit"

git status --short > "$RUN/status_before.txt"

# Не затираємо локальну роботу.
if [ -s "$RUN/status_before.txt" ]; then
    echo "[GIT] Local changes detected."
    echo "[GIT] Automatic deployment blocked."
    echo "PENDING" > "$STATE/status"
    echo "0" > "$STATE/percent"
    echo "LOCAL_CHANGES" > "$STATE/error"
    exit 2
fi

# ============================================================
# 3. ORACLE FETCH
# ============================================================

echo "[3] GIT ORACLE FETCH"

git fetch --prune "$REMOTE" "$BRANCH" \
    || fail "Git fetch failed"

LOCAL_BEFORE="$(git rev-parse HEAD)"
REMOTE_COMMIT="$(git rev-parse "$REMOTE/$BRANCH")"

echo "LOCAL : $LOCAL_BEFORE"
echo "REMOTE: $REMOTE_COMMIT"

echo "$LOCAL_BEFORE" > "$RUN/local_before"
echo "$REMOTE_COMMIT" > "$RUN/remote_commit"

# ============================================================
# 4. SNAPSHOT BEFORE CHANGE
# ============================================================

echo "[4] SNAPSHOT"

git status --short > "$RUN/status_snapshot.txt"
git diff --stat > "$RUN/local_diff.txt" 2>&1 || true

# ============================================================
# 5. BACKUP
# ============================================================

echo "[5] BACKUP"

BACKUP_FILE="$BASE/backups/cybra_preupdate_$TS.tar.gz"

tar \
    --exclude="./.git" \
    --exclude="./node_modules" \
    --exclude="./runtime/cybroncybra_oracle" \
    --exclude="./runtime/cybroncybra_integration" \
    -czf "$BACKUP_FILE" \
    . \
    || fail "Backup failed"

sha256sum "$BACKUP_FILE" > "$BACKUP_FILE.sha256"

echo "$BACKUP_FILE" > "$STATE/latest_backup"

echo "BACKUP=$BACKUP_FILE" > "$RUN/backup.env"

# ============================================================
# 6. ORACLE DECISION
# ============================================================

echo "[6] ORACLE DECISION"

if [ "$LOCAL_BEFORE" = "$REMOTE_COMMIT" ]; then

    echo "UP_TO_DATE"

    echo "TRUE" > "$STATE/status"
    echo "100" > "$STATE/percent"

    cat > "$STATE/integration.env" <<ENV
DOMAIN=$DOMAIN
GIT=TRUE
ORACLE=TRUE
AUTO_EVOLUTION=TRUE
UPDATE=NOT_REQUIRED
STATUS=TRUE
TIME=$TS
ENV

    echo "STATUS=TRUE" > "$RUN/result.env"
    echo "LOCAL=$LOCAL_BEFORE" >> "$RUN/result.env"
    echo "REMOTE=$REMOTE_COMMIT" >> "$RUN/result.env"

    ln -sfn "$RUN" "$INTEGRATION/latest"

    echo
    echo "================================================"
    echo " CYBRONCYBRA — ALREADY CURRENT"
    echo "================================================"
    echo "DOMAIN : $DOMAIN"
    echo "COMMIT : $LOCAL_BEFORE"
    echo "RESULT : TRUE / 100%"
    exit 0
fi

# ============================================================
# 7. FAST-FORWARD SAFETY TEST
# ============================================================

echo "[7] FAST-FORWARD TEST"

BASE_CHECK="$(git merge-base "$LOCAL_BEFORE" "$REMOTE_COMMIT")"

if [ "$BASE_CHECK" != "$LOCAL_BEFORE" ]; then

    echo "[ORACLE] Remote is not a fast-forward."
    echo "[ORACLE] Automatic deployment BLOCKED."

    echo "PENDING" > "$STATE/status"
    echo "0" > "$STATE/percent"
    echo "NON_FAST_FORWARD" > "$STATE/error"

    cat > "$RUN/result.env" <<ENV
DOMAIN=$DOMAIN
LOCAL=$LOCAL_BEFORE
REMOTE=$REMOTE_COMMIT
STATUS=PENDING
REASON=NON_FAST_FORWARD
ENV

    ln -sfn "$RUN" "$INTEGRATION/latest"

    exit 3
fi

# ============================================================
# 8. DIFF ORACLE
# ============================================================

echo "[8] DIFF ORACLE"

git diff \
    --stat \
    "$LOCAL_BEFORE" "$REMOTE_COMMIT" \
    > "$RUN/diff_stat.txt" 2>&1 || true

git diff \
    --name-status \
    "$LOCAL_BEFORE" "$REMOTE_COMMIT" \
    > "$RUN/diff_name_status.txt" 2>&1 || true

git diff \
    "$LOCAL_BEFORE" "$REMOTE_COMMIT" \
    > "$RUN/diff.patch" 2>/dev/null || true

# ============================================================
# 9. AUTOMATIC FAST-FORWARD
# ============================================================

echo "[9] AUTO UPDATE"

if ! git merge --ff-only "$REMOTE/$BRANCH"; then

    echo "[GIT] Update failed."
    echo "[GIT] Starting rollback."

    git reset --hard "$LOCAL_BEFORE" \
        || fail "Rollback failed"

    echo "ROLLBACK" > "$STATE/status"
    echo "0" > "$STATE/percent"
    echo "UPDATE_FAILED" > "$STATE/error"

    exit 4
fi

LOCAL_AFTER="$(git rev-parse HEAD)"

echo "UPDATED:"
echo "$LOCAL_BEFORE"
echo "→"
echo "$LOCAL_AFTER"

echo "$LOCAL_AFTER" > "$RUN/local_after"

# ============================================================
# 10. NODE DEPENDENCIES
# ============================================================

echo "[10] NODE CHECK"

if [ -f package-lock.json ]; then

    if ! npm ci --ignore-scripts; then

        echo "[NODE] npm ci failed."
        echo "[ROLLBACK] Restoring Git commit."

        git reset --hard "$LOCAL_BEFORE" \
            || fail "Git rollback failed"

        echo "ROLLBACK" > "$STATE/status"
        echo "0" > "$STATE/percent"
        echo "NPM_CI_FAILED" > "$STATE/error"

        exit 5
    fi

fi

# ============================================================
# 11. AUTO-EVOLUTION
# ============================================================

echo "[11] AUTO-EVOLUTION"

EVO_FOUND=0

for EVO in \
    "$ROOT/cybra_evolution.sh" \
    "$ROOT/cybra_evo.sh" \
    "$ROOT/cybra_evolution_deploy.sh" \
    "$ROOT/cybra_it_evolution.sh" \
    "$ROOT/evolution_engine_v1.sh"
do

    if [ -f "$EVO" ]; then
        EVO_FOUND=1
        chmod +x "$EVO" 2>/dev/null || true
        echo "FOUND: $EVO"
    fi

done

echo "$EVO_FOUND" > "$RUN/auto_evolution"

# ============================================================
# 12. HEALTH CHECK
# ============================================================

echo "[12] HEALTH CHECK"

HEALTH=TRUE

git rev-parse HEAD >/dev/null 2>&1 \
    || HEALTH=FALSE

[ -f package.json ] \
    || HEALTH=FALSE

if [ "$HEALTH" != "TRUE" ]; then

    echo "[HEALTH] FAILED"
    echo "[ROLLBACK] Restoring $LOCAL_BEFORE"

    git reset --hard "$LOCAL_BEFORE" \
        || fail "Critical rollback failure"

    echo "ROLLBACK" > "$STATE/status"
    echo "0" > "$STATE/percent"
    echo "HEALTH_CHECK_FAILED" > "$STATE/error"

    exit 6
fi

# ============================================================
# 13. FINAL TRUE
# ============================================================

echo "[13] FINAL ORACLE"

cat > "$STATE/integration.env" <<ENV
DOMAIN=$DOMAIN
GIT=TRUE
ORACLE=TRUE
AUTO_EVOLUTION=$EVO_FOUND
UPDATE=TRUE
HEALTH_CHECK=TRUE
ROLLBACK_READY=TRUE
LOCAL_BEFORE=$LOCAL_BEFORE
LOCAL_AFTER=$LOCAL_AFTER
STATUS=TRUE
TIME=$TS
ENV

echo "TRUE" > "$STATE/status"
echo "100" > "$STATE/percent"
rm -f "$STATE/error"

cat > "$RUN/result.env" <<ENV
DOMAIN=$DOMAIN
LOCAL_BEFORE=$LOCAL_BEFORE
LOCAL_AFTER=$LOCAL_AFTER
REMOTE=$REMOTE_COMMIT
AUTO_EVOLUTION=$EVO_FOUND
BACKUP=$BACKUP_FILE
HEALTH_CHECK=TRUE
STATUS=TRUE
TIME=$TS
ENV

ln -sfn "$RUN" "$INTEGRATION/latest"

echo
echo "================================================"
echo " CYBRONCYBRA AUTO UPDATE SUCCESS"
echo "================================================"
echo "DOMAIN : $DOMAIN"
echo "BEFORE : $LOCAL_BEFORE"
echo "AFTER  : $LOCAL_AFTER"
echo "REMOTE : $REMOTE_COMMIT"
echo "AUTO-EVO: $EVO_FOUND"
echo "HEALTH : TRUE"
echo "STATUS : TRUE / 100%"
echo
echo "BACKUP:"
echo "$BACKUP_FILE"
echo
echo "SNAPSHOT:"
echo "$RUN"
echo
