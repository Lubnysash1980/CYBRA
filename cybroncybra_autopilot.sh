#!/data/data/com.termux/files/usr/bin/bash

set -u
set -o pipefail

ROOT="$HOME/CYBRA"
DOMAIN="cybroncybra.com"
REMOTE="origin"
BRANCH="main"

BASE="$ROOT/runtime/cybroncybra_autopilot"
RUN="$BASE/$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP="$RUN/backup"
SNAPSHOT="$RUN/snapshot"
LOG="$RUN/run.log"
STATE="$BASE/state"

mkdir -p "$BACKUP" "$SNAPSHOT" "$STATE"
cd "$ROOT" || exit 20

exec > >(tee -a "$LOG") 2>&1

echo "================================================"
echo " CYBRONCYBRA.COM — AUTOPILOT"
echo "================================================"
echo "ROOT:   $ROOT"
echo "DOMAIN: $DOMAIN"
echo "REMOTE: $REMOTE"
echo "BRANCH: $BRANCH"
echo "RUN:    $RUN"
echo

die() {
    echo
    echo "[AUTO][FAIL] $1"
    echo "FALSE" > "$STATE/status"
    echo "$1" > "$STATE/error"
    error_pause
    exit 1
}

error_pause() {
    echo
    echo "------------------------------------------------"
    echo "[ERROR-PAUSE]"
    echo "Причина записана:"
    echo "$LOG"
    echo "------------------------------------------------"
    echo
    echo "Можна:"
    echo "  1 = повторити"
    echo "  2 = показати останні помилки"
    echo "  3 = вставити команду/підказку з clipboard"
    echo "  4 = продовжити"
    echo "  q = вихід"
    echo

    read -r -p "Вибір: " action

    case "$action" in
        1)
            return 0
            ;;
        2)
            tail -80 "$LOG"
            error_pause
            ;;
        3)
            if command -v termux-clipboard-get >/dev/null 2>&1; then
                echo
                echo "[CLIPBOARD]"
                timeout 5 termux-clipboard-get 2>/dev/null || true
                echo
            else
                echo "[CLIPBOARD] Termux:API недоступний."
                echo "Встанови: pkg install termux-api"
            fi
            error_pause
            ;;
        4)
            return 0
            ;;
        q|Q)
            exit 2
            ;;
        *)
            error_pause
            ;;
    esac
}

run_checked() {
    local description="$1"
    shift

    echo
    echo "[RUN] $description"
    echo "+ $*"

    "$@" 2>&1 || {
        echo "[AUTO][ERROR] $description"
        error_pause
        return 1
    }

    return 0
}

echo "[1/12] Repository"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || die "CYBRA не є Git repository"

echo "[2/12] Remote"

ACTUAL_REMOTE="$(git remote get-url "$REMOTE" 2>/dev/null || true)"

echo "REMOTE: $ACTUAL_REMOTE"

if [ "$ACTUAL_REMOTE" != "git@github.com:Lubnysash1980/CYBRA.git" ] &&
   [ "$ACTUAL_REMOTE" != "https://github.com/Lubnysash1980/CYBRA.git" ]; then
    die "Неправильний Git remote"
fi

echo "[3/12] Backup"

tar \
    --exclude=".git" \
    --exclude="node_modules" \
    --exclude="runtime/cybroncybra_autopilot" \
    -czf "$BACKUP/project.tar.gz" \
    . \
    || die "Backup failed"

sha256sum "$BACKUP/project.tar.gz" > "$BACKUP/project.tar.gz.sha256"

echo "[4/12] Snapshot"

git status --short > "$SNAPSHOT/status.txt"
git diff > "$SNAPSHOT/local.diff" || true
git rev-parse HEAD > "$SNAPSHOT/head"

echo "[5/12] SSH / Git Oracle"

ssh_ok=0

if timeout 12 ssh \
    -o BatchMode=yes \
    -o ConnectTimeout=8 \
    -T git@github.com 2>&1 |
    grep -qiE "successfully authenticated|shell access is not provided"; then
    ssh_ok=1
fi

if [ "$ssh_ok" -eq 0 ]; then

    echo
    echo "[SSH] GitHub SSH authentication не пройшла."
    echo

    if [ -f "$HOME/.ssh/id_ed25519_github" ]; then
        echo "[SSH] Знайдено:"
        echo "$HOME/.ssh/id_ed25519_github"
        echo

        chmod 600 "$HOME/.ssh/id_ed25519_github"

        export GIT_SSH_COMMAND="ssh -i $HOME/.ssh/id_ed25519_github -o IdentitiesOnly=yes -o ConnectTimeout=10"

        if timeout 15 ssh \
            -o BatchMode=yes \
            -o ConnectTimeout=10 \
            -i "$HOME/.ssh/id_ed25519_github" \
            -o IdentitiesOnly=yes \
            -T git@github.com 2>&1 |
            grep -qiE "successfully authenticated|shell access is not provided"; then
            ssh_ok=1
        fi
    fi
fi

