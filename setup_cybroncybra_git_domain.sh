#!/data/data/com.termux/files/usr/bin/bash

set -u

ROOT="$HOME/CYBRA"
DOMAIN="cybroncybra.com"
REMOTE="origin"
BRANCH="main"

mkdir -p "$ROOT/config" \
         "$ROOT/runtime/cybroncybra_oracle/domain" \
         "$ROOT/runtime/cybroncybra_oracle/logs"

cd "$ROOT" || exit 1

echo "================================================"
echo " CYBRONCYBRA.COM — GIT + AUTO DOMAIN SETUP"
echo "================================================"
echo "ROOT:   $ROOT"
echo "DOMAIN: $DOMAIN"
echo

# ------------------------------------------------
# 1. CENTRAL DOMAIN CONFIG
# ------------------------------------------------

cat > "$ROOT/config/cybroncybra.env" <<ENV
CYBRA_DOMAIN=cybroncybra.com
DOMAIN=cybroncybra.com
CYBRONCYBRA_DOMAIN=cybroncybra.com

CYBRA_GIT_REMOTE=origin
CYBRA_GIT_BRANCH=main

CYBRA_GIT_REPOSITORY=git@github.com:Lubnysash1980/CYBRA.git

CYBRA_ORACLE_ENABLED=true
CYBRA_AUTO_DOMAIN=true
CYBRA_AUTO_SNAPSHOT=true
CYBRA_AUTO_BACKUP=true
CYBRA_AUTO_ROLLBACK=true
CYBRA_AUTO_EVO=true
ENV

chmod 600 "$ROOT/config/cybroncybra.env"

# ------------------------------------------------
# 2. DOMAIN LOADER
# ------------------------------------------------

cat > "$ROOT/cybroncybra_domain.sh" <<'DOMAIN_EOF'
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
DOMAIN_EOF

chmod +x "$ROOT/cybroncybra_domain.sh"

# ------------------------------------------------
# 3. DOMAIN STATE
# ------------------------------------------------

cat > "$ROOT/runtime/cybroncybra_oracle/domain/current.env" <<ENV
DOMAIN=$DOMAIN
DOMAIN_URL=https://$DOMAIN
WWW_URL=https://www.$DOMAIN
API_URL=https://api.$DOMAIN
NODE_URL=https://node.$DOMAIN
UPDATED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
ENV

# ------------------------------------------------
# 4. GIT VERIFICATION
# ------------------------------------------------

echo "[GIT] Checking repository..."

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "[GIT][FAIL] Not a Git repository."
    exit 2
fi

CURRENT_REMOTE="$(git remote get-url "$REMOTE" 2>/dev/null || true)"

if [ "$CURRENT_REMOTE" != "git@github.com:Lubnysash1980/CYBRA.git" ]; then
    echo "[GIT] Setting origin..."
    git remote set-url "$REMOTE" \
        "git@github.com:Lubnysash1980/CYBRA.git"
fi

git branch --set-upstream-to="$REMOTE/$BRANCH" "$BRANCH" 2>/dev/null || true

echo "[GIT] Remote:"
git remote -v

echo
echo "[GIT] Branch:"
git branch --show-current

# ------------------------------------------------
# 5. DOMAIN-AWARE GIT ENVIRONMENT
# ------------------------------------------------

cat > "$ROOT/.cybroncybra_env" <<ENV
# CYBRONCYBRA.COM runtime environment
# Generated automatically.

export CYBRA_DOMAIN="cybroncybra.com"
export DOMAIN="cybroncybra.com"
export CYBRONCYBRA_DOMAIN="cybroncybra.com"

export CYBRA_GIT_REMOTE="origin"
export CYBRA_GIT_BRANCH="main"
export CYBRA_GIT_REPOSITORY="git@github.com:Lubnysash1980/CYBRA.git"

export CYBRA_DOMAIN_URL="https://cybroncybra.com"
export CYBRA_WWW_URL="https://www.cybroncybra.com"
export CYBRA_API_URL="https://api.cybroncybra.com"
export CYBRA_NODE_URL="https://node.cybroncybra.com"
ENV

chmod 600 "$ROOT/.cybroncybra_env"

# ------------------------------------------------
# 6. AUTO DOMAIN WRAPPER
# ------------------------------------------------

cat > "$ROOT/bin/cybroncybra-env" <<'ENV_EOF'
#!/data/data/com.termux/files/usr/bin/bash

ROOT="$HOME/CYBRA"

if [ ! -f "$ROOT/config/cybroncybra.env" ]; then
    echo "[CYBRONCYBRA][FAIL] Domain config missing."
    exit 1
fi

set -a
. "$ROOT/config/cybroncybra.env"
set +a

export DOMAIN
export CYBRA_DOMAIN
export CYBRONCYBRA_DOMAIN

export CYBRA_DOMAIN_URL="https://${DOMAIN}"
export CYBRA_WWW_URL="https://www.${DOMAIN}"
export CYBRA_API_URL="https://api.${DOMAIN}"
export CYBRA_NODE_URL="https://node.${DOMAIN}"

echo "CYBRA_DOMAIN=$CYBRA_DOMAIN"
echo "DOMAIN=$DOMAIN"
echo "CYBRA_DOMAIN_URL=$CYBRA_DOMAIN_URL"
echo "CYBRA_WWW_URL=$CYBRA_WWW_URL"
echo "CYBRA_API_URL=$CYBRA_API_URL"
echo "CYBRA_NODE_URL=$CYBRA_NODE_URL"
ENV_EOF

chmod +x "$ROOT/bin/cybroncybra-env"

# ------------------------------------------------
# 7. AUTO GIT ORACLE FETCH
# ------------------------------------------------

cat > "$ROOT/cybroncybra_git_auto_fetch.sh" <<'FETCH_EOF'
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
FETCH_EOF

chmod +x "$ROOT/cybroncybra_git_auto_fetch.sh"

# ------------------------------------------------
# 8. DOMAIN DISCOVERY FOR EXISTING SCRIPTS
# ------------------------------------------------

cat > "$ROOT/runtime/cybroncybra_oracle/domain/domain_discovery.txt" <<EOF
CYBRONCYBRA DOMAIN
==================

Primary:
$DOMAIN

HTTPS:
https://$DOMAIN

WWW:
https://www.$DOMAIN

API:
https://api.$DOMAIN

NODE:
https://node.$DOMAIN

Git:
git@github.com:Lubnysash1980/CYBRA.git

Branch:
$BRANCH

Oracle:
ENABLED

Snapshot:
ENABLED

Backup:
ENABLED

Rollback:
ENABLED

Auto-Evo:
ENABLED
