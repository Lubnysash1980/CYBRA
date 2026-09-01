#!/data/data/com.termux/files/usr/bin/bash
set -u

BASE="$(cd "$(dirname "$0")" && pwd)"
LOG="$BASE/logs/self_healing.log"

printf '%s | SELF_HEAL_CHECK | SAFE_MODE=TRUE\n' \
  "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" >> "$LOG"

# Safe healing:
# - never changes DNS automatically
# - never deletes repository files
# - never rewrites token.html
# - never rewrites the logo
# - records failure for IT/EVO review

HTTP="$(curl -L -s -o /dev/null -w '%{http_code}' \
  "https://cybroncybra.com/" || echo 000)"

if [ "$HTTP" = "200" ]; then
    printf '%s | DOMAIN_HEALTH=OK\n' \
      "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" >> "$LOG"
else
    printf '%s | DOMAIN_HEALTH=FAIL | HTTP=%s | ACTION=ESCALATE_IT\n' \
      "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$HTTP" >> "$LOG"
fi
