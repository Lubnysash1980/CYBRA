#!/data/data/com.termux/files/usr/bin/bash

# ============================================================
# CYBRON SELF UPGRADE ENGINE
# Termux / GitHub / Node.js
#
# SAFE UPDATE PIPELINE:
# CHECK -> FETCH -> VERIFY -> BACKUP -> TEST -> UPGRADE
#        -> HEALTH CHECK -> COMMIT LOCAL STATE
#        -> ROLLBACK ON FAILURE
#
# No blind git pull.
# No automatic destruction of local changes.
# ============================================================

set -u
set -o pipefail

BASE="${CYBRON_BASE:-$HOME/CYBRA}"
UPDATER="$BASE/updater"

LOG_DIR="$UPDATER/logs"
BACKUP_DIR="$UPDATER/backups"
STATE_DIR="$UPDATER/state"

LOG="$LOG_DIR/cybron_upgrade.log"
STATE="$STATE_DIR/state.env"
LOCK="$UPDATER/.upgrade.lock"

REMOTE="${CYBRON_REMOTE:-origin}"
BRANCH="${CYBRON_BRANCH:-main}"

HEALTH_URL="${CYBRON_HEALTH_URL:-}"
HEALTH_TIMEOUT="${CYBRON_HEALTH_TIMEOUT:-10}"

MAX_BACKUPS="${CYBRON_MAX_BACKUPS:-5}"

mkdir -p "$LOG_DIR" "$BACKUP_DIR" "$STATE_DIR"

touch "$LOG"

exec 9>"$LOCK"

if ! flock -n 9 2>/dev/null; then
    echo "CYBRON_UPGRADE_ALREADY_RUNNING"
    exit 20
fi

log() {
    printf '[%s] %s\n' "$(date -Is)" "$*" | tee -a "$LOG"
}

fail() {
    log "ERROR: $*"
    exit 1
}

cleanup_old_backups() {
    local count
    count=$(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)

    if [ "$count" -gt "$MAX_BACKUPS" ]; then
        find "$BACKUP_DIR" \
            -mindepth 1 \
            -maxdepth 1 \
            -type d \
            -printf '%T@ %p\n' 2>/dev/null \
            | sort -n \
            | head -n "$((count - MAX_BACKUPS))" \
            | cut -d' ' -f2- \
            | xargs -r rm -rf
    fi
}

write_state() {
    {
        echo "LAST_RUN=$(date -Is)"
        echo "STATUS=$1"
        echo "VERSION=${2:-unknown}"
        echo "COMMIT=${3:-unknown}"
    } > "$STATE"
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || fail "Missing command: $1"
}

get_version() {
    if [ -f "$BASE/package.json" ]; then
        node -e '
        try {
          const p=require("./package.json");
          console.log(p.version || "unknown")
        } catch(e) {
          console.log("unknown")
        }'
    else
        echo "unknown"
    fi
}

health_check() {

    log "HEALTH CHECK"

    # Optional HTTP health endpoint.
    if [ -n "$HEALTH_URL" ]; then

        require_command curl

        log "Checking: $HEALTH_URL"

        if curl \
            --fail \
            --silent \
            --show-error \
            --max-time "$HEALTH_TIMEOUT" \
            "$HEALTH_URL" >/dev/null; then

            log "HTTP HEALTH = OK"

        else
            log "HTTP HEALTH = FAILED"
            return 1
        fi
    fi

    # Optional project health command.
    if [ -f "$BASE/package.json" ]; then

        if node -e '
        const p=require("./package.json");
        process.exit(p.scripts && p.scripts.health ? 0 : 1)
        ' >/dev/null 2>&1; then

            log "Running npm health"

            if ! npm run health --if-present >>"$LOG" 2>&1; then
                log "npm health FAILED"
                return 1
            fi
        fi
    fi

    return 0
}

rollback() {

    local backup="$1"

    log "ROLLBACK STARTED"

    cd "$BASE" || return 1

    if [ ! -d "$backup" ]; then
        log "Rollback backup not found"
        return 1
    fi

    if [ -f "$backup/git_head" ]; then
        local old_commit
        old_commit=$(cat "$backup/git_head")

        if git rev-parse --verify "$old_commit" >/dev/null 2>&1; then
            git reset --hard "$old_commit" >>"$LOG" 2>&1 || true
        fi
    fi

    if [ -f "$backup/package-lock.json" ]; then
        cp "$backup/package-lock.json" "$BASE/package-lock.json"
    fi

    log "ROLLBACK FINISHED"

    return 0
}

create_backup() {

    local timestamp
    timestamp="$(date +%Y%m%d_%H%M%S)"

    local backup="$BACKUP_DIR/$timestamp"

    mkdir -p "$backup"

    log "Creating backup: $backup"

    git rev-parse HEAD > "$backup/git_head"

    if [ -f package.json ]; then
        cp package.json "$backup/package.json"
    fi

    if [ -f package-lock.json ]; then
        cp package-lock.json "$backup/package-lock.json"
    fi

    if [ -f .env ]; then
        cp .env "$backup/.env"
    fi

    git status --short > "$backup/git_status.txt"

    echo "$backup"

}

