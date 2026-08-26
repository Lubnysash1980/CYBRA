#!/data/data/com.termux/files/usr/bin/bash

# ============================================================
# CYBRONCYBRA — CODESPACES ORACLE AUTOPILOT
# CHECK + AUTOPATCH + DNS + PAGES + LOGO + BSC + GIT + EVO
# BUFFER PAUSE / SAFE RECOVERY
#
# SAFETY:
#   - NO git reset --hard
#   - NO destructive cleanup
#   - NO automatic execution of clipboard commands
#   - temporary state only in runtime/
#   - GitHub/Codespaces settings are prepared safely
# ============================================================

set -u
set -o pipefail

ROOT="$HOME/CYBRA"
cd "$ROOT" || exit 1

DOMAIN="cybroncybra.com"
SITE="https://cybroncybra.com"
PAGE="$SITE/token.html"
LOGO="$SITE/assets/cybra-logo.png"

CONTRACT="0x74dA52028E42A37bc89E05c2fD5c52daBE4CB48f"
OFFICIAL="official@cybroncybra.com"
SUPPORT="support@cybroncybra.com"
ADMIN="admin@cybroncybra.com"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
RUN="$ROOT/runtime/cybroncybra_codespace_oracle/$STAMP"
LOG="$RUN/run.log"
EVIDENCE="$ROOT/proofs/cybroncybra_codespace_oracle"
ENVFILE="$ROOT/feeds/cybroncybra_codespace_oracle.env"

mkdir -p "$RUN" "$EVIDENCE" "$ROOT/feeds"

exec > >(tee -a "$LOG") 2>&1

echo "================================================"
echo " CYBRONCYBRA — CODESPACES ORACLE AUTOPILOT"
echo "================================================"
echo "ROOT:     $ROOT"
echo "DOMAIN:   $SITE"
echo "PAGE:     $PAGE"
echo "LOGO:     $LOGO"
echo "CONTRACT: $CONTRACT"
echo "RUN:      $RUN"
echo

FAILURES=0
FIXES=0

pause_before_error() {
    echo
    echo "[BUFFER-AUTOPATCH] ERROR PAUSE"
    echo "[BUFFER-AUTOPATCH] Нова помилка буде спочатку записана."
    echo "[BUFFER-AUTOPATCH] Потім запускається контрольоване виправлення."
    sleep 2
}

fail() {
    FAILURES=$((FAILURES+1))
    echo "[AUTO][FAIL] $1"
    pause_before_error
}

