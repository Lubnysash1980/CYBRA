#!/data/data/com.termux/files/usr/bin/bash
set -u

ROOT="$HOME/CYBRA"
DOMAIN="cybroncybra.com"
REMOTE="origin"
BRANCH="main"

BASE="$ROOT/runtime/cybroncybra_integration"
SNAP="$BASE/snapshots"
BACKUP="$BASE/backups"
STATE="$BASE/state"
LOG="$BASE/logs"

mkdir -p "$SNAP" "$BACKUP" "$STATE" "$LOG"

cd "$ROOT" || exit 1

TS="$(date -u +%Y%m%dT%H%M%SZ)"
RUN="$SNAP/$TS"
mkdir -p "$RUN"

exec > >(tee -a "$LOG/$TS.log") 2>&1

echo "================================================"
echo " CYBRONCYBRA.COM — AUTO INTEGRATOR V2"
echo "================================================"
echo "TIME:   $TS"
echo "ROOT:   $ROOT"
echo "DOMAIN: $DOMAIN"
echo

echo "[1] DOMAIN CONFIG"

cat > "$RUN/domain.env" <<DOMAIN_EOF
CYBRA_DOMAIN=$DOMAIN
CYBRA_SITE=https://$DOMAIN
CYBRA_TOKEN_PAGE=https://$DOMAIN/
CYBRA_DOMAIN_ENABLED=1
DOMAIN_EOF

# CNAME is useful when publishing from a branch.
printf '%s\n' "$DOMAIN" > "$ROOT/CNAME"

echo "[2] GIT"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    echo "[GIT] ERROR: not a repository"
    exit 20
}

ACTUAL_REMOTE="$(git remote get-url "$REMOTE" 2>/dev/null || true)"
echo "REMOTE: $ACTUAL_REMOTE"

LOCAL="$(git rev-parse HEAD)"
git fetch --prune "$REMOTE" "$BRANCH"

REMOTE_COMMIT="$(git rev-parse "$REMOTE/$BRANCH")"

echo "LOCAL : $LOCAL"
echo "REMOTE: $REMOTE_COMMIT"

echo "[3] SNAPSHOT"

git status --short > "$RUN/status.txt"
git diff --stat > "$RUN/local_diff_stat.txt" 2>&1 || true

printf '%s\n' "$LOCAL" > "$RUN/local_commit"
printf '%s\n' "$REMOTE_COMMIT" > "$RUN/remote_commit"

echo "[4] BACKUP"

BACKUP_FILE="$BACKUP/cybra_$TS.tar.gz"

tar \
  --exclude="./.git" \
  --exclude="./node_modules" \
  --exclude="./runtime/cybroncybra_integration" \
  -czf "$BACKUP_FILE" \
  .

sha256sum "$BACKUP_FILE" > "$BACKUP_FILE.sha256"

echo "[BACKUP] $BACKUP_FILE"

echo "[5] TOKEN PAGE"

mkdir -p "$ROOT/docs"

cat > "$ROOT/docs/index.html" <<HTML
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>CYBRA Token</title>
<meta name="description" content="Official CYBRA Token website">
<link rel="canonical" href="https://$DOMAIN/">
<style>
body{font-family:system-ui,sans-serif;max-width:900px;margin:auto;padding:40px;line-height:1.6}
.card{border:1px solid #ddd;border-radius:16px;padding:24px;margin:20px 0}
code{word-break:break-all}
</style>
</head>
<body>
<h1>CYBRA Token</h1>

<div class="card">
<h2>Official Website</h2>
<p>CYBRONCYBRA.COM</p>
<p><a href="https://$DOMAIN/">https://$DOMAIN/</a></p>
</div>

<div class="card">
<h2>Token Information</h2>
<p><strong>Project:</strong> CYBRA</p>
<p><strong>Network:</strong> To be verified</p>
<p><strong>Contract:</strong> To be verified</p>
</div>

<div class="card">
<h2>Verification</h2>
<p>This page is the official CYBRA project website.</p>
<p>Contract information will only be published after verification.</p>
</div>
</body>
</html>
HTML

echo "[PAGE] Created docs/index.html"

echo "[6] AUTO-EVO DISCOVERY"

EVO_FOUND=0

for f in \
    ./cybra_evolution.sh \
    ./cybra_evolution.py \
    ./cybra_evo.sh \
    ./bin/cybra-evolution-bin \
    ./evolution_engine_v1.sh
do
    if [ -f "$f" ]; then
        echo "[EVO] FOUND: $f"
        EVO_FOUND=1
    fi
done

echo "[7] DOMAIN INTEGRATION"

mkdir -p "$ROOT/runtime/cybroncybra_integration"

cat > "$ROOT/runtime/cybroncybra_integration/domain.env" <<DOMAIN_EOF
DOMAIN=$DOMAIN
CYBRA_DOMAIN=$DOMAIN
CYBRA_SITE=https://$DOMAIN
CYBRA_TOKEN_PAGE=https://$DOMAIN/
AUTO_EVOLUTION=1
GIT_ORACLE=1
SNAPSHOT=1
BACKUP=1
ROLLBACK=1
DOMAIN_INTEGRATION=1
DOMAIN_EOF

echo "[8] STATE"

if [ "$LOCAL" = "$REMOTE_COMMIT" ]; then
    STATUS="TRUE"
    PERCENT="100"
    ORACLE="UP_TO_DATE"
else
    STATUS="FALSE/PENDING"
    PERCENT="0"
    ORACLE="UPDATE_AVAILABLE"
fi

cat > "$STATE/latest.env" <<STATE_EOF
DOMAIN=$DOMAIN
LOCAL_COMMIT=$LOCAL
REMOTE_COMMIT=$REMOTE_COMMIT
REMOTE_URL=$ACTUAL_REMOTE
ORACLE=$ORACLE
AUTO_EVOLUTION=$EVO_FOUND
STATUS=$STATUS
PERCENT=$PERCENT
TIME=$TS
BACKUP=$BACKUP_FILE
SNAPSHOT=$RUN
STATE_EOF

cp "$STATE/latest.env" "$ROOT/runtime/cybroncybra_integration/latest.env"

echo
echo "================================================"
echo " CYBRONCYBRA INTEGRATION RESULT"
echo "================================================"
cat "$STATE/latest.env"
echo

echo "[9] GIT STATUS"

git status --short | head -100

echo
echo "[10] NEXT"

if [ "$LOCAL" != "$REMOTE_COMMIT" ]; then
    echo "[ORACLE] GitHub has a newer commit."
    echo "[ORACLE] NO destructive reset performed."
    echo "[ORACLE] Snapshot and backup are ready."
    echo "[ORACLE] Existing local changes preserved."
fi

echo
echo "[PAGE] Token page:"
echo "       $ROOT/docs/index.html"
echo
echo "[DOMAIN] https://$DOMAIN/"
echo
echo "================================================"