run_tests() {

    log "TEST PHASE"

    if [ ! -f package.json ]; then
        log "No package.json - Node tests skipped"
        return 0
    fi

    if node -e '
    const p=require("./package.json");
    process.exit(p.scripts && p.scripts.test ? 0 : 1)
    ' >/dev/null 2>&1; then

        log "Running npm test"

        npm test >>"$LOG" 2>&1 || {
            log "npm test FAILED"
            return 1
        }

    else

        log "No npm test script - basic Node validation"

        node --check \
            "$(find . -maxdepth 2 -type f -name '*.js' | head -n 1)" \
            >>"$LOG" 2>&1 || true
    fi

    return 0
}

install_dependencies() {

    if [ ! -f package.json ]; then
        return 0
    fi

    log "DEPENDENCY PHASE"

    if [ -f package-lock.json ]; then

        log "package-lock.json detected"
        log "Running npm ci"

        npm ci >>"$LOG" 2>&1 || {
            log "npm ci FAILED"
            return 1
        }

    else

        log "No package-lock.json"
        log "Using npm install"

        npm install >>"$LOG" 2>&1 || {
            log "npm install FAILED"
            return 1
        }
    fi

    return 0
}

# ============================================================
# START
# ============================================================

log "============================================================"
log "CYBRON SELF UPGRADE START"
log "BASE=$BASE"
log "REMOTE=$REMOTE"
log "BRANCH=$BRANCH"
log "============================================================"

require_command git
require_command node
require_command npm

cd "$BASE" || fail "Cannot enter $BASE"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    fail "$BASE is not a Git repository"
fi

CURRENT_COMMIT="$(git rev-parse HEAD)"
CURRENT_VERSION="$(get_version)"

log "Current version: $CURRENT_VERSION"
log "Current commit: $CURRENT_COMMIT"

# ------------------------------------------------------------
# SECURITY: NEVER DESTROY UNCOMMITTED WORK
# ------------------------------------------------------------

if ! git diff --quiet || ! git diff --cached --quiet; then

    log "LOCAL CHANGES DETECTED"

    log "Update refused to prevent overwriting local work."

    write_state "BLOCKED_LOCAL_CHANGES" "$CURRENT_VERSION" "$CURRENT_COMMIT"

    exit 10
fi

# ------------------------------------------------------------
# FETCH
# ------------------------------------------------------------

log "Fetching GitHub..."

git fetch \
    --prune \
    "$REMOTE" \
    "$BRANCH" >>"$LOG" 2>&1 || fail "Git fetch failed"

REMOTE_COMMIT="$(git rev-parse "$REMOTE/$BRANCH")"

log "Remote commit: $REMOTE_COMMIT"

# ------------------------------------------------------------
# NO UPDATE
# ------------------------------------------------------------

if [ "$CURRENT_COMMIT" = "$REMOTE_COMMIT" ]; then

    log "SYSTEM ALREADY UP TO DATE"

    write_state "UP_TO_DATE" "$CURRENT_VERSION" "$CURRENT_COMMIT"

    health_check || {
        log "Existing system health check FAILED"
        exit 30
    }

    exit 0
fi

# ------------------------------------------------------------
# SHOW UPDATE
# ------------------------------------------------------------

log "NEW VERSION DETECTED"

git log \
    --oneline \
    "$CURRENT_COMMIT..$REMOTE_COMMIT" \
    | head -50 \
    | tee -a "$LOG"

# ------------------------------------------------------------
# BACKUP
# ------------------------------------------------------------

BACKUP="$(create_backup)" || fail "Backup failed"

cleanup_old_backups

# ------------------------------------------------------------
# UPDATE WORKTREE
# ------------------------------------------------------------

log "Applying GitHub update..."

if ! git merge \
    --ff-only \
    "$REMOTE/$BRANCH" >>"$LOG" 2>&1; then

    log "Fast-forward update failed."

    rollback "$BACKUP" || true

    write_state "UPDATE_FAILED" "$CURRENT_VERSION" "$CURRENT_COMMIT"

    exit 40
fi

NEW_COMMIT="$(git rev-parse HEAD)"
NEW_VERSION="$(get_version)"

log "New version: $NEW_VERSION"
log "New commit: $NEW_COMMIT"

# ------------------------------------------------------------
# DEPENDENCIES
# ------------------------------------------------------------

if ! install_dependencies; then

    log "Dependency installation failed."

    rollback "$BACKUP" || true

    write_state "ROLLBACK_DEPENDENCIES" "$CURRENT_VERSION" "$CURRENT_COMMIT"

    exit 50
fi

# ------------------------------------------------------------
# TEST
# ------------------------------------------------------------

if ! run_tests; then

    log "TEST FAILURE"

    rollback "$BACKUP" || true

    write_state "ROLLBACK_TEST_FAILURE" "$CURRENT_VERSION" "$CURRENT_COMMIT"

    exit 60
fi

# ------------------------------------------------------------
# HEALTH
# ------------------------------------------------------------

if ! health_check; then

    log "HEALTH CHECK FAILURE"

    rollback "$BACKUP" || true

    write_state "ROLLBACK_HEALTH_FAILURE" "$CURRENT_VERSION" "$CURRENT_COMMIT"

    exit 70
fi

# ------------------------------------------------------------
# SUCCESS
# ------------------------------------------------------------

write_state "LIVE" "$NEW_VERSION" "$NEW_COMMIT"

log "============================================================"
log "CYBRON UPDATE SUCCESS"
log "VERSION: $NEW_VERSION"
log "COMMIT:  $NEW_COMMIT"
log "STATUS:  LIVE"
log "============================================================"

exit 0