if [ "$ssh_ok" -eq 0 ]; then
    echo
    echo "SSH не налаштований."
    echo
    echo "Безпечно підтримуються два варіанти:"
    echo
    echo "A) вказати шлях до приватного ключа"
    echo "B) повернутися після ручного встановлення ключа"
    echo

    read -r -p "Шлях до SSH private key (Enter = пропустити): " KEY_PATH

    if [ -n "$KEY_PATH" ] && [ -f "$KEY_PATH" ]; then

        chmod 600 "$KEY_PATH"

        export GIT_SSH_COMMAND="ssh -i $KEY_PATH -o IdentitiesOnly=yes -o ConnectTimeout=10"

        echo "[SSH] Перевірка ключа..."

        if timeout 15 ssh \
            -o BatchMode=yes \
            -o ConnectTimeout=10 \
            -i "$KEY_PATH" \
            -o IdentitiesOnly=yes \
            -T git@github.com 2>&1 |
            grep -qiE "successfully authenticated|shell access is not provided"; then
            ssh_ok=1
            echo "[SSH] OK"
        else
            echo "[SSH] Ключ не пройшов GitHub authentication."
            error_pause
        fi
    fi
fi

echo "[6/12] Git fetch"

FETCH_OK=0

if git fetch --prune "$REMOTE" "$BRANCH"; then
    FETCH_OK=1
fi

if [ "$FETCH_OK" -eq 0 ]; then
    echo
    echo "[ORACLE] Git fetch failed."
    echo "[ORACLE] Local changes НЕ видаляються."
    echo "[ORACLE] Backup уже створений."
    echo

    error_pause

    git fetch --prune "$REMOTE" "$BRANCH" \
        || die "Git fetch повторно failed"
fi

LOCAL="$(git rev-parse HEAD)"
REMOTE_COMMIT="$(git rev-parse "$REMOTE/$BRANCH")"

echo
echo "LOCAL : $LOCAL"
echo "REMOTE: $REMOTE_COMMIT"

echo "[7/12] Diff Oracle"

git diff --stat "$LOCAL" "$REMOTE_COMMIT" \
    > "$SNAPSHOT/diff.stat" 2>&1 || true

git diff --name-status "$LOCAL" "$REMOTE_COMMIT" \
    > "$SNAPSHOT/diff.name-status" 2>&1 || true

echo "[8/12] Domain"

DOMAIN_FILE="$ROOT/.cybroncybra-domain"

cat > "$DOMAIN_FILE" <<DOMAIN
CYBRONCYBRA_DOMAIN=$DOMAIN
CYBRONCYBRA_URL=https://$DOMAIN
CYBRONCYBRA_TOKEN_PAGE=https://$DOMAIN/token.html
DOMAIN

echo "$DOMAIN" > "$STATE/domain"

echo "[9/12] Auto Evolution"

EVO=0

for evo in \
    "./cybra_evolution.sh" \
    "./cybra_evo.sh" \
    "./cybra_evolution.py" \
    "./cybra_it_evolution.sh"
do
    if [ -f "$evo" ]; then
        echo "[EVO] Found $evo"
        EVO=1
        break
    fi
done

echo "$EVO" > "$STATE/evolution"

echo "[10/12] Git branch"

BRANCH_NAME="autopilot/cybroncybra-$(date -u +%Y%m%d-%H%M%S)"

git switch -c "$BRANCH_NAME" 2>/dev/null \
    || git checkout -b "$BRANCH_NAME" \
    || die "Не вдалося створити automation branch"

echo "$BRANCH_NAME" > "$STATE/branch"

echo "[11/12] Stage safe integration"

git add \
    .cybroncybra-domain \
    2>/dev/null || true

git status --short > "$SNAPSHOT/status-after.txt"

if git diff --cached --quiet; then
    echo "[GIT] Немає нових змін для commit."
else
    git commit \
        -m "chore(cybroncybra): automated domain oracle integration" \
        || die "Git commit failed"
fi

echo "[12/12] Final state"

cat > "$RUN/result.env" <<RESULT
DOMAIN=$DOMAIN
LOCAL_COMMIT=$LOCAL
REMOTE_COMMIT=$REMOTE_COMMIT
BRANCH=$BRANCH_NAME
AUTO_EVOLUTION=$EVO
BACKUP=$BACKUP/project.tar.gz
SNAPSHOT=$SNAPSHOT
STATUS=TRUE
TIME=$(date -u +%Y%m%dT%H%M%SZ)
RESULT

echo "TRUE" > "$STATE/status"

echo
echo "================================================"
echo " CYBRONCYBRA AUTOPILOT READY"
echo "================================================"
echo
echo "DOMAIN:   https://$DOMAIN"
echo "BRANCH:   $BRANCH_NAME"
echo "EVO:      $EVO"
echo "BACKUP:   $BACKUP/project.tar.gz"
echo "SNAPSHOT: $SNAPSHOT"
echo
echo "[AUTO] Local changes preserved."
echo "[AUTO] No destructive reset performed."
echo "[AUTO] SSH private key was not written to logs."
echo "[AUTO] Clipboard content is NEVER executed automatically."
echo
echo "[NEXT] Якщо GitHub SSH працює:"
echo
echo "git push -u origin \"$BRANCH_NAME\""
echo
