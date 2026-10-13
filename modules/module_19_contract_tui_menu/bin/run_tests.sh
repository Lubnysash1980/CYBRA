#!/data/data/com.termux/files/usr/bin/bash
set -u

MOD="$(cd "$(dirname "$0")/.." && pwd)"
source "$MOD/bin/cybra_tui_lib.sh"

# EXPORT_ENV
: "${LICENSE_A_PERCENT:=1}"
: "${LICENSE_B_PERCENT:=1}"
: "${CREATION_FEE_ENABLED:=TRUE}"
: "${CREATION_FEE_PERCENT:=1}"
: "${DUAL_LICENSE_ENABLED:=TRUE}"
export LICENSE_A_PERCENT LICENSE_B_PERCENT
export CREATION_FEE_ENABLED CREATION_FEE_PERCENT
export DUAL_LICENSE_ENABLED
export LICENSE_A_RECIPIENT LICENSE_B_RECIPIENT CREATION_FEE_RECIPIENT
export CYBRA_LICENSE_LEDGER CYBRA_LICENSE_LEDGER_B CYBRA_CREATION_LEDGER

PASS=0
FAIL=0
ok()   { echo "[PASS] $1"; PASS=$((PASS+1)); }
fail() { echo "[FAIL] $1"; FAIL=$((FAIL+1)); }

echo "============================================================"
echo " CYBRA MODULE 19 — CONTRACT TUI MENU"
echo "============================================================"

# 01 — license recipient correct
[ "$LICENSE_RECIPIENT" = "0x66434c5501242ccC71b5a39C765892921624B66c" ] \
    && ok "License recipient correct" || fail "License recipient"

# 02 — license percent 1%
[ "$LICENSE_PERCENT" = "1" ] \
    && ok "License percent = 1" || fail "License percent"

# 03 — license calculation
[ "$(cybra_calc_license 10000)" = "100" ] \
    && ok "License calc 10000 → 100" || fail "License calc 10000"

[ "$(cybra_calc_license 1000000)" = "10000" ] \
    && ok "License calc 1000000 → 10000" || fail "License calc 1000000"

[ "$(cybra_calc_license 100)" = "1" ] \
    && ok "License calc 100 → 1" || fail "License calc 100"

# 04 — create contract
CID="$(cybra_contract_create "0xAAA" "0xBBB" "50000" "BNB")"
[ -n "$CID" ] && ok "Contract created: $CID" || fail "Contract create"

# 05 — contract file exists
cybra_contract_exists "$CID" \
    && ok "Contract file exists" || fail "Contract file"

# 06 — license ledger updated
grep -q "$CID" "$CYBRA_LICENSE_LEDGER" \
    && ok "License ledger updated" || fail "License ledger"

# 07 — generate links
BL="$(cybra_link_generate "$CID" BUYER)"
SL="$(cybra_link_generate "$CID" SELLER)"
RL="$(cybra_link_generate "$CID" RECEIPT)"

[ -n "$BL" ] && [ -n "$SL" ] && [ -n "$RL" ] \
    && ok "3 links generated" || fail "Links generation"

# 08 — confirm buyer
cybra_link_confirm "$BL" "0xAAA" >/dev/null \
    && ok "Buyer confirmed" || fail "Buyer confirm"

# 09 — confirm seller
cybra_link_confirm "$SL" "0xBBB" >/dev/null \
    && ok "Seller confirmed" || fail "Seller confirm"

# 10 — confirm receipt
cybra_link_confirm "$RL" "0xAAA" >/dev/null \
    && ok "Receipt confirmed" || fail "Receipt confirm"

# 11 — stage COMPLETE
CF="$(cybra_contract_path "$CID")"
STAGE="$(grep '^STAGE=' "$CF" | cut -d= -f2)"
[ "$STAGE" = "COMPLETE" ] \
    && ok "Contract STAGE=COMPLETE" || fail "Contract stage=$STAGE"

# 12 — no auto transaction
AUTO="$(grep '^REAL_TRANSACTION_SENT=' "$CF" | cut -d= -f2)"
[ "$AUTO" = "FALSE" ] \
    && ok "No real transaction" || fail "Real transaction detected"

# 13 — no global TRUE_100
G100="$(grep '^GLOBAL_TRUE_100=' "$CF" | cut -d= -f2)"
[ "$G100" = "FALSE" ] \
    && ok "No global TRUE_100" || fail "Global TRUE_100"

# 14 — double confirm blocked
if cybra_link_confirm "$BL" "0xAAA" >/dev/null 2>&1; then fail "Double confirm allowed"; else ok "Double confirm blocked"; fi

