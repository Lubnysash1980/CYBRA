#!/data/data/com.termux/files/usr/bin/bash
# CYBRA HEALTH — статус індикатори для меню

# ─── Швидкий glob без fork ───
shopt -s nullglob

HEALTH_MOD="$HOME/CYBRA/modules/module_19_contract_tui_menu"
H_CONTRACTS="$HEALTH_MOD/contracts"
H_LINKS="$HEALTH_MOD/links"
H_EVIDENCE="$HEALTH_MOD/evidence"
H_STATE="$HEALTH_MOD/state"
H_BIN="$HEALTH_MOD/bin"

# ─── Icon ───
cybra_icon() {
    case "$1" in
        OK)   printf '🟢' ;;
        WARN) printf '🟡' ;;
        ERR)  printf '🔴' ;;
        NA)   printf '⚪' ;;
        *)    printf '⚪' ;;
    esac
}

cybra_icon_label() {
    case "$1" in
        OK)   printf 'READY' ;;
        WARN) printf 'WARN'  ;;
        ERR)  printf 'ERROR' ;;
        *)    printf 'N/A'   ;;
    esac
}

# ─── Checks ───

h_create() { [ -w "$H_CONTRACTS" ] && echo OK || echo ERR; }
h_list()   { local n=0; for f in "$H_CONTRACTS"/*.env; do n=$((n+1)); done; [ "$n" -gt 0 ] && echo OK || echo WARN; }
h_status() { local n=0; for f in "$H_CONTRACTS"/*.env; do n=$((n+1)); done; [ "$n" -gt 0 ] && echo OK || echo WARN; }
h_links_gen() { [ -w "$H_LINKS" ] && echo OK || echo ERR; }
h_links_confirm() {
    local n=0
    for f in "$H_LINKS"/*.link; do
        grep -q '^STATUS=PENDING' "$f" 2>/dev/null && n=$((n+1))
    done
    [ "$n" -gt 0 ] && echo OK || echo WARN
}
h_debug() { [ -s "$H_EVIDENCE/debug.log" ] && echo OK || echo WARN; }
h_ledger_a() { [ -f "$H_EVIDENCE/license_ledger.txt" ] && echo OK || echo ERR; }
h_ledger_b() { [ -f "$H_EVIDENCE/license_ledger_b.txt" ] && echo OK || echo ERR; }
h_hardening() { [ -x "$HOME/CYBRA/cybra_mega_hardening.sh" ] && echo OK || echo ERR; }

h_invoice_create() { [ -w "$H_CONTRACTS" ] && echo OK || echo ERR; }
h_invoice_line() {
    local n=0
    for f in "$H_CONTRACTS"/*.env; do
        grep -q '^CONTRACT_TYPE=INVOICE' "$f" 2>/dev/null && n=$((n+1))
    done
    [ "$n" -gt 0 ] && echo OK || echo WARN
}
h_invoice_show() { local n=0; for f in "$H_CONTRACTS"/*.env; do n=$((n+1)); done; [ "$n" -gt 0 ] && echo OK || echo WARN; }
h_invoice_final() {
    local n=0
    for f in "$H_CONTRACTS"/*.env; do
        grep -q '^CONTRACT_TYPE=INVOICE' "$f" 2>/dev/null && grep -q '^STAGE=DRAFT' "$f" 2>/dev/null && n=$((n+1))
    done
    [ "$n" -gt 0 ] && echo OK || echo WARN
}

h_pii_export() { local n=0; for f in "$H_CONTRACTS"/*.env; do n=$((n+1)); done; [ "$n" -gt 0 ] && echo OK || echo WARN; }
h_pii_git() { [ -d "$HOME/CYBRA/git_module/.git" ] && echo OK || echo WARN; }
h_pii_verify() {
    [ -f "$H_BIN/cybra_tui_lib.sh" ] && grep -q 'cybra_pii_hash' "$H_BIN/cybra_tui_lib.sh" 2>/dev/null && echo OK || echo WARN
}

h_refund_decision() {
    local n=0
    for f in "$H_CONTRACTS"/*.env; do
        grep -q '^BUYER_FINAL_DECISION=PENDING' "$f" 2>/dev/null && n=$((n+1))
    done
    [ "$n" -gt 0 ] && echo OK || echo WARN
}
h_refund_timeout() { [ -f "$H_BIN/cybra_tui_lib.sh" ] && echo OK || echo ERR; }
h_refund_status() { [ -f "$H_BIN/cybra_tui_lib.sh" ] && echo OK || echo ERR; }
h_refund_term() { [ -w "$H_CONTRACTS" ] && echo OK || echo ERR; }

h_rates_show() { [ -s "$H_STATE/rates.env" ] && echo OK || echo ERR; }
h_rates_update() { [ -w "$H_STATE/rates.env" ] && echo OK || echo ERR; }
h_rates_convert() {
    [ -s "$H_STATE/rates.env" ] && command -v python3 >/dev/null 2>&1 && echo OK || echo WARN
}

h_preflight() { [ -x "$H_BIN/cybra_preflight.sh" ] && echo OK || echo ERR; }
h_self_heal() { [ -x "$H_BIN/cybra_self_heal.sh" ] && echo OK || echo ERR; }
h_dual_verify() { grep -q 'cybra_contract_compute_dual_hash' "$H_BIN/cybra_tui_lib.sh" 2>/dev/null && echo OK || echo WARN; }
h_ownership() { [ -f "$H_STATE/ownership.manifest" ] && echo OK || echo WARN; }

h_ai_review() {
    [ -f "$H_BIN/cybra_local_ai.sh" ] || { echo ERR; return; }
    local n=0; for f in "$H_CONTRACTS"/*.env; do n=$((n+1)); done
    [ "$n" -gt 0 ] && echo OK || echo WARN
}
h_ai_parse()  { [ -f "$H_BIN/cybra_local_ai.sh" ] && echo OK || echo ERR; }
h_ai_terms()  {
    [ -f "$H_BIN/cybra_local_ai.sh" ] || { echo ERR; return; }
    local n=0; for f in "$H_CONTRACTS"/*.env; do n=$((n+1)); done
    [ "$n" -gt 0 ] && echo OK || echo WARN
}
h_ai_help()   { [ -f "$H_BIN/cybra_local_ai.sh" ] && echo OK || echo ERR; }
h_ai_ask()    { [ -f "$H_BIN/cybra_local_ai.sh" ] && echo OK || echo ERR; }
h_ai_bar()    { [ -x "$HOME/CYBRA/CYBRA_AI_TASK_BAR.sh" ] && echo OK || echo ERR; }

h_ai_exec_full()  { [ -x "$HOME/CYBRA/ai/cybra_ai_executor.sh" ] && echo OK || echo ERR; }
h_ai_exec_scan()  { [ -x "$HOME/CYBRA/ai/cybra_ai_executor.sh" ] && echo OK || echo ERR; }
h_ai_exec_apply() { [ -x "$HOME/CYBRA/ai/cybra_ai_executor.sh" ] && echo OK || echo ERR; }
h_ai_exec_list()  { [ -d "$HOME/CYBRA/ai/evolution/suggestions" ] && echo OK || echo WARN; }

# ─── Overall system ───
h_system() {
    local errs=0 warns=0
    for c in h_create h_ledger_a h_ledger_b h_hardening h_rates_show h_preflight h_self_heal h_ai_bar h_ai_exec_full; do
        local s=$($c 2>/dev/null)
        case "$s" in
            ERR)  errs=$((errs+1)) ;;
            WARN) warns=$((warns+1)) ;;
        esac
    done
    if [ "$errs" -gt 0 ]; then
        echo ERR
    elif [ "$warns" -gt 0 ]; then
        echo WARN
    else
        echo OK
    fi
}

# ─── Stats (швидко) ───
h_stat_contracts() { local n=0; for f in "$H_CONTRACTS"/*.env; do n=$((n+1)); done; echo "$n"; }
h_stat_links()     { local n=0; for f in "$H_LINKS"/*.link; do n=$((n+1)); done; echo "$n"; }
h_stat_modules() {
    local n=0
    for d in "$HOME/CYBRA/modules"/*/; do
        [ -d "$d" ] || continue
        local m=$(basename "$d")
        case "$m" in @*|.*|_disabled*|evolution|answer_engine|node_modules) continue ;; esac
        n=$((n+1))
    done
    echo "$n"
}
