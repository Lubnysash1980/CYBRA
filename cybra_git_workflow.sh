#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

CYBRA="${HOME}/CYBRA"
cd "$CYBRA"

BACKEND="gitcybrahash_double_backend.py"
SNAPSHOT="cybra_snapshot.py"
NODE="gitcybrahash_node.js"
SNAPSHOT_JSON="snapshots/cybra_snapshot.json"

EXPECTED_LINES=1697
EXPECTED_SHA="04fd51d8e87088fe638deb1611ab8ae477cf8c4b464e0eb253886ac8aea31e19"

TARGETS=(
  "$BACKEND"
  "$SNAPSHOT"
  "$NODE"
  "$SNAPSHOT_JSON"
)

echo "============================================================"
echo " CYBRA — SAFE GIT WORKFLOW"
echo " CHECK → FIX → CHANGE → COMMIT → WORKFLOW"
echo "============================================================"

fail() {
    echo
    echo "[FAIL] $1"
    exit 1
}

echo
echo "=== 1. ROOT ==="
test "$PWD" = "$CYBRA" || fail "Не в ~/CYBRA"

echo
echo "=== 2. ABORT STALE CHERRY-PICK ==="
if git rev-parse --verify CHERRY_PICK_HEAD >/dev/null 2>&1; then
    echo "[WARN] Старий cherry-pick знайдений."
    git cherry-pick --abort || fail "Не вдалося скасувати старий cherry-pick."
    echo "[OK] Stale cherry-pick aborted."
else
    echo "[OK] No active cherry-pick."
fi

echo
echo "=== 3. CURRENT GIT ==="
BRANCH="$(git branch --show-current)"
HEAD="$(git rev-parse HEAD)"
REMOTE="$(git rev-parse origin/main 2>/dev/null || true)"

echo "BRANCH=$BRANCH"
echo "HEAD=$HEAD"
echo "ORIGIN_MAIN=${REMOTE:-UNAVAILABLE}"

test "$BRANCH" = "main" || fail "Поточна гілка не main."

echo
echo "=== 4. BACKUP BRANCH ==="
BACKUP_BRANCH="backup-before-cybra-workflow-$(date -u +%Y%m%dT%H%M%SZ)"

if git branch "$BACKUP_BRANCH"; then
    echo "[OK] Backup branch: $BACKUP_BRANCH"
else
    fail "Не вдалося створити backup branch."
fi

echo
echo "=== 5. BACKEND INTEGRITY ==="

test -f "$BACKEND" || fail "$BACKEND відсутній."

LINES="$(wc -l < "$BACKEND")"
SHA="$(sha256sum "$BACKEND" | awk '{print $1}')"

echo "LINES=$LINES"
echo "SHA=$SHA"

test "$LINES" -eq "$EXPECTED_LINES" \
    || fail "Backend не 1697 рядків."

test "$SHA" = "$EXPECTED_SHA" \
    || fail "SHA backend не збігається з підтвердженою повною версією."

echo "[OK] Full 1697-line backend confirmed."

echo
echo "=== 6. SYNTAX ==="

python3 -m py_compile \
    "$BACKEND" \
    "$SNAPSHOT" \
    || fail "Python syntax failed."

node --check "$NODE" \
    || fail "Node syntax failed."

echo "[OK] Python + Node syntax."

echo
echo "=== 7. SNAPSHOT ==="

test -f "$SNAPSHOT_JSON" || fail "Snapshot JSON відсутній."

python3 "$SNAPSHOT" verify \
    || fail "Snapshot verification failed."

echo "[OK] Snapshot verified."

echo
echo "=== 8. TARGET FILES ONLY ==="

for f in "${TARGETS[@]}"; do
    test -e "$f" || fail "Target missing: $f"
    echo "[OK] $f"
done

echo
echo "=== 9. UNRELATED CHANGES ==="

git status --short | while IFS= read -r line; do
    path="${line:3}"

    case "$path" in
        "$BACKEND"|"$SNAPSHOT"|"$NODE"|"$SNAPSHOT_JSON")
            ;;
        *)
            [ -z "$path" ] || echo "[PRESERVED] $path"
            ;;
    esac
done

echo
echo "=== 10. STAGE TARGETS ONLY ==="

git reset >/dev/null

git add \
    "$BACKEND" \
    "$SNAPSHOT" \
    "$NODE" \
    "$SNAPSHOT_JSON"

echo
echo "=== STAGED ==="
git status --short

echo
echo "=== STAGED CHECK ==="
git diff --cached --check \
    || fail "Staged diff check failed."

echo
echo "=== 11. COMMIT ==="

if git diff --cached --quiet; then
    echo "[INFO] Немає нових змін для commit."
else
    git commit -m "Add CYBRA snapshot state and Node bridge"
    echo "[OK] Main code commit created."
fi

echo
echo "=== 12. WORKFLOW COMMIT ==="

WORKFLOW_FILE="cybra_git_workflow.sh"

git add "$WORKFLOW_FILE"

if git diff --cached --quiet; then
    echo "[INFO] Workflow вже закомічений."
else
    git commit -m "Add CYBRA safe Git workflow"
    echo "[OK] Workflow commit created."
fi

echo
echo "=== 13. FINAL TEST ==="

python3 "$BACKEND" --test \
    || fail "Final backend self-test failed."

node "$NODE" --test \
    || fail "Final Node/backend self-test failed."

python3 "$SNAPSHOT" verify \
    || fail "Final snapshot verification failed."

echo
echo "============================================================"
echo " CYBRA GIT WORKFLOW COMPLETE"
echo "============================================================"

echo
echo "HEAD:"
git log -3 --oneline

echo
echo "BACKUP:"
echo "$BACKUP_BRANCH"

echo
echo "STATUS:"
git status --short

echo
echo "[IMPORTANT] Push НЕ виконувався."
echo "[IMPORTANT] Force-push НЕ виконувався."
echo "[IMPORTANT] Незв'язані файли НЕ додавалися."
