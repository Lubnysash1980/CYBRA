#!/data/data/com.termux/files/usr/bin/bash

ROOT="$HOME/CYBRA"
CONFIG="$ROOT/config/cybroncybra.env"

if [ ! -f "$CONFIG" ]; then
    echo "[DOMAIN][FAIL] Missing $CONFIG"
    return 1 2>/dev/null || exit 1
fi

set -a
. "$CONFIG"
set +a

export CYBRA_DOMAIN
export DOMAIN
export CYBRONCYBRA_DOMAIN
export CYBRA_GIT_REMOTE
export CYBRA_GIT_BRANCH
export CYBRA_GIT_REPOSITORY
export CYBRA_ORACLE_ENABLED
export CYBRA_AUTO_DOMAIN
export CYBRA_AUTO_SNAPSHOT
export CYBRA_AUTO_BACKUP
export CYBRA_AUTO_ROLLBACK
export CYBRA_AUTO_EVO

export CYBRA_DOMAIN_URL="https://${CYBRA_DOMAIN}"
export CYBRA_WWW_URL="https://www.${CYBRA_DOMAIN}"
export CYBRA_API_URL="https://api.${CYBRA_DOMAIN}"
export CYBRA_NODE_URL="https://node.${CYBRA_DOMAIN}"

echo "[DOMAIN] $CYBRA_DOMAIN"
echo "[DOMAIN] $CYBRA_DOMAIN_URL"