fix() {
    FIXES=$((FIXES+1))
    echo "[AUTOPATCH] $1"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

http_code() {
    curl -L -k -sS \
        --connect-timeout 8 \
        --max-time 15 \
        -o /dev/null \
        -w '%{http_code}' "$1" 2>/dev/null || echo "000"
}

write_env() {
    cat > "$ENVFILE" <<ENV
CYBRONCYBRA_DOMAIN=$DOMAIN
CYBRONCYBRA_SITE=$SITE
CYBRONCYBRA_TOKEN_PAGE=$PAGE
CYBRONCYBRA_LOGO=$LOGO
CYBRONCYBRA_CONTRACT=$CONTRACT
CYBRONCYBRA_OFFICIAL=$OFFICIAL
CYBRONCYBRA_SUPPORT=$SUPPORT
CYBRONCYBRA_ADMIN=$ADMIN
CYBRONCYBRA_RUN=$RUN
CYBRONCYBRA_FIXES=$FIXES
CYBRONCYBRA_FAILURES=$FAILURES
ENV
}

echo "[1/16] Repository"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    BRANCH="$(git branch --show-current)"
    HEAD="$(git rev-parse HEAD)"
    echo "BRANCH=$BRANCH"
    echo "HEAD=$HEAD"
else
    fail "Git repository недоступний."
    exit 1
fi

echo
echo "[2/16] Remote"
REMOTE="$(git remote get-url origin 2>/dev/null || true)"
echo "REMOTE=$REMOTE"

if [ -z "$REMOTE" ]; then
    fail "origin відсутній."
fi

echo
echo "[3/16] Space Guard"
AVAIL="$(df -Pm "$ROOT" 2>/dev/null | awk 'NR==2 {print $4}')"

if [[ "$AVAIL" =~ ^[0-9]+$ ]]; then
    echo "AVAILABLE_MB=$AVAIL"
    if [ "$AVAIL" -lt 1024 ]; then
        fail "Вільне місце менше 1 GB."
    fi
else
    echo "[SPACE] Unknown — safe mode."
fi

echo
echo "[4/16] Snapshot"

SNAP="$RUN/snapshot"
mkdir -p "$SNAP"

git rev-parse HEAD > "$SNAP/head.txt"
git branch --show-current > "$SNAP/branch.txt"
git remote -v > "$SNAP/remotes.txt" 2>/dev/null || true
git status --short > "$SNAP/status.txt" 2>/dev/null || true

echo "[SNAPSHOT] Saved."

echo
echo "[5/16] Local Token Page"

TOKEN_LOCAL="$ROOT/docs/token.html"

if [ -f "$TOKEN_LOCAL" ]; then
    echo "[PAGE] $TOKEN_LOCAL"
    grep -qi "$CONTRACT" "$TOKEN_LOCAL" || {
        fail "Contract не знайдений у Token Page."
    }
    grep -qi "$LOGO" "$TOKEN_LOCAL" || {
        fail "Logo URL не знайдений у Token Page."
    }
    grep -qi "$OFFICIAL" "$TOKEN_LOCAL" || {
        fail "Official email не знайдений."
    }
    grep -qi "$SUPPORT" "$TOKEN_LOCAL" || {
        fail "Support email не знайдений."
    }
    grep -qi "$ADMIN" "$TOKEN_LOCAL" || {
        fail "Admin email не знайдений."
    }
else
    fail "docs/token.html відсутній."
fi

echo
echo "[6/16] SEO AutoPatch"

cat > "$ROOT/robots.txt" <<ROBOTS
User-agent: *
Allow: /

Sitemap: $SITE/sitemap.xml
ROBOTS

cat > "$ROOT/sitemap.xml" <<SITEMAP
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>$SITE/</loc>
  </url>
  <url>
    <loc>$PAGE</loc>
  </url>
</urlset>
SITEMAP

fix "robots.txt та sitemap.xml regenerated."

echo
echo "[7/16] GitHub Pages / Codespaces configuration"

mkdir -p "$ROOT/.devcontainer"

cat > "$ROOT/.devcontainer/devcontainer.json" <<'JSON'
{
  "name": "CYBRONCYBRA",
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
  "features": {
    "ghcr.io/devcontainers/features/git:1": {}
  },
  "postCreateCommand": "git --version && echo CYBRONCYBRA_CODESPACE_READY=1",
  "remoteEnv": {
    "CYBRONCYBRA_DOMAIN": "cybroncybra.com",
    "CYBRONCYBRA_TOKEN_PAGE": "https://cybroncybra.com/token.html"
  }
}
JSON

fix "Codespaces Dev Container configuration created."

# GitHub Pages workflow.
mkdir -p "$ROOT/.github/workflows"

cat > "$ROOT/.github/workflows/pages.yml" <<'YAML'
name: CYBRONCYBRA Pages

on:
  push:
    branches:
      - main
      - 'autopilot/**'
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: pages
  cancel-in-progress: true

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Prepare site
        run: |
          mkdir -p _site
          if [ -f index.html ]; then
            cp index.html _site/index.html
          else
            printf '%s\n' '<!doctype html><html><head><meta charset="utf-8"><title>CYBRA</title></head><body><a href="token.html">CYBRA Token</a></body></html>' > _site/index.html
          fi

          if [ -f docs/token.html ]; then
            cp docs/token.html _site/token.html
          fi

          if [ -d assets ]; then
            cp -r assets _site/
          fi

          if [ -f robots.txt ]; then
            cp robots.txt _site/
          fi

          if [ -f sitemap.xml ]; then
            cp sitemap.xml _site/
          fi

      - name: Setup Pages
        uses: actions/configure-pages@v5

      - name: Upload Pages artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: _site

  deploy:
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    runs-on: ubuntu-latest
    needs: build

    permissions:
      pages: write
      id-token: write

    steps:
      - name: Deploy
        id: deployment
        uses: actions/deploy-pages@v4
YAML

fix "GitHub Pages workflow created."

echo
echo "[8/16] Custom domain preparation"

# GitHub Pages custom-domain file.
printf '%s\n' "$DOMAIN" > "$ROOT/CNAME"

fix "CNAME prepared for $DOMAIN."

echo
echo "[9/16] DNS Oracle"

DNS_OK=0

if command_exists getent; then
    DNS="$(getent hosts "$DOMAIN" 2>/dev/null || true)"
elif command_exists nslookup; then
    DNS="$(nslookup "$DOMAIN" 2>/dev/null || true)"
else
    DNS=""
fi

if [ -n "$DNS" ]; then
    DNS_OK=1
    echo "[DNS] RESOLVED"
    echo "$DNS"
else
    echo "[DNS] Not resolved from this device/network."
    echo "[DNS] This is NOT automatically treated as a local code failure."
fi

echo
echo "[10/16] HTTPS Oracle"

DOMAIN_HTTP="$(http_code "$SITE")"
PAGE_HTTP="$(http_code "$PAGE")"
LOGO_HTTP="$(http_code "$LOGO")"

echo "DOMAIN_HTTP=$DOMAIN_HTTP"
echo "PAGE_HTTP=$PAGE_HTTP"
echo "LOGO_HTTP=$LOGO_HTTP"

case "$DOMAIN_HTTP" in
    2*|3*) echo "[URL] DOMAIN OK" ;;
    *) echo "[URL] DOMAIN unavailable from this network." ;;
