#!/data/data/com.termux/files/usr/bin/bash

set -u

# ============================================================
# CYBRONCYBRA.COM — CYBRA GIT ORACLE GUARD
# Git verification + backup + snapshot + rollback
# ============================================================

ROOT="$HOME/CYBRA"
DOMAIN="cybroncybra.com"
REMOTE="origin"
BRANCH="main"

BASE="$ROOT/runtime/cybroncybra_oracle"
SNAP="$BASE/snapshots"
BACKUP="$BASE/backups"
LOG="$BASE/logs"
STATE="$BASE/state"
LOCK="$BASE/.lock"

mkdir -p "$SNAP" "$BACKUP" "$LOG" "$STATE"

exec 9>"$LOCK"
if ! flock -n 9 2>/dev/null; then
    echo "[ORACLE] another cycle is already running"
    exit 10
fi

cd "$ROOT" || exit 20

TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
RUN="$SNAP/$TIMESTAMP"
mkdir -p "$RUN"

LOGFILE="$LOG/$TIMESTAMP.log"
exec > >(tee -a "$LOGFILE") 2>&1

echo "================================================"
echo " CYBRONCYBRA.COM — GIT ORACLE GUARD"
echo "================================================"
echo "TIME:      $TIMESTAMP"
echo "ROOT:      $ROOT"
echo "DOMAIN:    $DOMAIN"
echo "REMOTE:    $REMOTE"
echo "BRANCH:    $BRANCH"
echo

fail() {
    echo "[ORACLE][FAIL] $1"
    echo "FALSE" > "$STATE/status"
    echo "100" > "$STATE/percent"
    exit 1
}

echo "[1/10] Repository check"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || fail "Not a Git repository"

CURRENT_COMMIT="$(git rev-parse HEAD 2>/dev/null)" \
    || fail "Cannot read current commit"

echo "$CURRENT_COMMIT" > "$RUN/current_commit"

echo "[2/10] Remote verification"

ACTUAL_REMOTE="$(git remote get-url "$REMOTE" 2>/dev/null || true)"

echo "Remote: $ACTUAL_REMOTE"

EXPECTED_HTTPS="https://github.com/Lubnysash1980/CYBRA.git"
EXPECTED_SSH="git@github.com:Lubnysash1980/CYBRA.git"

if [ "$ACTUAL_REMOTE" != "$EXPECTED_SSH" ] &&
   [ "$ACTUAL_REMOTE" != "$EXPECTED_HTTPS" ]; then
    fail "Unexpected Git remote"
fi

echo "$ACTUAL_REMOTE" > "$RUN/remote"

echo "[3/10] Working tree snapshot"

git status --short > "$RUN/status_before.txt"

# IMPORTANT:
# We do NOT modify, stage, commit or push user changes.
# Snapshot is read-only at this stage.

echo "[4/10] Git integrity"

git fsck --no-progress --full > "$RUN/git_fsck.txt" 2>&1 \
    || fail "Git fsck failed"

echo "[5/10] Fetch Oracle"

git fetch --prune "$REMOTE" "$BRANCH" \
    || fail "Git fetch failed"

REMOTE_COMMIT="$(git rev-parse "$REMOTE/$BRANCH" 2>/dev/null)" \
    || fail "Cannot resolve remote branch"

echo "$REMOTE_COMMIT" > "$RUN/remote_commit"

echo
echo "LOCAL : $CURRENT_COMMIT"
echo "REMOTE: $REMOTE_COMMIT"
echo

echo "[6/10] Diff Oracle"

git diff --stat "$CURRENT_COMMIT" "$REMOTE_COMMIT" \
    > "$RUN/diff_stat.txt" 2>&1 || true

git diff --name-status "$CURRENT_COMMIT" "$REMOTE_COMMIT" \
    > "$RUN/diff_name_status.txt" 2>&1 || true

git diff -- "$CURRENT_COMMIT" "$REMOTE_COMMIT" \
    > "$RUN/diff.patch" 2>/dev/null || true

echo "[7/10] SHA-256 manifest"

(
    find . \
        -path './.git' -prune -o \
        -path './runtime/cybroncybra_oracle' -prune -o \
        -type f -print0
) | sort -z | xargs -0 sha256sum > "$RUN/manifest.sha256"

echo "[8/10] Configuration snapshot"

{
    echo "DOMAIN=$DOMAIN"
    echo "REMOTE=$ACTUAL_REMOTE"
    echo "BRANCH=$BRANCH"
    echo "CURRENT_COMMIT=$CURRENT_COMMIT"
    echo "REMOTE_COMMIT=$REMOTE_COMMIT"
    echo "TIME=$TIMESTAMP"
} > "$RUN/metadata.env"

cp package.json "$RUN/package.json" 2>/dev/null || true
cp package-lock.json "$RUN/package-lock.json" 2>/dev/null || true

echo "[9/10] Backup"

BACKUP_FILE="$BACKUP/cybra_$TIMESTAMP.tar.gz"

tar \
    --exclude="./.git" \
    --exclude="./node_modules" \
    --exclude="./runtime/cybroncybra_oracle" \
    -czf "$BACKUP_FILE" \
    . 2>/dev/null \
    || fail "Backup creation failed"

sha256sum "$BACKUP_FILE" > "$BACKUP_FILE.sha256"

echo "$BACKUP_FILE" > "$STATE/latest_backup"
echo "$RUN" > "$STATE/latest_snapshot"

echo "[10/10] Oracle decision"

if [ "$CURRENT_COMMIT" = "$REMOTE_COMMIT" ]; then

    echo "STATUS=UP_TO_DATE" > "$STATE/state.env"
    echo "TRUE" > "$STATE/status"
    echo "100" > "$STATE/percent"

    echo
    echo "[ORACLE] CYBRA is already synchronized."
    echo "[ORACLE] Snapshot: $RUN"
    echo "[ORACLE] Backup:   $BACKUP_FILE"
    echo "[ORACLE] RESULT: TRUE / 100%"
    exit 0

fi

echo "STATUS=UPDATE_AVAILABLE" > "$STATE/state.env"
echo "PENDING" > "$STATE/status"
echo "0" > "$STATE/percent"

echo
echo "================================================"
echo " UPDATE AVAILABLE"
echo "================================================"
echo "LOCAL : $CURRENT_COMMIT"
echo "REMOTE: $REMOTE_COMMIT"
echo
echo "NO AUTOMATIC DEPLOYMENT WAS PERFORMED."
echo
echo "Snapshot:"
echo "$RUN"
echo
echo "Backup:"
echo "$BACKUP_FILE"
echo
echo "[ORACLE] RESULT: FALSE/PENDING"
echo "[ORACLE] Manual approval required before deployment."
echo
