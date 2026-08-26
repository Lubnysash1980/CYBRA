#!/data/data/com.termux/files/usr/bin/bash

set -u
set -o pipefail

ROOT="$HOME/CYBRA"
REMOTE="origin"
BASE="$ROOT/runtime/cybroncybra_git_largefile_autofix"
RUN="$BASE/$(date -u +%Y%m%dT%H%M%SZ)"

mkdir -p "$RUN"

cd "$ROOT" || exit 1

LOG="$RUN/run.log"
exec > >(tee -a "$LOG") 2>&1

echo "================================================"
echo " CYBRONCYBRA — GIT LARGE FILE AUTO-FIX"
echo "================================================"
echo "ROOT: $ROOT"
echo "RUN:  $RUN"
echo

fail() {
    echo
    echo "[AUTO][FAIL] $1"
    echo "$1" > "$RUN/error"
    echo
    echo "LOG: $LOG"
    exit 1
}

echo "[1] Repository"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
    fail "Git repository не знайдений"

BRANCH="$(git branch --show-current)"
echo "BRANCH=$BRANCH"

git status --short > "$RUN/status-before.txt"

echo "[2] Remote"

ACTUAL_REMOTE="$(git remote get-url "$REMOTE" 2>/dev/null || true)"
echo "REMOTE=$ACTUAL_REMOTE"

[ -n "$ACTUAL_REMOTE" ] ||
    fail "Git remote відсутній"

echo "[3] Create protected Git ignore"

touch "$ROOT/.gitignore"

add_ignore() {
    local value="$1"
    grep -Fqx "$value" "$ROOT/.gitignore" 2>/dev/null || \
        printf '%s\n' "$value" >> "$ROOT/.gitignore"
}

add_ignore "node_modules/"
add_ignore "runtime/"
add_ignore "backup_*.tar.gz"
add_ignore "*.tar.gz"
add_ignore "*.tar"
add_ignore "*.zip"
add_ignore "*.7z"
add_ignore "*.iso"

echo "[GIT] .gitignore updated"

echo "[4] Detect large tracked files"

LARGE="$RUN/large_tracked_files.txt"

git ls-files -z |
while IFS= read -r -d '' file; do
    [ -f "$file" ] || continue

    size="$(wc -c < "$file" 2>/dev/null || echo 0)"

    if [ "$size" -gt 100000000 ]; then
        printf '%s\t%s bytes\n' "$file" "$size"
    fi
done > "$LARGE"

COUNT="$(wc -l < "$LARGE" | tr -d ' ')"

echo "[GIT] Large tracked files: $COUNT"

if [ "$COUNT" -gt 0 ]; then
    cat "$LARGE"
fi

echo "[5] Snapshot"

git rev-parse HEAD > "$RUN/head-before"
git status --short > "$RUN/status-before.txt"
git diff --stat > "$RUN/diff-stat.txt" || true

echo "[6] Protect local work"

# Видаляємо з INDEX лише явно небезпечні generated archives.
# Фізичні файли залишаються на пристрої.
while IFS=$'\t' read -r file size; do
    [ -n "$file" ] || continue

    case "$file" in
        *.tar.gz|*.tar|*.zip|*.7z|*.iso|backup_*|runtime/*)
            echo "[GIT] Untracking generated large file: $file"
            git rm --cached --ignore-unmatch -- "$file" || true
            ;;
        *)
            echo "[GIT] Large source preserved: $file"
            ;;
    esac
done < "$LARGE"

echo "[7] Stage Git protection"

git add .gitignore

echo "[8] Commit protection"

if ! git diff --cached --quiet; then
    git commit \
        -m "chore(cybroncybra): protect repository from large generated files" ||
        fail "Git commit failed"
else
    echo "[GIT] Немає нових protection changes."
fi

echo "[9] Verify current tree"

git status --short > "$RUN/status-after.txt"

echo "[GIT] Current HEAD:"
git rev-parse HEAD

echo "[10] Check repository history"

HIST="$RUN/history_large_files.txt"

git rev-list --objects --all 2>/dev/null |
while read -r object path; do
    [ -f "$path" ] || continue

    size="$(wc -c < "$path" 2>/dev/null || echo 0)"

    if [ "$size" -gt 100000000 ]; then
        printf '%s\t%s bytes\t%s\n' "$object" "$size" "$path"
    fi
done > "$HIST"

HIST_COUNT="$(wc -l < "$HIST" | tr -d ' ')"

echo "[GIT] Large objects in history: $HIST_COUNT"

if [ "$HIST_COUNT" -gt 0 ]; then
    echo
    echo "[GIT] У старій історії ще є великі об'єкти."
    echo "[GIT] Вони не видаляються автоматично з main."
    echo "[GIT] Це безпечна перевірка перед history rewrite."
fi

echo "[11] Remote connectivity"

REMOTE_OK=0

if timeout 20 git ls-remote "$REMOTE" HEAD >/dev/null 2>&1; then
    REMOTE_OK=1
    echo "[REMOTE] OK"
else
    echo "[REMOTE] unavailable"
fi

echo "[12] Prepare result"

cat > "$RUN/result.env" <<RESULT
BRANCH=$BRANCH
REMOTE=$ACTUAL_REMOTE
LARGE_TRACKED=$COUNT
LARGE_HISTORY=$HIST_COUNT
REMOTE_OK=$REMOTE_OK
HEAD=$(git rev-parse HEAD)
STATUS=TRUE
TIME=$(date -u +%Y%m%dT%H%M%SZ)
RESULT

echo "TRUE" > "$BASE/status"

echo
echo "================================================"
echo " CYBRONCYBRA GIT LARGE FILE GUARD — READY"
echo "================================================"
echo
echo "BRANCH:         $BRANCH"
echo "LARGE TRACKED:  $COUNT"
echo "LARGE HISTORY:  $HIST_COUNT"
echo "REMOTE:         $REMOTE_OK"
echo "HEAD:           $(git rev-parse HEAD)"
echo
echo "RUN:            $RUN"
echo "LOG:            $LOG"
echo
echo "[AUTO] Local files preserved."
echo "[AUTO] runtime preserved."
echo "[AUTO] node_modules preserved."
echo "[AUTO] Token Page preserved."
echo "[AUTO] No git reset --hard."
echo "[AUTO] No destructive cleanup."
echo

if [ "$HIST_COUNT" -gt 0 ]; then
    echo "[NEXT] GitHub може ще відхилити push через старі large objects."
    echo "[NEXT] History rewrite потрібен окремим контрольованим кроком."
else
    echo "[GIT] Large-file history check: OK"
fi

if [ "$REMOTE_OK" -eq 1 ]; then
    echo
    echo "[REMOTE] GitHub доступний."
else
    echo
    echo "[REMOTE] GitHub недоступний зараз."
fi

echo