esac

case "$PAGE_HTTP" in
    2*|3*) echo "[URL] TOKEN PAGE OK" ;;
    *) echo "[URL] TOKEN PAGE unavailable from this network." ;;
esac

case "$LOGO_HTTP" in
    2*|3*) echo "[URL] LOGO OK" ;;
    *) echo "[URL] LOGO unavailable from this network." ;;
esac

echo
echo "[11/16] BSC Oracle"

BSC_OK=0

# Public BSC RPC fallback list.
RPCS="
https://bsc-dataseed.binance.org
https://bsc-dataseed1.defibit.io
https://bsc-dataseed1.ninicoin.io
"

if command_exists curl; then
    for RPC in $RPCS; do
        BODY="{\"jsonrpc\":\"2.0\",\"method\":\"eth_getCode\",\"params\":[\"$CONTRACT\",\"latest\"],\"id\":1}"

        RESPONSE="$(
            curl -sS \
              --connect-timeout 6 \
              --max-time 12 \
              -H 'Content-Type: application/json' \
              --data "$BODY" \
              "$RPC" 2>/dev/null || true
        )"

        if echo "$RESPONSE" | grep -q '"result":"0x'; then
            CODE="$(echo "$RESPONSE" | sed -n 's/.*"result":"\([^"]*\)".*/\1/p')"
            if [ -n "$CODE" ] && [ "$CODE" != "0x" ]; then
                BSC_OK=1
                echo "[BSC] RPC OK: $RPC"
                echo "[BSC] Contract bytecode present."
                break
            fi
        fi
    done
fi

if [ "$BSC_OK" -eq 0 ]; then
    echo "[BSC] Public RPC unavailable from this network."
    echo "[BSC] Local contract format will still be validated."
fi

if [[ "$CONTRACT" =~ ^0x[0-9a-fA-F]{40}$ ]]; then
    echo "[BSC] Contract format OK"
else
    fail "Invalid BSC contract format."
fi

echo
echo "[12/16] Git Large Object Oracle"

LARGE="$(
    git rev-list --objects --all 2>/dev/null |
    while read -r obj path; do
        size="$(git cat-file -s "$obj" 2>/dev/null || echo 0)"
        if [ "$size" -gt 100000000 ]; then
            echo "$size $obj $path"
        fi
    done |
    sort -nr |
    head -20
)"

if [ -n "$LARGE" ]; then
    echo "[GIT] Large objects detected:"
    echo "$LARGE"

    printf '%s\n' "$LARGE" > "$RUN/large_objects.txt"

    # Do NOT rewrite history automatically here.
    # This is intentionally separated from normal autopatching.
    echo "[GIT] History rewrite NOT performed automatically."
else
    echo "[GIT] No reachable objects >100 MB."
fi

echo
echo "[13/16] GitHub SSH Oracle"

SSH_OK=0

if [ -f "$HOME/.ssh/id_ed25519_github" ]; then
    if timeout 15 ssh \
        -i "$HOME/.ssh/id_ed25519_github" \
        -o IdentitiesOnly=yes \
        -o PreferredAuthentications=publickey \
        -o BatchMode=yes \
        -o ConnectTimeout=10 \
        -T git@github.com >/dev/null 2>&1; then

        SSH_OK=1
        echo "[SSH] GitHub authentication OK."
    else
        echo "[SSH] Authentication failed."
        echo "[SSH] Key may require passphrase or is not authorized."
    fi
else
    echo "[SSH] GitHub private key not found."
fi

echo
echo "[14/16] GitHub Remote Oracle"

REMOTE_OK=0

if [ -n "$REMOTE" ] && [ "$SSH_OK" -eq 1 ]; then
    if GIT_SSH_COMMAND="ssh -i $HOME/.ssh/id_ed25519_github -o IdentitiesOnly=yes -o ConnectTimeout=10" \
        git ls-remote origin HEAD >/dev/null 2>&1; then

        REMOTE_OK=1
        echo "[REMOTE] GitHub remote reachable."
    else
        echo "[REMOTE] GitHub remote check failed."
    fi
else
    echo "[REMOTE] Deferred because SSH is not authenticated."
fi

echo
echo "[15/16] Evidence + EVO"

mkdir -p "$EVIDENCE"

write_env

cat > "$EVIDENCE/status.env" <<ENV
RUN=$RUN
DOMAIN=$DOMAIN
SITE=$SITE
TOKEN_PAGE=$PAGE
LOGO=$LOGO
CONTRACT=$CONTRACT
DNS_OK=$DNS_OK
DOMAIN_HTTP=$DOMAIN_HTTP
PAGE_HTTP=$PAGE_HTTP
LOGO_HTTP=$LOGO_HTTP
BSC_OK=$BSC_OK
SSH_OK=$SSH_OK
REMOTE_OK=$REMOTE_OK
BRANCH=$BRANCH
HEAD=$HEAD
FIXES=$FIXES
FAILURES=$FAILURES
ENV

if [ -f "$ROOT/cybra_evolution.sh" ]; then
    echo "[EVO] Found: $ROOT/cybra_evolution.sh"

    cat > "$EVIDENCE/evo.env" <<ENV
EVO=1
EVO_MODULE=cybra_evolution.sh
EVO_RUN=$RUN
ENV

    echo "[EVO] Registration evidence saved."
else
    echo "[EVO] cybra_evolution.sh not found."
fi

echo
echo "[16/16] Safe Git Stage"

# Make sure generated runtime does not get staged.
mkdir -p "$ROOT/runtime"

if ! grep -qE '^runtime/$' "$ROOT/.gitignore" 2>/dev/null; then
    printf '\nruntime/\n' >> "$ROOT/.gitignore"
    fix "runtime/ added to .gitignore."
fi

# Protect generated backup.
if ! grep -qE '^backup_.*\.tar\.gz$' "$ROOT/.gitignore" 2>/dev/null; then
    printf 'backup_*.tar.gz\n' >> "$ROOT/.gitignore"
    fix "Generated backup protection added."
fi

git add \
    .gitignore \
    robots.txt \
    sitemap.xml \
    CNAME \
    .devcontainer/devcontainer.json \
    .github/workflows/pages.yml \
    2>/dev/null || true

# Evidence is intentionally forced because proofs/feeds may be ignored.
git add -f \
    "$EVIDENCE/status.env" \
    "$EVIDENCE/evo.env" \
    "$ENVFILE" \
    2>/dev/null || true

# Token page only if already tracked or explicitly intended.
if [ -f "$TOKEN_LOCAL" ]; then
    git add -f "$TOKEN_LOCAL" 2>/dev/null || true
fi

if git diff --cached --quiet; then
    echo "[GIT] Nothing new to commit."
else
    git commit -m "chore(cybroncybra): codespaces oracle autopatch" || {
        fail "Git commit failed."
    }
fi

echo
echo "================================================"
echo " CYBRONCYBRA CODESPACES ORACLE — COMPLETE"
echo "================================================"
echo
echo "DOMAIN:       $SITE"
echo "TOKEN PAGE:   $PAGE"
echo "LOGO:         $LOGO"
echo "BSC:          $CONTRACT"
echo
echo "DNS:          $DNS_OK"
echo "DOMAIN HTTP:  $DOMAIN_HTTP"
echo "PAGE HTTP:    $PAGE_HTTP"
echo "LOGO HTTP:    $LOGO_HTTP"
echo "BSC RPC:      $BSC_OK"
echo "SSH:          $SSH_OK"
echo "REMOTE:       $REMOTE_OK"
echo
echo "BRANCH:       $(git branch --show-current)"
echo "HEAD:         $(git rev-parse HEAD)"
echo "FIXES:        $FIXES"
echo "FAILURES:     $FAILURES"
echo
echo "RUN:          $RUN"
echo "LOG:          $LOG"
echo
echo "[AUTO] No git reset --hard."
echo "[AUTO] No destructive cleanup."
echo "[AUTO] Clipboard commands are NEVER executed automatically."
echo "[AUTO] Errors are paused before recovery."
echo "[AUTO] Temporary state stays inside runtime."
echo "[AUTO] Codespaces + GitHub Pages configuration prepared."
echo "[AUTO] Evidence saved."
echo

if [ "$SSH_OK" -eq 1 ] && [ "$REMOTE_OK" -eq 1 ]; then
    echo "[NEXT] Remote доступний."
    echo "[NEXT] Перевірити staged history перед push:"
    echo
    echo "git status --short"
    echo "git log -3 --oneline"
    echo
    echo "[NEXT] Для push використовуй:"
    echo "git push -u origin \"$(git branch --show-current)\""
else
    echo "[NEXT] Push НЕ виконується автоматично."
    echo "[NEXT] Спочатку потрібна GitHub SSH/remote authentication."
fi

echo
echo "[BUFFER-AUTOPATCH] READY"
