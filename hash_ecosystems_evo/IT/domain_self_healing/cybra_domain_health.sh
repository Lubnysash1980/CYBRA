#!/data/data/com.termux/files/usr/bin/bash
set -u

DOMAIN="cybroncybra.com"
BASE="$(cd "$(dirname "$0")" && pwd)"
LOG="$BASE/logs/domain_health.log"

check() {
    local url="$1"
    local code
    code="$(curl -L -s -o /dev/null -w '%{http_code}' "$url" || echo 000)"
    printf '%s | %s | HTTP=%s\n' \
      "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$url" "$code" >> "$LOG"
    echo "$code"
}

check "https://$DOMAIN/"
check "https://$DOMAIN/token.html"
check "https://$DOMAIN/assets/cybra-logo.png"
