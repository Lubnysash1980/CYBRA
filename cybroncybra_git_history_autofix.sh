#!/data/data/com.termux/files/usr/bin/bash

set -u
set -o pipefail

ROOT="$HOME/CYBRA"
TARGET="backup_.tar.gz"
BASE="$ROOT/runtime/cybroncybra_git_history_autofix"
RUN="$BASE/$(date -u +%Y%m%dT%H%M%SZ)"

mkdir -p "$RUN"

cd "$ROOT" || exit 1

exec > >(tee -a "$RUN/run.log") 2>&1

echo "================================================"
echo " CYBRONCYBRA — GIT HISTORY AUTO-FIX"
echo " REMOVE LARGE OBJECT SAFELY"
echo "================================================"
echo "ROOT:   $ROOT"
echo "TARGET: $TARGET"
echo "RUN:    $RUN"
echo

fail() {
    echo
    echo "[AUTO][FAIL] $1"
    printf '%s\n' "$1" > "$RUN/error"
    exit 1
}

echo "[1/12] Repository"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
    fail "Not a Git repository"

BRANCH="$(git branch --show-current)"
HEAD_BEFORE="$(git rev-parse HEAD)"

echo "BRANCH: $BRANCH"
echo "HEAD:   $HEAD_BEFORE"

echo "[2/12] Working tree snapshot"

git status --short > "$RUN/status-before.txt"
git diff > "$RUN/local.diff" || true

echo "[3/12] Verify Token Page"

[ -f "$ROOT/docs/token.html" ] ||
    fail "docs/token.html missing"

sha256sum "$ROOT/docs/token.html" > "$RUN/token-page.sha256"

echo "[4/12] Verify target exists in history"

FOUND="$(
    git rev-list --objects --all |
    awk -v target="$TARGET" '$2 == target {print $1; exit}'
)"

if [ -z "$FOUND" ]; then
    echo "[GIT] Target already absent from history."
    echo "TRUE" > "$RUN/target-already-clean"
    exit 0
fi

echo "TARGET_OBJECT=$FOUND"

SIZE="$(git cat-file -s "$FOUND" 2>/dev/null || echo 0)"

echo "TARGET_SIZE=$SIZE bytes"

if [ "$SIZE" -lt 100000000 ]; then
    echo "[GIT] Target is below GitHub 100 MB limit."
    echo "[GIT] Still removing it because it is generated backup data."
fi

echo "[5/12] Create safety refs"

SAFE_REF="refs/cybra/autofix-before-$(
    date -u +%Y%m%dT%H%M%SZ
)"

git update-ref "$SAFE_REF" "$HEAD_BEFORE" ||
    fail "Could not create safety ref"

echo "$SAFE_REF" > "$RUN/safety-ref"

echo "[SAFE] $SAFE_REF"

echo "[6/12] Create token-page protection copy"

cp "$ROOT/docs/token.html" "$RUN/token.html.before-history-fix" ||
    fail "Could not backup Token Page"

echo "[7/12] Check git-filter-repo"

if command -v git-filter-repo >/dev/null 2>&1; then
    FILTER_MODE="git-filter-repo"
else
    FILTER_MODE="none"
fi

echo "FILTER_MODE=$FILTER_MODE"

if [ "$FILTER_MODE" = "none" ]; then

    echo
    echo "[AUTO] git-filter-repo is not installed."

    if command -v python >/dev/null 2>&1 && \
       python -m git_filter_repo --help >/dev/null 2>&1; then
        FILTER_MODE="python-module"
    fi
fi

if [ "$FILTER_MODE" = "none" ]; then

    echo
    echo "[INSTALL] Installing git-filter-repo..."

    if command -v pip >/dev/null 2>&1; then
        pip install --user git-filter-repo ||
            fail "Не вдалося встановити git-filter-repo"
    else
        python -m pip install --user git-filter-repo ||
            fail "Не вдалося встановити git-filter-repo"
    fi

    if command -v git-filter-repo >/dev/null 2>&1; then
        FILTER_MODE="git-filter-repo"
    elif python -m git_filter_repo --help >/dev/null 2>&1; then
        FILTER_MODE="python-module"
    else
        fail "git-filter-repo недоступний після встановлення"
    fi
fi

echo "FILTER_MODE=$FILTER_MODE"

echo "[8/12] Remove target from ALL Git history"

if [ "$FILTER_MODE" = "git-filter-repo" ]; then

    git filter-repo \
        --force \
        --path "$TARGET" \
        --invert-paths ||
        fail "git-filter-repo failed"

else

    python -m git_filter_repo \
        --force \
        --path "$TARGET" \
        --invert-paths ||
        fail "python git-filter-repo failed"

fi

echo "[9/12] Restore / verify current Token Page"

[ -f "$ROOT/docs/token.html" ] ||
    fail "Token Page disappeared after history rewrite"

sha256sum "$ROOT/docs/token.html" > "$RUN/token-page.after.sha256"

echo "[TOKEN] Token Page preserved."

echo "[10/12] Verify large object removal"

REMAINING="$(
    git rev-list --objects --all |
    awk -v target="$TARGET" '$2 == target {print}'
)"

if [ -n "$REMAINING" ]; then
    echo "$REMAINING"
    fail "backup_.tar.gz still exists in Git history"
fi

echo "[GIT] backup_.tar.gz removed from reachable history."

echo "[11/12] Git garbage collection"

git reflog expire --expire=now --all ||
    true

git gc --prune=now ||
    fail "Git garbage collection failed"

echo "[GIT] GC completed."

echo "[12/12] Final validation"

if git rev-list --objects --all |
   awk '$2 == "backup_.tar.gz" {found=1} END {exit found}'; then
    :
else
    fail "Large backup object still reachable"
fi

git diff --check ||
    fail "Git diff check failed"

HEAD_AFTER="$(git rev-parse HEAD)"

echo
echo "================================================"
echo " CYBRONCYBRA GIT HISTORY — CLEAN"
echo "================================================"
echo
echo "TARGET:       $TARGET"
echo "OLD OBJECT:   $FOUND"
echo "OLD SIZE:     $SIZE bytes"
echo "HEAD BEFORE:  $HEAD_BEFORE"
echo "HEAD AFTER:   $HEAD_AFTER"
echo "BRANCH:       $BRANCH"
echo
echo "TOKEN PAGE:   PRESERVED"
echo "HISTORY:      CLEAN"
echo "DESTRUCTIVE:  NO RESET --HARD"
echo "RUN:          $RUN"
echo
echo "[AUTO] Large generated backup removed from Git history."
echo "[AUTO] Current Token Page preserved."
echo "[AUTO] Safety ref preserved:"
echo "$SAFE_REF"
echo
echo "[NEXT] Verify remote before push."
