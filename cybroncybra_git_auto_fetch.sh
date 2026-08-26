#!/data/data/com.termux/files/usr/bin/bash

set -u

ROOT="$HOME/CYBRA"

cd "$ROOT" || exit 1

if [ -f "$ROOT/config/cybroncybra.env" ]; then
    set -a
    . "$ROOT/config/cybroncybra.env"
    set +a
fi

REMOTE="${CYBRA_GIT_REMOTE:-origin}"
BRANCH="${CYBRA_GIT_BRANCH:-main}"

echo "==============================================="
echo " CYBRONCYBRA.COM — AUTO GIT ORACLE"
echo "==============================================="

echo "DOMAIN: ${CYBRA_DOMAIN:-unknown}"
echo "REMOTE: $REMOTE"
echo "BRANCH: $BRANCH"
echo

git fetch --prune "$REMOTE" "$BRANCH" || {
    echo "[GIT-ORACLE][FAIL] Fetch failed"
    exit 1
}

LOCAL="$(git rev-parse HEAD)"
REMOTE_COMMIT="$(git rev-parse "$REMOTE/$BRANCH")"

echo "LOCAL : $LOCAL"
echo "REMOTE: $REMOTE_COMMIT"

if [ "$LOCAL" = "$REMOTE_COMMIT" ]; then
    echo "STATUS=UP_TO_DATE"
    exit 0
fi

echo "STATUS=UPDATE_AVAILABLE"
echo
echo "[GIT-ORACLE] New version detected."
echo "[GIT-ORACLE] Handing control to CYBRONCYBRA Oracle Guard."

if [ -x "$ROOT/cybroncybra_git_oracle_guard.sh" ]; then
    "$ROOT/cybroncybra_git_oracle_guard.sh"
else
    echo "[GIT-ORACLE][FAIL] Oracle Guard missing."
    exit 2
fi
