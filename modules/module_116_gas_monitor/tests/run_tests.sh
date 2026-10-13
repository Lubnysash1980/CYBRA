#!/data/data/com.termux/files/usr/bin/bash
MOD="$(cd "$(dirname "$0")/.." && pwd)"
P=0; F=0
ok()   { echo "[PASS] $1"; P=$((P+1)); }
fail() { echo "[FAIL] $1"; F=$((F+1)); }

echo "============================================================"
echo " $MOD"
echo "============================================================"

[ -d "$MOD" ]           && ok "module dir"    || fail "module dir"
[ -d "$MOD/state" ]     && ok "state dir"     || fail "state dir"
[ -d "$MOD/evidence" ]  && ok "evidence dir"  || fail "evidence dir"
[ -d "$MOD/tests" ]     && ok "tests dir"     || fail "tests dir"

[ -f "$MOD/state/config.env" ] && ok "config.env" || fail "config.env missing"
[ -f "$MOD/state/config.env" ] && bash -n "$MOD/state/config.env" 2>/dev/null || true

if grep -rqE '^AUTO_TRANSACTION=TRUE$|^REAL_TRANSACTION_SENT=TRUE$' "$MOD" 2>/dev/null; then
    fail "auto transaction detected"
else
    ok "no auto transaction"
fi

if grep -q '0x66434c5501242ccC71b5a39C765892921624B66c' "$MOD/state/config.env" 2>/dev/null; then
    ok "license recipient correct"
else
    fail "license recipient wrong"
fi

echo ""
echo "PASS=$P  FAIL=$F"
[ "$F" -eq 0 ] && echo "MODULE_TEST=PASS" || echo "MODULE_TEST=FAIL"
[ "$F" -eq 0 ] && exit 0 || exit 1
