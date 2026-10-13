#!/data/data/com.termux/files/usr/bin/bash
# CYBRA HARD PREFLIGHT — показує жорсткі помилки з інструкціями

CYBRA_MOD19_ROOT="$HOME/CYBRA/modules/module_19_contract_tui_menu"
CYBRA_CONTRACTS="$CYBRA_MOD19_ROOT/contracts"

PREFLIGHT_PASS=0
PREFLIGHT_FAIL=0

# --- Кольори ---
if [ -t 1 ]; then
    R=$'\033[31m'; G=$'\033[32m'; Y=$'\033[33m'; B=$'\033[1m'; Z=$'\033[0m'
else
    R=""; G=""; Y=""; B=""; Z=""
fi

ph_ok()   { printf '  %s[OK]%s %s\n' "$G" "$Z" "$1"; PREFLIGHT_PASS=$((PREFLIGHT_PASS+1)); }
ph_err()  { printf '  %s[FIX]%s %s\n' "$R" "$Z" "$1"; PREFLIGHT_FAIL=$((PREFLIGHT_FAIL+1)); }
ph_warn() { printf '  %s[WARN]%s %s\n' "$Y" "$Z" "$1"; }

cybra_preflight() {
    PREFLIGHT_PASS=0
    PREFLIGHT_FAIL=0

    printf '%s=== CYBRA PREFLIGHT ===%s\n' "$B" "$Z"

    # --- 1. Essential dirs ---
    for d in "$CYBRA_CONTRACTS" "$CYBRA_MOD19_ROOT/links" "$CYBRA_MOD19_ROOT/evidence" "$CYBRA_MOD19_ROOT/state"; do
        if [ -d "$d" ]; then
            ph_ok "dir: $(basename "$d")"
        else
            mkdir -p "$d"
            ph_warn "dir created: $(basename "$d")"
        fi
    done

    # --- 2. Essential files ---
    for f in \
        "$CYBRA_MOD19_ROOT/bin/cybra_tui_lib.sh" \
        "$CYBRA_MOD19_ROOT/bin/cybra_menu.sh" \
        "$CYBRA_MOD19_ROOT/state/config.env"
    do
        if [ -f "$f" ]; then
            ph_ok "file: $(basename "$f")"
        else
            ph_err "MISSING: $f → запусти: cybra_self_heal"
        fi
    done

    # --- 3. Ledgers ---
    for l in \
        "$CYBRA_MOD19_ROOT/evidence/license_ledger.txt" \
        "$CYBRA_MOD19_ROOT/evidence/license_ledger_b.txt" \
        "$CYBRA_MOD19_ROOT/evidence/creation_license_ledger.txt" \
        "$CYBRA_MOD19_ROOT/evidence/refund_ledger.txt"
    do
        if [ -f "$l" ]; then
            ph_ok "ledger: $(basename "$l")"
        else
            touch "$l"
            ph_warn "ledger init: $(basename "$l")"
        fi
    done

    # --- 4. Syntax check ---
    for f in "$CYBRA_MOD19_ROOT/bin/cybra_tui_lib.sh" "$CYBRA_MOD19_ROOT/bin/cybra_menu.sh"; do
        [ ! -f "$f" ] && continue
        if bash -n "$f" 2>/dev/null; then
            ph_ok "syntax: $(basename "$f")"
        else
            ph_err "SYNTAX ERROR in $f → запусти: cybra_self_heal"
        fi
    done

    # --- 5. Owner ---
    if [ -f "$HOME/CYBRA/.owner" ]; then
        ph_ok "owner marker"
    else
        ph_err "owner missing → запусти: cybra_hard_fix"
    fi

    # --- 6. Frozen ---
    if [ -f "$HOME/CYBRA/evolution/FROZEN" ]; then
        ph_err "СИСТЕМА FROZEN → cybra_evo unfreeze"
    else
        ph_ok "not frozen"
    fi

    # --- 7. Rates ---
    if [ -f "$CYBRA_MOD19_ROOT/state/rates.env" ]; then
        ph_ok "rates"
    else
        ph_warn "rates.env missing → створиться автоматично"
    fi

    # --- 8. Refund schema check (per contract) ---
    local bad_contracts=0
    local total_contracts=0
    for f in "$CYBRA_CONTRACTS"/*.env; do
        [ -f "$f" ] || continue
        total_contracts=$((total_contracts+1))

        # Обов'язкові поля
        for key in REFUND_ENABLED BUYER_FINAL_DECISION REFUND_STATUS; do
            if ! grep -qm1 "^${key}=" "$f"; then
                ph_err "contract $(basename "$f" .env) missing $key"
                bad_contracts=$((bad_contracts+1))
                break
            fi
        done
    done

    if [ "$total_contracts" -eq 0 ]; then
        ph_warn "немає контрактів (це ок для першого запуску)"
    elif [ "$bad_contracts" -eq 0 ]; then
        ph_ok "all contracts valid ($total_contracts)"
    fi

    printf -- '------------------------\n'
    printf '  PASS: %s  FAIL: %s\n' "$PREFLIGHT_PASS" "$PREFLIGHT_FAIL"

    if [ "$PREFLIGHT_FAIL" -eq 0 ]; then
        printf '  %s✓ PREFLIGHT OK%s\n' "$G" "$Z"
        return 0
    else
        printf '  %s✗ PREFLIGHT FAILED — виправ помилки вище%s\n' "$R" "$Z"
        return 1
    fi
}

# Якщо скрипт викликано напряму — запустити
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    cybra_preflight
fi