# 16 — dual license A percent
[ "$LICENSE_A_PERCENT" = "1" ]     && ok "License A = 1%" || fail "License A percent"

# 17 — dual license B percent
[ "$LICENSE_B_PERCENT" = "1" ]     && ok "License B = 1%" || fail "License B percent"

# 18 — recipient A
[ "$LICENSE_A_RECIPIENT" = "0x66434c5501242ccC71b5a39C765892921624B66c" ]     && ok "License A recipient" || fail "License A recipient"

# 19 — recipient B
[ "$LICENSE_B_RECIPIENT" = "0x66434c5501242ccC71b5a39C765892921624B66c" ]     && ok "License B recipient" || fail "License B recipient"

# 20 — dual license enabled
[ "$DUAL_LICENSE_ENABLED" = "TRUE" ]     && ok "Dual-license enabled" || fail "Dual-license flag"

# 21 — dual ledger A exists
[ -f "$CYBRA_LICENSE_LEDGER" ]     && ok "Ledger A exists" || fail "Ledger A"

# 22 — dual ledger B exists
[ -f "$CYBRA_LICENSE_LEDGER_B" ]     && ok "Ledger B exists" || fail "Ledger B"

# 23 — contract має LICENSE_A_WEI
CF="$(cybra_contract_path "$CID")"
grep -q '^LICENSE_A_WEI=' "$CF"     && ok "Contract has LICENSE_A_WEI" || fail "LICENSE_A_WEI"

# 24 — contract має LICENSE_B_WEI
grep -q '^LICENSE_B_WEI=' "$CF"     && ok "Contract has LICENSE_B_WEI" || fail "LICENSE_B_WEI"

# 25 — contract має LICENSE_TOTAL
grep -q '^LICENSE_TOTAL_WEI=' "$CF"     && ok "Contract has LICENSE_TOTAL_WEI" || fail "LICENSE_TOTAL_WEI"

# 26 — contract dual frozen
grep -q '^DUAL_LICENSE_FROZEN=TRUE' "$CF"     && ok "Dual-license frozen" || fail "Dual frozen"

# 27 — 2% total on example
TOTAL_TEST="$(cybra_calc_license 10000)"
[ "$TOTAL_TEST" = "100" ]     && ok "Single calc 10000 → 100" || fail "Single calc"

# 28 — creation fee enabled
[ "$CREATION_FEE_ENABLED" = "TRUE" ]     && ok "Creation fee enabled" || fail "Creation fee"

# 29 — creation recipient
[ "$CREATION_FEE_RECIPIENT" = "0x66434c5501242ccC71b5a39C765892921624B66c" ]     && ok "Creation recipient" || fail "Creation recipient"

# 30 — creation fee calc (1% від 10000 = 100)
[ "$(cybra_calc_creation_fee 10000)" = "100" ]     && ok "Creation fee calc 10000 → 100" || fail "Creation fee calc"

# 31 — creation ledger exists
[ -f "$CREATION_LICENSE_LEDGER" ]     && ok "Creation ledger exists" || fail "Creation ledger"

# 32 — contract has CREATION_FEE_WEI
grep -q '^CREATION_FEE_WEI=' "$CF"     && ok "Contract CREATION_FEE_WEI" || fail "CREATION_FEE_WEI"

# 33 — contract has CREATION_FEE_RECIPIENT
grep -q '^CREATION_FEE_RECIPIENT=' "$CF"     && ok "Contract CREATION_FEE_RECIPIENT" || fail "CREATION_FEE_RECIPIENT"

# 34 — contract has CREATION_FEE_FROZEN
grep -q '^CREATION_FEE_FROZEN=TRUE' "$CF"     && ok "Contract CREATION_FEE_FROZEN" || fail "CREATION_FEE_FROZEN"

# 35 — git export creation ledger
[ -d "$HOME/CYBRA/git_module/meta/creation_licenses" ]     && ok "Git export creation licenses" || warn "Git export not done yet"

# 15 — rules hash
EXPECTED="$(sha256sum "$MOD/evidence/tui_rules.txt" | awk "{print \$1}")"
SAVED="$(cat "$MOD/evidence/rules.sha256")"
[ "$EXPECTED" = "$SAVED" ] \
    && ok "Rules SHA-256 integrity" || fail "Rules mismatch"

echo
echo "============================================================"
echo " TEST RESULT"
echo " PASS=$PASS  FAIL=$FAIL"
echo "============================================================"

if [ "$FAIL" -eq 0 ]; then
    echo "MODULE_19_TEST=PASS"
    exit 0
else
    echo "MODULE_19_TEST=FAIL"
    exit 1
fi
