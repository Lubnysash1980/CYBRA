#!/data/data/com.termux/files/usr/bin/bash

set -u

ROOT="$HOME/CYBRA"
DOMAIN="cybroncybra.com"
REMOTE="origin"
BASE="$ROOT/runtime/cybroncybra_hash_migration"
TIME="$(date -u +%Y%m%dT%H%M%SZ)"
RUN="$BASE/$TIME"
MANIFEST="$RUN/cybra_runtime_sha256.txt"
STATE="$BASE/state"
BRANCH="cybroncybra/hash-state-$TIME"

mkdir -p "$RUN" "$STATE"

cd "$ROOT" || exit 1

echo "================================================"
echo " CYBRONCYBRA.COM — HASH GIT MIGRATION AUTOFIX"
echo "================================================"
echo "TIME:   $TIME"
echo "ROOT:   $ROOT"
echo "DOMAIN: $DOMAIN"
echo

fail() {
    echo
    echo "[AUTO][FAIL] $1"
    echo "FALSE" > "$STATE/status" 2>/dev/null || true
    exit 1
}

echo "[1/10] Disk check"

df -h "$HOME"

AVAIL_KB="$(df -Pk "$HOME" | awk 'NR==2 {print $4}')"

if [ -z "$AVAIL_KB" ]; then
    fail "Cannot determine free space"
fi

echo "Available: ${AVAIL_KB} KB"

echo
echo "[2/10] Git check"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || fail "Not a Git repository"

LOCAL_HEAD="$(git rev-parse HEAD)" \
    || fail "Cannot read HEAD"

echo "HEAD: $LOCAL_HEAD"

ACTUAL_REMOTE="$(git remote get-url "$REMOTE" 2>/dev/null || true)"

echo "REMOTE: $ACTUAL_REMOTE"

[ "$ACTUAL_REMOTE" = "git@github.com:Lubnysash1980/CYBRA.git" ] \
    || fail "Unexpected Git remote"

echo
echo "[3/10] Create migration branch"

git show-ref --verify --quiet "refs/heads/$BRANCH" 2>/dev/null \
    && fail "Generated branch already exists"

git switch -c "$BRANCH" \
    || fail "Cannot create migration branch"

echo "$BRANCH" > "$STATE/branch"

echo
echo "[4/10] Create hash registry"

cat > "$RUN/metadata.env" <<META
DOMAIN=$DOMAIN
TIME=$TIME
LOCAL_HEAD=$LOCAL_HEAD
REMOTE=$ACTUAL_REMOTE
BRANCH=$BRANCH
META

echo "Generating SHA-256 manifest..."

: > "$MANIFEST"

find runtime \
    -type f \
    -not -path 'runtime/cybroncybra_hash_migration/*' \
    -print0 2>/dev/null |
while IFS= read -r -d '' FILE; do
    sha256sum "$FILE" >> "$MANIFEST" 2>/dev/null || true
done

if [ ! -s "$MANIFEST" ]; then
    echo "No runtime files found."
fi

MANIFEST_SHA="$(sha256sum "$MANIFEST" | awk '{print $1}')"

echo "$MANIFEST_SHA" > "$RUN/manifest.sha256"

echo "MANIFEST SHA256: $MANIFEST_SHA"

echo
echo "[5/10] Register domain"

mkdir -p docs

cat > "$RUN/domain.env" <<DOMAIN
CYBRON_DOMAIN=$DOMAIN
TOKEN_PAGE=/docs/token.html
OFFICIAL_EMAIL=official@$DOMAIN
SUPPORT_EMAIL=support@$DOMAIN
ADMIN_EMAIL=admin@$DOMAIN
DOMAIN

echo
echo "[6/10] Register CYBRA token page"

if [ -f docs/token.html ]; then
    sha256sum docs/token.html > "$RUN/token_page.sha256"
    echo "Token page found: docs/token.html"
else
    echo "Token page not found — preserved as missing-state."
    echo "MISSING docs/token.html" > "$RUN/token_page.sha256"
fi

echo
echo "[7/10] Register important CYBRA scripts"

{
    echo "# CYBRONCYBRA important files"
    echo

    for FILE in \
        cybroncybra_git_oracle_guard.sh \
        cybroncybra_auto_integrator.sh \
        cybroncybra_token_autofix.sh \
        cybroncybra_autopilot.sh \
        cybra_evolution.sh \
        cybra_evolution.py \
        github_autonomous_cycle.sh \
        cybra_github_autonomy.py
    do
        if [ -f "$FILE" ]; then
            sha256sum "$FILE"
        fi
    done
} > "$RUN/cybra_scripts.sha256"

echo
echo "[8/10] Git commit — HASH REGISTRY ONLY"

git add "$RUN"

git add docs/token.html 2>/dev/null || true

git add cybroncybra_git_oracle_guard.sh \
        cybroncybra_auto_integrator.sh \
        cybroncybra_token_autofix.sh \
        cybroncybra_autopilot.sh \
        cybra_evolution.sh \
        cybra_evolution.py \
        github_autonomous_cycle.sh \
        cybra_github_autonomy.py 2>/dev/null || true

if git diff --cached --quiet; then
    echo "[GIT] Nothing new to commit."
else
    git commit -m "cybroncybra: hash state and autonomous recovery registry" \
        || fail "Git commit failed"
fi

echo
echo "[9/10] Push HASH registry to GitHub"

git push -u "$REMOTE" "$BRANCH" \
    || fail "Git push failed"

REMOTE_HEAD="$(git ls-remote "$REMOTE" "refs/heads/$BRANCH" 2>/dev/null | awk '{print $1}')"

[ -n "$REMOTE_HEAD" ] \
    || fail "Remote branch verification failed"

echo "REMOTE HASH: $REMOTE_HEAD"

echo "$REMOTE_HEAD" > "$STATE/remote_hash"

echo
echo "[10/10] Cleanup large local runtime data"

echo
echo "The hash registry is now on GitHub."
echo "Local runtime can now be cleaned."

echo

# Remove only generated runtime state.
# .git and source code are NEVER touched.

for DIR in \
    runtime/backup \
    runtime/cybroncybra_autopilot \
    runtime/cybroncybra_auto \
    runtime/cybroncybra_oracle \
    runtime/cybroncybra_autofix \
    runtime/cybroncybra_integration
do
    if [ -d "$DIR" ]; then
        echo "[CLEAN] $DIR"
        rm -rf "$DIR"
    fi
done

sync

echo "TRUE" > "$STATE/status"

echo
echo "================================================"
echo " MIGRATION COMPLETE"
echo "================================================"

echo "DOMAIN:       $DOMAIN"
echo "LOCAL HEAD:   $LOCAL_HEAD"
echo "GIT BRANCH:   $BRANCH"
echo "REMOTE HASH:  $REMOTE_HEAD"
echo "MANIFEST:     $MANIFEST_SHA"

echo
echo "=== FREE SPACE AFTER ==="
df -h "$HOME"

echo
echo "[CYBRONCYBRA] Git hash registry: TRUE"
echo "[CYBRONCYBRA] Runtime cleanup:   TRUE"
echo "[CYBRONCYBRA] .git preserved:    TRUE"
echo "[CYBRONCYBRA] Source preserved:  TRUE"
echo
