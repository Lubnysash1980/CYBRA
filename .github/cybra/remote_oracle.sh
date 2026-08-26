#!/usr/bin/env bash
set -u
set -o pipefail

DOMAIN="https://cybroncybra.com"
PAGE="${DOMAIN}/token.html"
LOGO="${DOMAIN}/assets/cybra-logo.png"

OUT="${1:-remote_oracle.env}"

check_url() {
    local url="$1"
    local code

    code="$(curl -L -sS \
        --connect-timeout 15 \
        --max-time 30 \
        -o /dev/null \
        -w '%{http_code}' \
        "$url" 2>/dev/null || true)"

    case "$code" in
        200|201|202|204|301|302|307|308)
            echo "$code"
            return 0
            ;;
        *)
            echo "$code"
            return 1
            ;;
    esac
}

DNS_OK=FALSE
HTTPS_DOMAIN_OK=FALSE
HTTPS_PAGE_OK=FALSE
HTTPS_LOGO_OK=FALSE

if getent hosts cybroncybra.com >/dev/null 2>&1; then
    DNS_OK=TRUE
fi

DOMAIN_HTTP="$(check_url "$DOMAIN" || true)"
PAGE_HTTP="$(check_url "$PAGE" || true)"
LOGO_HTTP="$(check_url "$LOGO" || true)"

[ "$DOMAIN_HTTP" != "000" ] && [ -n "$DOMAIN_HTTP" ] && \
    [ "$DOMAIN_HTTP" != "000000" ] && HTTPS_DOMAIN_OK=TRUE

[ "$PAGE_HTTP" != "000" ] && [ -n "$PAGE_HTTP" ] && \
    [ "$PAGE_HTTP" != "000000" ] && HTTPS_PAGE_OK=TRUE

[ "$LOGO_HTTP" != "000" ] && [ -n "$LOGO_HTTP" ] && \
    [ "$LOGO_HTTP" != "000000" ] && HTTPS_LOGO_OK=TRUE

FINAL_REMOTE=FALSE

if [ "$DNS_OK" = TRUE ] &&
   [ "$HTTPS_DOMAIN_OK" = TRUE ] &&
   [ "$HTTPS_PAGE_OK" = TRUE ] &&
   [ "$HTTPS_LOGO_OK" = TRUE ]; then
    FINAL_REMOTE=TRUE
fi

cat > "$OUT" <<STATE
ORACLE_VERSION=1
DOMAIN=$DOMAIN
PAGE=$PAGE
LOGO=$LOGO
DNS_OK=$DNS_OK
HTTPS_DOMAIN_OK=$HTTPS_DOMAIN_OK
HTTPS_PAGE_OK=$HTTPS_PAGE_OK
HTTPS_LOGO_OK=$HTTPS_LOGO_OK
DOMAIN_HTTP=$DOMAIN_HTTP
PAGE_HTTP=$PAGE_HTTP
LOGO_HTTP=$LOGO_HTTP
FINAL_REMOTE=$FINAL_REMOTE
TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
STATE

cat "$OUT"

[ "$FINAL_REMOTE" = TRUE ]
