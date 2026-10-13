#!/data/data/com.termux/files/usr/bin/bash
# CYBRA CONTRACT TUI v1.1 — повний
source "$HOME/CYBRA/modules/module_19_contract_tui_menu/bin/cybra_tui_lib.sh" 2>/dev/null || true
source "$HOME/CYBRA/modules/module_19_contract_tui_menu/bin/cybra_health.sh" 2>/dev/null || true

# ─── Кольори ───
if [ -t 1 ]; then
    C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'
    C_RED=$'\033[31m'; C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'; C_BLUE=$'\033[34m'
    C_CYAN=$'\033[36m'; C_MAGENTA=$'\033[35m'
    C_GREY=$'\033[90m'
else
    C_RESET=""; C_BOLD=""; C_RED=""; C_GREEN=""
    C_YELLOW=""; C_BLUE=""; C_CYAN=""; C_MAGENTA=""; C_GREY=""
fi

CYBRA_ICON() {
    case "$1" in
        OK)   printf '🟢' ;;
        WARN) printf '🟡' ;;
        ERR)  printf '🔴' ;;
        108) bash "$H/modules/module_108_metamask_sign/main.sh" ;;
    109) bash "$H/modules/module_109_metamask_verify/main.sh" ;;
    110) bash "$H/modules/module_110_metamask_history/main.sh" ;;
    111) bash "$H/modules/module_111_metamask_settings/main.sh" ;;
    112) bash "$H/modules/module_112_metamask_deeplink/main.sh" ;;
    113) bash "$H/modules/module_113_metamask_batch/main.sh" ;;
    114) bash "$H/modules/module_114_autonode/main.sh" ;;
    115) bash "$H/modules/module_115_rpc_bench/main.sh" ;;
    116) bash "$H/modules/module_116_gas_monitor/main.sh" ;;
    117) bash "$H/modules/module_117_tx_lookup/main.sh" ;;
    118) bash "$H/modules/module_118_net_health/main.sh" ;;
    119) bash "$H/modules/module_119_qr_sign/main.sh" ;;
    120) bash "$H/modules/module_120_ai_guardian/main.sh" ;;
    121) bash "$H/modules/module_121_parlament/main.sh" ;;
    122) bash "$H/modules/module_122_contract_validator/main.sh" ;;
    123) bash "$H/modules/module_123_multisig/main.sh" ;;
    124) bash "$H/modules/module_124_timelock/main.sh" ;;
    125) bash "$H/modules/module_125_anchor/main.sh" ;;
    126) bash "$H/modules/module_126_zk/main.sh" ;;
    128) bash "$H/modules/module_128_dashboard/main.sh" ;;
    129) bash "$H/modules/module_129_voice/main.sh" ;;
    130) bash "$H/modules/module_130_test_suite/main.sh" ;;
    131) bash "$H/modules/module_131_kyc/main.sh" ;;
    132) bash "$H/modules/module_132_compliance/main.sh" ;;
    133) bash "$H/modules/module_133_tokens/main.sh" ;;
    134) bash "$H/modules/module_134_discord/main.sh" ;;
    135) bash "$H/modules/module_135_walletconnect/main.sh" ;;
    136) bash "$H/modules/module_136_templates/main.sh" ;;
    137) bash "$H/modules/module_137_escrow/main.sh" ;;
    138) bash "$H/modules/module_138_arbitration/main.sh" ;;
    139) bash "$H/modules/module_139_reputation/main.sh" ;;
    140) bash "$H/modules/module_140_analytics/main.sh" ;;
    141) bash "$H/modules/module_141_portfolio/main.sh" ;;
    142) bash "$H/modules/module_142_invoice_pdf/main.sh" ;;
    143) bash "$H/modules/module_143_email/main.sh" ;;
    144) bash "$H/modules/module_144_lightning/main.sh" ;;
    145) bash "$H/modules/module_145_ipfs/main.sh" ;;
    146) bash "$H/modules/module_146_merkle/main.sh" ;;
    147) bash "$H/modules/module_147_reputation_v2/main.sh" ;;
    148) bash "$H/modules/module_148_multisig_ui/main.sh" ;;
    149) bash "$H/modules/module_149_analytics/main.sh" ;;
    150) bash "$H/modules/module_150_scripts/main.sh" ;;
    151) bash "$H/modules/module_151_wizard/main.sh" ;;
    152) bash "$H/modules/module_152_doctor/main.sh" ;;
    200) bash "$H/modules/module_200_network/main.sh" ;;
    310) bash "$H/modules/module_310_sign_existing/main.sh" ;;
    *)    printf '⚪' ;;
    esac
}

# ─── Actions: ОСНОВНЕ ───
action_create_contract() {
    printf '%s\n' "${C_BOLD}--- Створити контракт ---${C_RESET}"
    printf 'BUYER (0x...):  '; read -r B
    printf 'SELLER (0x...): '; read -r S
    printf 'AMOUNT (wei):   '; read -r A
    printf 'TOKEN [BNB]:    '; read -r T; T="${T:-BNB}"
    [ -z "$B" ] || [ -z "$S" ] || [ -z "$A" ] && { printf '%s\n' "${C_RED}Помилка${C_RESET}"; read -r _; return 1; }
    CID="$(cybra_contract_create "$B" "$S" "$A" "$T")"
    printf '%s\n' "${C_GREEN}OK: $CID${C_RESET}"
    printf 'CONTRACT_ID: %s\n' "$CID"
    read -r _
}

action_list_contracts() {
    printf '%s\n' "${C_BOLD}--- Контракти ---${C_RESET}"
    local n=0
    for f in "$CYBRA_CONTRACTS"/*.env; do
        [ -f "$f" ] || continue
        local cid="$(basename "$f" .env)"
        local stage="$(grep -m1 '^STAGE=' "$f" | cut -d= -f2-)"
        printf '  %-45s [%s]\n' "$cid" "$stage"
        n=$((n+1))
    done
    printf '\nВсього: %s\n' "$n"
    read -r _
}

action_show_status() {
    printf 'CONTRACT_ID: '; read -r C
    local f="$CYBRA_CONTRACTS/$C.env"
    [ ! -f "$f" ] && { printf '%s\n' "${C_RED}Not found${C_RESET}"; read -r _; return 1; }
    cat "$f" | sed 's/^/  /'
    read -r _
}

action_generate_links() {
    printf 'CONTRACT_ID: '; read -r C
    for r in BUYER SELLER RECEIPT; do
        L="$(cybra_link_generate "$C" "$r")"
        printf '  %s -> %s\n' "$r" "$L"
    done
    read -r _
}

action_confirm_link() {
    printf 'LINK_ID: '; read -r L
    printf 'WHO:     '; read -r W
    cybra_link_confirm "$L" "$W"
    read -r _
}

action_debug() {
    printf 'CONTRACT_ID: '; read -r C
    cat "$CYBRA_CONTRACTS/$C.env" 2>/dev/null | sed 's/^/  /'
    echo ""
    echo "--- links ---"
    for lf in "$CYBRA_LINKS"/*.link; do
        [ -f "$lf" ] || continue
        grep -q "CONTRACT_ID=$C" "$lf" && cat "$lf" | sed 's/^/  /'
    done
    read -r _
}

action_dual_license_ledger() {
    printf '%s\n' "${C_BOLD}--- DUAL LICENSE ledger (A+B) ---${C_RESET}"
    printf '\n--- A ---\n'
    tail -20 "$MOD/evidence/license_ledger.txt" 2>/dev/null
    printf '\n--- B ---\n'
    tail -20 "$MOD/evidence/license_ledger_b.txt" 2>/dev/null
    read -r _
}

action_creation_license() {
    printf '%s\n' "${C_BOLD}--- CREATION LICENSE ledger ---${C_RESET}"
    tail -20 "$MOD/evidence/creation_license_ledger.txt" 2>/dev/null
    read -r _
}

action_hardening() {
    printf '%s\n' "${C_BOLD}--- Hardening ---${C_RESET}"
    if [ -x "$HOME/CYBRA/cybra_mega_hardening.sh" ]; then
        "$HOME/CYBRA/cybra_mega_hardening.sh" 2>&1 | tail -30
    else
        printf '%s\n' "${C_RED}hardening not found${C_RESET}"
    fi
    read -r _
}

# ─── INVOICE ───
action_create_invoice() {
    printf '%s\n' "${C_BOLD}--- INVOICE ---${C_RESET}"
    printf 'ПІБ покупця:     '; read -r BN
    printf 'ІПН покупця:     '; read -r BI
    printf 'Wallet покупця:  '; read -r BW
    printf 'Продавець:       '; read -r SN
    printf 'ЄДРПОУ:          '; read -r SE
    printf 'Wallet продавця: '; read -r SW
    printf '№ рахунку:       '; read -r IN
    printf 'Дата:            '; read -r ID
    printf 'Сума (wei):      '; read -r AM
    printf 'Token:           '; read -r TK
    CID="$(cybra_contract_create_invoice "$BN" "$BI" "$BW" "$SN" "$SE" "$SW" "$IN" "$ID" "$AM" "$TK" 18 20)" 2>/dev/null
    [ -z "$CID" ] && { printf '%s\n' "${C_RED}Fail${C_RESET}"; read -r _; return 1; }
    printf '%s\n' "${C_GREEN}OK: $CID${C_RESET}"
    read -r _
}

action_add_line() {
    printf 'CONTRACT_ID: '; read -r C
    printf 'Код:        '; read -r CODE
    printf 'Назва:      '; read -r NAME
    printf 'К-сть:      '; read -r QTY
    printf 'Ціна:       '; read -r PRICE
    cybra_invoice_add_line "$C" "$CODE" "$NAME" "$QTY" "$PRICE" 2>/dev/null
    read -r _
}

action_show_invoice() {
    printf 'CONTRACT_ID: '; read -r C
    cybra_invoice_show "$C" 2>/dev/null
    read -r _
}

action_finalize_invoice() {
    printf 'CONTRACT_ID: '; read -r C
    cybra_invoice_finalize "$C" 2>/dev/null
    read -r _
}

# ─── PII MASK ───
action_export_masked() {
    printf 'CONTRACT_ID: '; read -r C
    local h="$(cybra_export_masked "$C" "$HOME/CYBRA/public/contracts" 2>/dev/null)"
    printf '%s\n' "${C_GREEN}Export: ${h:0:16}...${C_RESET}"
    read -r _
}
action_export_all_masked() {
    cybra_export_all_masked "$HOME/CYBRA/public/contracts" 2>/dev/null
    read -r _
}
action_verify_pii() {
    printf 'Значення: '; read -r V
    printf 'Hash:     '; read -r H
    local c="$(cybra_pii_hash "$V" 2>/dev/null)"
    [ "$c" = "$H" ] && printf '%s\n' "${C_GREEN}MATCH${C_RESET}" || printf '%s\n' "${C_RED}MISMATCH${C_RESET}"
    read -r _
}

# ─── REFUND ───
action_buyer_final_decision() {
    printf 'CONTRACT_ID: '; read -r C
    printf 'Рішення [CONFIRMED/REJECTED]: '; read -r D
    cybra_buyer_final_decision "$C" "$D" 2>/dev/null
    read -r _
}
action_check_timeouts() {
    cybra_check_all_refunds 2>/dev/null
    read -r _
}
action_refund_status() {
    printf 'CONTRACT_ID: '; read -r C
    cybra_refund_status "$C" 2>/dev/null
    read -r _
}
action_add_term() {
    printf 'CONTRACT_ID: '; read -r C
    printf 'Умова:       '; read -r T
    cybra_add_custom_term "$C" "$T" 2>/dev/null
    read -r _
}

# ─── ВАЛЮТИ ───
action_show_rates() {
    cybra_show_rates 2>/dev/null
    read -r _
}
action_update_rate() {
    printf 'RATE_KEY: '; read -r K
    printf 'VALUE:    '; read -r V
    local rf="$MOD/state/rates.env"
    if grep -q "^${K}=" "$rf" 2>/dev/null; then
        sed -i "s|^${K}=.*|${K}=${V}|" "$rf"
    else
        printf '%s=%s\n' "$K" "$V" >> "$rf"
    fi
    printf '%s\n' "${C_GREEN}OK${C_RESET}"
    read -r _
}
action_convert() {
    printf 'Сума:  '; read -r A
    printf 'З:     '; read -r F
    printf 'У:     '; read -r T
    printf '  Див. курси в [22]\n'
    read -r _
}

# ─── СИСТЕМА ───
action_preflight() {
    bash "$MOD/bin/cybra_preflight.sh" 2>/dev/null
    read -r _
}
action_self_heal() {
    bash "$MOD/bin/cybra_self_heal.sh" 2>/dev/null
    read -r _
}
action_dual_verify() {
    printf 'CONTRACT_ID: '; read -r C
    cybra_contract_compute_dual_hash "$C" >/dev/null 2>&1
    cybra_contract_verify_dual "$C" 2>/dev/null
    read -r _
}
action_ownership() {
    cybra_ownership_scan 2>/dev/null
    read -r _
}

# ─── AI ───
action_ai_review() {
    printf 'CONTRACT_ID: '; read -r C
    source "$MOD/bin/cybra_local_ai.sh" 2>/dev/null
    local_ai_review_contract "$C" 2>/dev/null || printf 'AI недоступний\n'
    read -r _
}
action_ai_parse() {
    source "$MOD/bin/cybra_local_ai.sh" 2>/dev/null
    local_ai_parse_invoice 2>/dev/null
    read -r _
}
action_ai_terms() {
    printf 'CONTRACT_ID: '; read -r C
    source "$MOD/bin/cybra_local_ai.sh" 2>/dev/null
    local_ai_generate_terms "$C" 2>/dev/null
    read -r _
}
action_ai_help() {
    printf 'Помилка: '; read -r E
    source "$MOD/bin/cybra_local_ai.sh" 2>/dev/null
    local_ai_help_error "$E" 2>/dev/null
    read -r _
}
action_ai_ask() {
    printf 'Питання: '; read -r Q
    source "$MOD/bin/cybra_local_ai.sh" 2>/dev/null
    local_ai_answer "$Q" 2>/dev/null
    read -r _
}
action_ai_taskbar() {
    if [ -x "$HOME/CYBRA/CYBRA_AI_TASK_BAR.sh" ]; then
        "$HOME/CYBRA/CYBRA_AI_TASK_BAR.sh"
    else
        printf '%s\n' "${C_RED}AI Task Bar не знайдено${C_RESET}"
        read -r _
    fi
}

# ─── AI EVOLUTION ───
action_ai_exec_full()  { "$HOME/CYBRA/ai/cybra_ai_executor.sh" full 2>&1 | tail -30; read -r _; }
action_ai_exec_scan()  { "$HOME/CYBRA/ai/cybra_ai_executor.sh" scan 2>&1 | tail -30; read -r _; }
action_ai_exec_apply() { "$HOME/CYBRA/ai/cybra_ai_executor.sh" apply 2>&1 | tail -30; read -r _; }
action_ai_exec_list()  { ls -la "$HOME/CYBRA/ai/evolution/suggestions/" 2>/dev/null; read -r _; }

# ─── ADDRESS BOOK ───
action_addr_add() {
    printf 'Name:    '; read -r N
    printf 'Address: '; read -r A
    printf 'Tag:     '; read -r T
    source "$HOME/CYBRA/modules/module_25_address_book/bin/address_book.sh" 2>/dev/null
    ab_add "$N" "$A" "${T:-user}" 2>/dev/null
    read -r _
}
action_addr_list()    { source "$HOME/CYBRA/modules/module_25_address_book/bin/address_book.sh" 2>/dev/null; ab_list 2>/dev/null; read -r _; }
action_addr_history() { source "$HOME/CYBRA/modules/module_25_address_book/bin/address_book.sh" 2>/dev/null; ab_history 2>/dev/null; read -r _; }

# ─── INTEGRATIONS ───
action_qr() {
    printf 'CONTRACT_ID: '; read -r C
    printf 'ROLE:        '; read -r R
    source "$HOME/CYBRA/modules/module_26_qr_codes/bin/qr.sh" 2>/dev/null
    qr_gen_link "$C" "${R:-BUYER}" 2>/dev/null
    read -r _
}
action_tg_setup() {
    printf 'Bot Token: '; read -r T
    printf 'Chat ID:   '; read -r C
    source "$HOME/CYBRA/modules/module_27_telegram_bot/bin/tg.sh" 2>/dev/null
    tg_set_token "$T"; tg_set_chat "$C"
    read -r _
}
action_tg_test() {
    source "$HOME/CYBRA/modules/module_27_telegram_bot/bin/tg.sh" 2>/dev/null
    tg_test 2>/dev/null
    read -r _
}
action_wh_list() { source "$HOME/CYBRA/modules/module_32_webhook/bin/webhook.sh" 2>/dev/null; wh_list 2>/dev/null; read -r _; }
action_wh_add() {
    printf 'Name:   '; read -r N
    printf 'URL:    '; read -r U
    printf 'Events: '; read -r E
    source "$HOME/CYBRA/modules/module_32_webhook/bin/webhook.sh" 2>/dev/null
    wh_add "$N" "$U" "${E:-*}" 2>/dev/null
    read -r _
}

# ─── EXPORT / BACKUP ───
action_exp_csv()    { source "$HOME/CYBRA/modules/module_28_export/bin/export.sh" 2>/dev/null; exp_contracts_csv 2>/dev/null; read -r _; }
action_exp_ledger() { source "$HOME/CYBRA/modules/module_28_export/bin/export.sh" 2>/dev/null; exp_ledger_csv 2>/dev/null; read -r _; }
action_exp_report() {
    printf 'CONTRACT_ID: '; read -r C
    source "$HOME/CYBRA/modules/module_28_export/bin/export.sh" 2>/dev/null
    exp_txt_report "$C" 2>/dev/null
    read -r _
}
action_bk_local() { source "$HOME/CYBRA/modules/module_29_backup/bin/backup.sh" 2>/dev/null; bk_local 2>/dev/null; read -r _; }
action_bk_cloud() { source "$HOME/CYBRA/modules/module_29_backup/bin/backup.sh" 2>/dev/null; bk_cloud 2>/dev/null; read -r _; }

# ─── MULTI-CHAIN ───
action_chains() {
    source "$HOME/CYBRA/modules/module_30_multichain/bin/multichain.sh" 2>/dev/null
    mc_list 2>/dev/null
    read -r _
}
action_scan_tx() {
    printf 'CHAIN [BSC]: '; read -r C
    printf 'TX:          '; read -r T
    source "$HOME/CYBRA/modules/module_30_multichain/bin/multichain.sh" 2>/dev/null
    mc_tx_link "${C:-BSC}" "$T" 2>/dev/null
    read -r _
}

# ─── DISPUTE / AUDIT ───
action_dp_open() {
    printf 'CONTRACT_ID: '; read -r C
    printf 'OPENED_BY:   '; read -r B
    printf 'REASON:      '; read -r R
    source "$HOME/CYBRA/modules/module_31_dispute_resolver/bin/dispute.sh" 2>/dev/null
    dp_open "$C" "$B" "$R" 2>/dev/null
    read -r _
}
action_dp_list() { source "$HOME/CYBRA/modules/module_31_dispute_resolver/bin/dispute.sh" 2>/dev/null; dp_list 2>/dev/null; read -r _; }
action_dp_vote() {
    printf 'DISPUTE_ID: '; read -r D
    printf 'VOTER:      '; read -r V
    printf 'VOTE:       '; read -r O
    source "$HOME/CYBRA/modules/module_31_dispute_resolver/bin/dispute.sh" 2>/dev/null
    dp_vote "$D" "$V" "$O" 2>/dev/null
    read -r _
}
action_audit_show()   { source "$HOME/CYBRA/modules/module_33_audit_log/bin/audit.sh" 2>/dev/null; au_show 2>/dev/null; read -r _; }
action_audit_verify() { source "$HOME/CYBRA/modules/module_33_audit_log/bin/audit.sh" 2>/dev/null; au_verify 2>/dev/null; read -r _; }

# ─── DOCUMENT SCANNER ───
action_scan_photo() { source "$HOME/CYBRA/modules/module_34_doc_scanner/bin/scanner.sh" 2>/dev/null; sc_photo 2>/dev/null; read -r _; }
action_scan_ocr()   { printf 'File: '; read -r F; source "$HOME/CYBRA/modules/module_34_doc_scanner/bin/scanner.sh" 2>/dev/null; sc_ocr "$F" 2>/dev/null; read -r _; }
action_scan_pdf()   { printf 'PDF:  '; read -r F; source "$HOME/CYBRA/modules/module_34_doc_scanner/bin/scanner.sh" 2>/dev/null; sc_pdf_to_text "$F" 2>/dev/null; read -r _; }
action_scan_full()  { source "$HOME/CYBRA/modules/module_34_doc_scanner/bin/scanner.sh" 2>/dev/null; sc_scan_pipeline 2>/dev/null; read -r _; }

# ─── GUARDIAN ───
GD_LIB="$HOME/CYBRA/modules/module_35_cybra_guardian/bin/guardian.sh"

action_gd_state()        { source "$GD_LIB" 2>/dev/null; gd_check_state 2>/dev/null; read -r _; }
action_gd_100()          {
    source "$GD_LIB" 2>/dev/null
    gd_check_state >/dev/null 2>&1
    local p="$(cat "$GUARD_EV/state_pct.txt" 2>/dev/null || echo 0)"
    if [ "$p" -eq 100 ]; then
        printf '%s✓ 100%% STATE%s\n' "${C_GREEN}" "${C_RESET}"
    else
        printf '%s✗ %s%% — потрібно відновлення%s\n' "${C_RED}" "$p" "${C_RESET}"
    fi
    read -r _
}
action_gd_register() {
    source "$GD_LIB" 2>/dev/null
    printf "Ім'я:      "; read -r N
    printf "ID номер:  "; read -r I
    printf "Wallet:    "; read -r W
    printf "Bio [none]: "; read -r B
    gd_register "$N" "$I" "$W" "${B:-none}" 2>/dev/null
    read -r _
}
action_gd_show()         { source "$GD_LIB" 2>/dev/null; gd_show_identity 2>/dev/null; read -r _; }
action_gd_verify() {
    source "$GD_LIB" 2>/dev/null
    printf "Ім'я:      "; read -r N
    printf "ID номер:  "; read -r I
    printf "Wallet:    "; read -r W
    printf "Bio [none]: "; read -r B
    gd_verify "$N" "$I" "$W" "${B:-none}" 2>/dev/null
    read -r _
}
action_gd_device()       { source "$GD_LIB" 2>/dev/null; gd_device_info 2>/dev/null; read -r _; }
action_gd_snapshot()     { source "$GD_LIB" 2>/dev/null; gd_recovery_snapshot 2>/dev/null; read -r _; }
action_gd_restore_git()  { source "$GD_LIB" 2>/dev/null; gd_recovery_from_git 2>/dev/null; read -r _; }
action_gd_restore_snap() { source "$GD_LIB" 2>/dev/null; gd_recovery_from_snapshot 2>/dev/null; read -r _; }
action_gd_auto()         { source "$GD_LIB" 2>/dev/null; gd_auto_recover 2>/dev/null; read -r _; }
action_gd_actions()      { tail -30 "$HOME/CYBRA/modules/module_35_cybra_guardian/evidence/actions.log" 2>/dev/null; read -r _; }
action_gd_log_verify()   { source "$GD_LIB" 2>/dev/null; gd_log_verify 2>/dev/null; read -r _; }

# ─── AUTOSAVE ───
AS_LIB="$HOME/CYBRA/modules/module_35_cybra_guardian/bin/autosave.sh"

action_as_save()      { source "$AS_LIB" 2>/dev/null; printf 'CONTRACT_ID: '; read -r C; as_save_all "$C" 2>/dev/null; read -r _; }
action_as_status()    { source "$AS_LIB" 2>/dev/null; as_status 2>/dev/null; read -r _; }
action_as_recent()    { source "$AS_LIB" 2>/dev/null; as_recent 2>/dev/null; read -r _; }
action_as_restore()   { source "$AS_LIB" 2>/dev/null; printf 'CONTRACT_ID: '; read -r C; as_restore_contract "$C" 2>/dev/null; read -r _; }
action_as_setup_email() {
    CONF="$HOME/CYBRA/modules/module_35_cybra_guardian/state/autosave.env"
    printf 'From:   '; read -r F
    printf 'To:     '; read -r T
    printf 'Host:   '; read -r H
    printf 'Port:   '; read -r P
    printf 'User:   '; read -r U
    printf 'Pass:   '; read -rs PW; echo
    sed -i "s|^EMAIL_FROM=.*|EMAIL_FROM=$F|"        "$CONF"
    sed -i "s|^EMAIL_TO=.*|EMAIL_TO=$T|"            "$CONF"
    sed -i "s|^EMAIL_SMTP_HOST=.*|EMAIL_SMTP_HOST=$H|" "$CONF"
    sed -i "s|^EMAIL_SMTP_PORT=.*|EMAIL_SMTP_PORT=$P|" "$CONF"
    sed -i "s|^EMAIL_SMTP_USER=.*|EMAIL_SMTP_USER=$U|" "$CONF"
    sed -i "s|^EMAIL_SMTP_PASS=.*|EMAIL_SMTP_PASS=$PW|" "$CONF"
    sed -i "s|^EMAIL_ENABLED=.*|EMAIL_ENABLED=TRUE|"   "$CONF"
    sed -i "s|^AUTOSAVE_EMAIL=.*|AUTOSAVE_EMAIL=TRUE|" "$CONF"
    printf '%s\n' "${C_GREEN}OK${C_RESET}"
    read -r _
}
action_as_setup_cloud() {
    CONF="$HOME/CYBRA/modules/module_35_cybra_guardian/state/autosave.env"
    printf 'Provider: '; read -r P
    printf 'Path:     '; read -r PA
    sed -i "s|^CLOUD_PROVIDER=.*|CLOUD_PROVIDER=$P|"   "$CONF"
    sed -i "s|^CLOUD_PATH=.*|CLOUD_PATH=$PA|"          "$CONF"
    sed -i "s|^CLOUD_ENABLED=.*|CLOUD_ENABLED=TRUE|"   "$CONF"
    sed -i "s|^AUTOSAVE_CLOUD=.*|AUTOSAVE_CLOUD=TRUE|" "$CONF"
    printf '%s\n' "${C_GREEN}OK${C_RESET}"
    read -r _
}

# ─── HEADER ───
print_header() {
    clear 2>/dev/null || printf '\033[2J\033[H'
    local mods=0
    for d in "$HOME/CYBRA/modules"/*/; do
        [ -d "$d" ] || continue
        local m=$(basename "$d")
        case "$m" in @*|.*|_disabled*|evolution|answer_engine|node_modules) continue;; esac
        mods=$((mods+1))
    done
    local cons=0
    for f in "$CYBRA_CONTRACTS"/*.env; do [ -f "$f" ] && cons=$((cons+1)); done
    local links=0
    for f in "$CYBRA_LINKS"/*.link; do [ -f "$f" ] && links=$((links+1)); done
    local now="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

    printf '%s\n' "${C_BOLD}${C_CYAN}════════════════════════════════════════════════════════════${C_RESET}"
    printf '%s\n' "${C_BOLD}${C_CYAN}              CYBRA CONTRACT MANAGER — TUI v1.1${C_RESET}"
    printf '%s\n' "${C_BOLD}${C_CYAN}════════════════════════════════════════════════════════════${C_RESET}"
    printf '  🟢 READY  │  BSC(56)  │  1%%+1%%+1%% license\n'
    printf '  %s modules  │  %s contracts  │  %s links\n' "$mods" "$cons" "$links"
    printf '%s\n' "  ${C_GREY}🕐 $now${C_RESET}"
    printf '%s\n' "${C_GREY}────────────────────────────────────────────────────────────${C_RESET}"
    printf '\n'
}

# ─── MENU (усі секції) ───
print_menu(){
  clear
  printf "%s\n" "${B}${C_BOLD}════════════════════════════════════════════════════════════${C_RESET}"
  printf "%s\n" "${B}${C_BOLD}  CYBRA · v3.0${C_RESET}                    $(date -u +'%Y-%m-%d %H:%M UTC')"
  printf "%s\n" "${B}${C_BOLD}════════════════════════════════════════════════════════════${C_RESET}"
  echo
  printf "%s\n" "  ${B}─── ОСНОВНЕ ───${C_RESET}"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[1]${C_RESET} create_contract\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[2]${C_RESET} list_contracts\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[3]${C_RESET} show_status\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[4]${C_RESET} generate_links\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[5]${C_RESET} confirm_link\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[6]${C_RESET} debug\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[7]${C_RESET} dual_license_ledger\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[8]${C_RESET} creation_license\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[9]${C_RESET} hardening\n"
  echo
  printf "%s\n" "  ${B}─── INVOICE ───${C_RESET}"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[11]${C_RESET} create_invoice\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[12]${C_RESET} add_line\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[13]${C_RESET} show_invoice\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[14]${C_RESET} finalize_invoice\n"
  echo
  printf "%s\n" "  ${B}─── PII MASK ───${C_RESET}"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[15]${C_RESET} export_masked\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[16]${C_RESET} export_all_masked\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[17]${C_RESET} verify_pii\n"
  echo
  printf "%s\n" "  ${B}─── REFUND ───${C_RESET}"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[18]${C_RESET} buyer_final_decision\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[19]${C_RESET} check_timeouts\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[20]${C_RESET} refund_status\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[21]${C_RESET} add_term\n"
  echo
  printf "%s\n" "  ${B}─── ВАЛЮТИ ───${C_RESET}"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[22]${C_RESET} show_rates\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[23]${C_RESET} update_rate\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[24]${C_RESET} convert\n"
  echo
  printf "%s\n" "  ${B}─── СИСТЕМА ───${C_RESET}"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[30]${C_RESET} preflight\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[31]${C_RESET} self_heal\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[32]${C_RESET} dual_verify\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[33]${C_RESET} ownership\n"
  echo
  printf "%s\n" "  ${B}─── AI (офлайн) ───${C_RESET}"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[40]${C_RESET} ai_review\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[41]${C_RESET} ai_parse\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[42]${C_RESET} ai_terms\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[43]${C_RESET} ai_help\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[44]${C_RESET} ai_ask\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[45]${C_RESET} ai_taskbar\n"
  echo
  printf "%s\n" "  ${B}─── AI EVOLUTION ───${C_RESET}"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[46]${C_RESET} ai_exec_full\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[47]${C_RESET} ai_exec_scan\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[48]${C_RESET} ai_exec_apply\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[49]${C_RESET} ai_exec_list\n"
  echo
  printf "%s\n" "  ${B}─── ADDRESS BOOK ───${C_RESET}"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[50]${C_RESET} addr_add\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[51]${C_RESET} addr_list\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[52]${C_RESET} addr_history\n"
  echo
  printf "%s\n" "  ${B}─── INTEGRATIONS ───${C_RESET}"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[53]${C_RESET} qr\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[54]${C_RESET} tg_setup\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[55]${C_RESET} tg_test\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[56]${C_RESET} wh_list\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[57]${C_RESET} wh_add\n"
  echo
  printf "%s\n" "  ${B}─── EXPORT / BACKUP ───${C_RESET}"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[58]${C_RESET} exp_csv\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[59]${C_RESET} exp_ledger\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[60]${C_RESET} exp_report\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[61]${C_RESET} bk_local\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[62]${C_RESET} bk_cloud\n"
  echo
  printf "%s\n" "  ${B}─── MULTI-CHAIN ───${C_RESET}"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[63]${C_RESET} chains\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[64]${C_RESET} scan_tx\n"
  echo
  printf "%s\n" "  ${B}─── DISPUTE / AUDIT ───${C_RESET}"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[65]${C_RESET} dp_open\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[66]${C_RESET} dp_list\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[67]${C_RESET} dp_vote\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[68]${C_RESET} audit_show\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[69]${C_RESET} audit_verify\n"
  echo
  printf "%s\n" "  ${B}─── DOCUMENT SCANNER ───${C_RESET}"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[70]${C_RESET} scan_photo\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[71]${C_RESET} scan_ocr\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[72]${C_RESET} scan_pdf\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[73]${C_RESET} scan_full\n"
  echo
  printf "%s\n" "  ${B}─── РОЗШИРЕНІ ───${C_RESET}"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[74]${C_RESET} search_contract\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[75]${C_RESET} autofill_contract\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[76]${C_RESET} ai_terms\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[77]${C_RESET} check_payment\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[78]${C_RESET} custom_terms\n"
  echo
  printf "%s\n" "  ${B}─── GUARDIAN ───${C_RESET}"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[80]${C_RESET} gd_state\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[81]${C_RESET} gd_100\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[82]${C_RESET} gd_register\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[83]${C_RESET} gd_show\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[84]${C_RESET} gd_verify\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[85]${C_RESET} gd_device\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[86]${C_RESET} gd_snapshot\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[87]${C_RESET} gd_restore_git\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[88]${C_RESET} gd_restore_snap\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[89]${C_RESET} gd_auto\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[90]${C_RESET} gd_actions\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[91]${C_RESET} gd_log_verify\n"
  echo
  printf "%s\n" "  ${B}─── AUTOSAVE ───${C_RESET}"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[92]${C_RESET} as_save\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[93]${C_RESET} as_status\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[94]${C_RESET} as_recent\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[95]${C_RESET} as_restore\n"
  echo
  printf "%s\n" "  ${B}─── EVO CONTROLLERS ───${C_RESET}"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[96]${C_RESET} evo7\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[97]${C_RESET} evo_ctl\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[98]${C_RESET} parawatch\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[99]${C_RESET} autopatch_menu\n"
  echo
  printf "%s\n" "  ${B}─── NODE / HASH / SYSTEM ───${C_RESET}"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[100]${C_RESET} node\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[101]${C_RESET} hash_eco\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[102]${C_RESET} binmix\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[103]${C_RESET} metrics\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[104]${C_RESET} http\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[105]${C_RESET} schedule\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[106]${C_RESET} cleanup\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[107]${C_RESET} autopilot\n"
  echo
  printf "%s\n" "  ${B}─── METAMASK ───${C_RESET}"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[108]${C_RESET} metamask_sign\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[109]${C_RESET} metamask_verify\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[110]${C_RESET} metamask_history\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[111]${C_RESET} metamask_settings\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[112]${C_RESET} metamask_deeplink\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[113]${C_RESET} metamask_batch\n"
  echo
  printf "%s\n" "  ${B}─── AUTONODE ───${C_RESET}"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[114]${C_RESET} autonode\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[115]${C_RESET} rpc_bench\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[116]${C_RESET} gas_monitor\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[117]${C_RESET} tx_lookup\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[118]${C_RESET} net_health\n"
  echo
  printf "%s\n" "  ${B}─── QR SIGN ───${C_RESET}"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[119]${C_RESET} qr_sign\n"
  echo
  printf "%s\n" "  ${B}─── AI GUARDIAN ───${C_RESET}"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[120]${C_RESET} ai_guardian\n"
  echo
  printf "%s\n" "  ${B}─── PARLIAMENT ───${C_RESET}"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[121]${C_RESET} parlament\n"
  echo
  printf "%s\n" "  ${B}─── VALIDATOR / MULTISIG ───${C_RESET}"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[122]${C_RESET} contract_validator\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[123]${C_RESET} multisig\n"
  echo
  printf "%s\n" "  ${B}─── CRYPTO ───${C_RESET}"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[124]${C_RESET} timelock\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[125]${C_RESET} anchor\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[126]${C_RESET} zk\n"
  echo
  printf "%s\n" "  ${B}─── UI / TOOLS ───${C_RESET}"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[128]${C_RESET} dashboard\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[129]${C_RESET} voice\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[130]${C_RESET} test_suite\n"
  echo
  printf "%s\n" "  ${B}─── INTEGRATIONS+ ───${C_RESET}"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[131]${C_RESET} kyc\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[132]${C_RESET} compliance\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[133]${C_RESET} tokens\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[134]${C_RESET} discord\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[135]${C_RESET} walletconnect\n"
  echo
  printf "%s\n" "  ${B}─── ESCROW / ARBITRATION ───${C_RESET}"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[136]${C_RESET} templates\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[137]${C_RESET} escrow\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[138]${C_RESET} arbitration\n"
  echo
  printf "%s\n" "  ${B}─── REPUTATION / ANALYTICS ───${C_RESET}"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[139]${C_RESET} reputation\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[140]${C_RESET} analytics\n"
  echo
  printf "%s\n" "  ${B}─── ADVANCED ───${C_RESET}"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[141]${C_RESET} portfolio\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[142]${C_RESET} invoice_pdf\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[143]${C_RESET} email\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[144]${C_RESET} lightning\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[145]${C_RESET} ipfs\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[146]${C_RESET} merkle\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[147]${C_RESET} reputation_v2\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[148]${C_RESET} multisig_ui\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[149]${C_RESET} analytics\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[150]${C_RESET} scripts\n"
  echo
  printf "%s\n" "  ${B}─── ONBOARDING ───${C_RESET}"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[151]${C_RESET} wizard\n"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[152]${C_RESET} doctor\n"
  echo
  printf "%s\n" "  ${B}─── NETWORK ───${C_RESET}"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[200]${C_RESET} network\n"
  echo
  printf "%s\n" "  ${B}─── SIGN EXISTING ───${C_RESET}"
  printf "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[310]${C_RESET} sign_existing\n"

  echo "  ${B}─── CONTROLLERS ───${C_RESET}"
  echo "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[320]${C_RESET} Контролери системи (7 контролерів)"
  echo "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[330]${C_RESET} Self-Heal Engine — авто-відновлення"
  echo "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[350]${C_RESET} Controller Worker — цикл + автолікування"
  echo "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[360]${C_RESET} Mapping Controller — карта пунктів"
  echo "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[370]${C_RESET} Runtime Worker — паралельні задачі"
  echo "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[371]${C_RESET} Job Controller — failover runtime→binmixer"
  echo "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[380]${C_RESET} SIC — System Integration Controller"
  echo "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[390]${C_RESET} SRC — Self-Recovery Controller (100%)"

  echo "  ${B}─── STABILITY ───${C_RESET}"
  echo "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[395]${C_RESET} Structure Guardian — карта структури"
  echo "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[396]${C_RESET} Snapshot Diff Recovery — посимвольне"
  echo "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[397]${C_RESET} Load Controller — балансування CPU"
  echo "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[398]${C_RESET} Web UI — стан (порт 8791)"
  echo "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[399]${C_RESET} 🚫 100% Gate — жорсткий пропускний"
  echo "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[401]${C_RESET} Cascade Verifier — тести ротації"
  echo "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[402]${C_RESET} Menu Doctor — перевірка пунктів меню"
  echo "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[405]${C_RESET} Task Engine — двигун задач (sandbox + test)"
  echo "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[340]${C_RESET} Payment Confirmation (NBU QR)"
  echo "  ${C_GREY}🟢${C_RESET} ${C_BOLD}[341]${C_RESET} Dual Confirmation — подвійний підпис"
  echo
  printf "%s\n" "  ${C_GREY}🟢 ready  🟡 warning  🔴 error${C_RESET}"
  echo
  echo "  [0]  Вихід"
  echo
}

# ─── Main loop ───

action_evo7() {
    "$HOME/CYBRA/bin/cybra_evo7" menu
}


action_evo_ctl() {
    "$HOME/CYBRA/bin/cybra_evo_ctl" run
    read -r _
}

action_parawatch() {
    printf '  [1] Status\n'
    printf '  [2] Start (фон)\n'
    printf '  [3] Stop\n'
    printf '  [4] Once\n'
    printf 'Вибір: '
    read -r pw
    case "$pw" in
        1) "$HOME/CYBRA/bin/cybra_parawatch" status; read -r _ ;;
        2) "$HOME/CYBRA/bin/cybra_parawatch" start; read -r _ ;;
        3) "$HOME/CYBRA/bin/cybra_parawatch" stop; read -r _ ;;
        4) "$HOME/CYBRA/bin/cybra_parawatch" once; read -r _ ;;
    esac
}

action_autopatch_menu() {
    printf '  [1] Dry-run\n'
    printf '  [2] Патчити все\n'
    printf '  [3] Тільки контракти\n'
    printf 'Вибір: '
    read -r ap
    case "$ap" in
        1) "$HOME/CYBRA/bin/cybra_autopatch" check; read -r _ ;;
        2) "$HOME/CYBRA/bin/cybra_autopatch" all; read -r _ ;;
        3) "$HOME/CYBRA/bin/cybra_autopatch" contracts; read -r _ ;;
    esac
}


action_watchdog() {
    printf '  [1] Status\n'
    printf '  [2] Start (фон)\n'
    printf '  [3] Stop\n'
    printf '  [4] Once\n'
    printf 'Вибір: '
    read -r wd
    case "$wd" in
        1) "$HOME/CYBRA/bin/cybra_watchdog" status; read -r _ ;;
        2) "$HOME/CYBRA/bin/cybra_watchdog" start; read -r _ ;;
        3) "$HOME/CYBRA/bin/cybra_watchdog" stop; read -r _ ;;
        4) "$HOME/CYBRA/bin/cybra_watchdog" once; read -r _ ;;
    esac
}


action_boot() {
    "$HOME/CYBRA/bin/cybra_boot"
    read -r _
}


action_web() {
    printf '  [1] Status\n'
    printf '  [2] Start (фон)\n'
    printf '  [3] Stop\n'
    printf '  [4] Restart\n'
    printf 'Вибір: '
    read -r w
    case "$w" in
        1) "$HOME/CYBRA/bin/cybra_web" status; read -r _ ;;
        2) "$HOME/CYBRA/bin/cybra_web" start; read -r _ ;;
        3) "$HOME/CYBRA/bin/cybra_web" stop; read -r _ ;;
        4) "$HOME/CYBRA/bin/cybra_web" restart; read -r _ ;;
    esac
}

action_export() {
    printf 'Файл [~/cybra_export.tar.gz]: '
    read -r OUT
    [ -z "$OUT" ] && OUT="$HOME/cybra_export.tar.gz"
    "$HOME/CYBRA/bin/cybra_export" "$OUT"
    read -r _
}

action_import() {
    printf 'Файл архіву: '
    read -r IN
    [ -z "$IN" ] && return
    "$HOME/CYBRA/bin/cybra_import" "$IN"
    read -r _
}



# ═══ SYSTEM (76-79) ═══
action_metrics() {
    "$HOME/CYBRA/bin/cybra_metrics" -v 2>&1 | head -40
    read -r _
}

action_http() {
    printf '  [1] Status\n'
    printf '  [2] Start (фон)\n'
    printf '  [3] Stop\n'
    printf '  [4] Test\n'
    printf 'Вибір: '
    read -r h
    case "$h" in
        1) "$HOME/CYBRA/bin/cybra_http" status 2>&1; read -r _ ;;
        2) "$HOME/CYBRA/bin/cybra_http" start 2>&1; read -r _ ;;
        3) "$HOME/CYBRA/bin/cybra_http" stop 2>&1; read -r _ ;;
        4) "$HOME/CYBRA/bin/cybra_http" test 2>&1; read -r _ ;;
    esac
}

action_schedule() {
    printf '  [1] Status\n'
    printf '  [2] Start\n'
    printf '  [3] Stop\n'
    printf '  [4] List rules\n'
    printf 'Вибір: '
    read -r sc
    case "$sc" in
        1) "$HOME/CYBRA/bin/cybra_schedule" status 2>&1; read -r _ ;;
        2) "$HOME/CYBRA/bin/cybra_schedule" start 2>&1; read -r _ ;;
        3) "$HOME/CYBRA/bin/cybra_schedule" stop 2>&1; read -r _ ;;
        4) "$HOME/CYBRA/bin/cybra_schedule" list 2>&1; read -r _ ;;
    esac
}

action_cleanup() {
    "$HOME/CYBRA/bin/cybra_cleanup" 2>&1
    read -r _
}

action_binmix() {
    printf '  [1] Status\n'
    printf '  [2] Start\n'
    printf '  [3] Stop\n'
    printf '  [4] Snapshot\n'
    printf '  [5] Chain\n'
    printf '  [6] Log\n'
    printf 'Вибір: '
    read -r bm
    case "$bm" in
        1) "$HOME/CYBRA/bin/cybra_binmix" status 2>&1; read -r _ ;;
        2) "$HOME/CYBRA/bin/cybra_binmix" start 2>&1; read -r _ ;;
        3) "$HOME/CYBRA/bin/cybra_binmix" stop 2>&1; read -r _ ;;
        4) "$HOME/CYBRA/bin/cybra_binmix" snapshot 2>&1; read -r _ ;;
        5) "$HOME/CYBRA/bin/cybra_binmix" chain 2>&1; read -r _ ;;
        6) "$HOME/CYBRA/bin/cybra_binmix" log 2>&1 | tail -15; read -r _ ;;
    esac
}

action_hash_eco() {
    printf '  [1] Run (5 layers)\n'
    printf '  [2] List snapshots\n'
    printf '  [3] Push\n'
    printf '  [4] Cleanup\n'
    printf 'Вибір: '
    read -r he
    case "$he" in
        1) "$HOME/CYBRA/cybra_hash.sh" layers 2>&1; read -r _ ;;
        2) "$HOME/CYBRA/cybra_hash.sh" list 2>&1 | head -20; read -r _ ;;
        3) "$HOME/CYBRA/cybra_hash.sh" push 2>&1; read -r _ ;;
        4) "$HOME/CYBRA/cybra_hash.sh" cleanup 2>&1; read -r _ ;;
    esac
}

action_node() {
    printf '  [1] Check\n'
    printf '  [2] Fix\n'
    printf '  [3] Test\n'
    printf '  [4] Sync\n'
    printf '  [5] Push\n'
    printf '  [6] Run all\n'
    printf 'Вибір: '
    read -r nd
    case "$nd" in
        1) "$HOME/CYBRA/cybra_node.sh" check 2>&1; read -r _ ;;
        2) "$HOME/CYBRA/cybra_node.sh" fix 2>&1; read -r _ ;;
        3) "$HOME/CYBRA/cybra_node.sh" test 2>&1; read -r _ ;;
        4) "$HOME/CYBRA/cybra_node.sh" sync 2>&1; read -r _ ;;
        5) "$HOME/CYBRA/cybra_node.sh" push 2>&1; read -r _ ;;
        6) "$HOME/CYBRA/cybra_node.sh" run 2>&1; read -r _ ;;
    esac
}


action_autopilot() {
    printf '  [1] Status\n'
    printf '  [2] Start (фон)\n'
    printf '  [3] Stop\n'
    printf '  [4] One cycle\n'
    printf '  [5] Log\n'
    printf 'Вибір: '
    read -r ap
    case "$ap" in
        1) "$HOME/CYBRA/bin/cybra_autopilot" status 2>&1; read -r _ ;;
        2) "$HOME/CYBRA/bin/cybra_autopilot" start 2>&1; read -r _ ;;
        3) "$HOME/CYBRA/bin/cybra_autopilot" stop 2>&1; read -r _ ;;
        4) "$HOME/CYBRA/bin/cybra_autopilot" once 2>&1; read -r _ ;;
        5) tail -30 "$HOME/CYBRA/logs/autopilot.log" 2>/dev/null; read -r _ ;;
    esac
}


while true; do
    print_header
    print_menu
    printf '  Вибір: '
    read -r CHOICE

    case "$CHOICE" in
        1) action_create_contract ;;
        2) action_list_contracts ;;
        3) action_show_status ;;
        4) action_generate_links ;;
        5) action_confirm_link ;;
        6) action_debug ;;
        7) action_dual_license_ledger ;;
        8) action_creation_license ;;
        9) action_hardening ;;
        11) action_create_invoice ;;
        12) action_add_line ;;
        13) action_show_invoice ;;
        14) action_finalize_invoice ;;
        15) action_export_masked ;;
        16) action_export_all_masked ;;
        17) action_verify_pii ;;
        18) action_buyer_final_decision ;;
        19) action_check_timeouts ;;
        20) action_refund_status ;;
        21) action_add_term ;;
        22) action_show_rates ;;
        23) action_update_rate ;;
        24) action_convert ;;
        30) action_preflight ;;
        31) action_self_heal ;;
        32) action_dual_verify ;;
        33) action_ownership ;;
        40) action_ai_review ;;
        41) action_ai_parse ;;
        42) action_ai_terms ;;
        43) action_ai_help ;;
        44) action_ai_ask ;;
        45) action_ai_taskbar ;;
        46) action_ai_exec_full ;;
        47) action_ai_exec_scan ;;
        48) action_ai_exec_apply ;;
        49) action_ai_exec_list ;;
        50) action_addr_add ;;
        51) action_addr_list ;;
        52) action_addr_history ;;
        53) action_qr ;;
        54) action_tg_setup ;;
        55) action_tg_test ;;
        56) action_wh_list ;;
        57) action_wh_add ;;
        58) action_exp_csv ;;
        59) action_exp_ledger ;;
        60) action_exp_report ;;
        61) action_bk_local ;;
        62) action_bk_cloud ;;
        63) action_chains ;;
        64) action_scan_tx ;;
        65) action_dp_open ;;
        66) action_dp_list ;;
        67) action_dp_vote ;;
        68) action_audit_show ;;
        69) action_audit_verify ;;
        70) action_scan_photo ;;
        71) action_scan_ocr ;;
        72) action_scan_pdf ;;
        73) action_scan_full ;;
        74) action_search_contract ;;
        75) action_autofill_contract ;;
        76) action_ai_terms ;;
        77) action_check_payment ;;
        78) action_custom_terms ;;
        88) action_metrics ;;
        89) action_http ;;
        90) action_schedule ;;
        87) action_cleanup ;;
        80) action_gd_state ;;
        81) action_gd_100 ;;
        82) action_gd_register ;;
        83) action_gd_show ;;
        84) action_gd_verify ;;
        85) action_gd_device ;;
        86) action_gd_snapshot ;;
        87) action_gd_restore_git ;;
        88) action_gd_restore_snap ;;
        89) action_gd_auto ;;
        90) action_gd_actions ;;
        91) action_gd_log_verify ;;
        92) action_as_save ;;
        93) action_as_status ;;
        94) action_as_recent ;;
        95) action_as_restore ;;
        96) action_evo7 ;;
        97) action_evo_ctl ;;
        98) action_parawatch ;;
        99) action_autopatch_menu ;;
        100) action_node ;;
        101) action_hash_eco ;;
        102) action_binmix ;;
        103) action_metrics ;;
        104) action_http ;;
        105) action_schedule ;;
        106) action_cleanup ;;
        107) action_autopilot ;;


        320) bash "$HOME/CYBRA/modules/module_320_controllers/main.sh" ;;
        330) bash "$HOME/CYBRA/modules/module_330_selfheal/main.sh" ;;
        340) bash "$HOME/CYBRA/modules/module_340_payment_confirm/main.sh" ;;
        341) bash "$HOME/CYBRA/modules/module_341_dual_confirm/main.sh" ;;
        350) bash "$HOME/CYBRA/modules/module_350_controller_worker/main.sh" ;;
        360) bash "$HOME/CYBRA/modules/module_360_mapping/main.sh" ;;
        370) bash "$HOME/CYBRA/modules/module_370_runtime/main.sh" ;;
        371) bash "$HOME/CYBRA/modules/module_371_job_controller/main.sh" ;;
        380) bash "$HOME/CYBRA/modules/module_380_sic/main.sh" ;;
        390) bash "$HOME/CYBRA/modules/module_390_src/main.sh" ;;
        395) bash "$HOME/CYBRA/modules/module_395_structure/main.sh" ;;
        396) bash "$HOME/CYBRA/modules/module_396_diffrecover/main.sh" ;;
        397) bash "$HOME/CYBRA/modules/module_397_load/main.sh" ;;
        398) bash "$HOME/CYBRA/modules/module_398_webui/main.sh" ;;
        399) bash "$HOME/CYBRA/modules/module_399_gate/main.sh" ;;
        401) bash "$HOME/CYBRA/modules/module_401_cascade_verify/main.sh" ;;
        402) bash "$HOME/CYBRA/modules/module_402_menu_doctor/main.sh" ;;
        405) bash "$HOME/CYBRA/modules/module_405_task_engine/main.sh" ;;
        0|q|Q|exit|quit)
            printf '%s\n' "${C_GREEN}До побачення.${C_RESET}"
            exit 0
            ;;
        *)
            printf '%s\n' "${C_RED}Невідома опція: $CHOICE${C_RESET}"
            sleep 1
            ;;
    esac
done


# ── Заглушки (auto-added) ──
action_add_line() { echo "⚠ action_add_line: not implemented"; }
action_add_term() { echo "⚠ action_add_term: not implemented"; }
action_addr_add() { echo "⚠ action_addr_add: not implemented"; }
action_addr_history() { echo "⚠ action_addr_history: not implemented"; }
action_addr_list() { echo "⚠ action_addr_list: not implemented"; }
action_ai_ask() { echo "⚠ action_ai_ask: not implemented"; }
action_ai_exec_apply() { echo "⚠ action_ai_exec_apply: not implemented"; }
action_ai_exec_full() { echo "⚠ action_ai_exec_full: not implemented"; }
action_ai_exec_list() { echo "⚠ action_ai_exec_list: not implemented"; }
action_ai_exec_scan() { echo "⚠ action_ai_exec_scan: not implemented"; }
action_ai_help() { echo "⚠ action_ai_help: not implemented"; }
action_ai_parse() { echo "⚠ action_ai_parse: not implemented"; }
action_ai_review() { echo "⚠ action_ai_review: not implemented"; }
action_ai_taskbar() { echo "⚠ action_ai_taskbar: not implemented"; }
action_ai_terms() { echo "⚠ action_ai_terms: not implemented"; }
action_as_recent() { echo "⚠ action_as_recent: not implemented"; }
action_as_restore() { echo "⚠ action_as_restore: not implemented"; }
action_as_save() { echo "⚠ action_as_save: not implemented"; }
action_as_status() { echo "⚠ action_as_status: not implemented"; }
action_audit_show() { echo "⚠ action_audit_show: not implemented"; }
action_audit_verify() { echo "⚠ action_audit_verify: not implemented"; }
action_autofill_contract() { echo "⚠ action_autofill_contract: not implemented"; }
action_autopatch_menu() { echo "⚠ action_autopatch_menu: not implemented"; }
action_autopilot() { echo "⚠ action_autopilot: not implemented"; }
action_binmix() { echo "⚠ action_binmix: not implemented"; }
action_bk_cloud() { echo "⚠ action_bk_cloud: not implemented"; }
action_bk_local() { echo "⚠ action_bk_local: not implemented"; }
action_buyer_final_decision() { echo "⚠ action_buyer_final_decision: not implemented"; }
action_chains() { echo "⚠ action_chains: not implemented"; }
action_check_payment() { echo "⚠ action_check_payment: not implemented"; }
action_check_timeouts() { echo "⚠ action_check_timeouts: not implemented"; }
action_cleanup() { echo "⚠ action_cleanup: not implemented"; }
action_confirm_link() { echo "⚠ action_confirm_link: not implemented"; }
action_convert() { echo "⚠ action_convert: not implemented"; }
action_create_contract() { echo "⚠ action_create_contract: not implemented"; }
action_create_invoice() { echo "⚠ action_create_invoice: not implemented"; }
action_creation_license() { echo "⚠ action_creation_license: not implemented"; }
action_custom_terms() { echo "⚠ action_custom_terms: not implemented"; }
action_debug() { echo "⚠ action_debug: not implemented"; }
action_dp_list() { echo "⚠ action_dp_list: not implemented"; }
action_dp_open() { echo "⚠ action_dp_open: not implemented"; }
action_dp_vote() { echo "⚠ action_dp_vote: not implemented"; }
action_dual_license_ledger() { echo "⚠ action_dual_license_ledger: not implemented"; }
action_dual_verify() { echo "⚠ action_dual_verify: not implemented"; }
action_evo() { echo "⚠ action_evo: not implemented"; }
action_evo_ctl() { echo "⚠ action_evo_ctl: not implemented"; }
action_exp_csv() { echo "⚠ action_exp_csv: not implemented"; }
action_exp_ledger() { echo "⚠ action_exp_ledger: not implemented"; }
action_exp_report() { echo "⚠ action_exp_report: not implemented"; }
action_export_all_masked() { echo "⚠ action_export_all_masked: not implemented"; }
action_export_masked() { echo "⚠ action_export_masked: not implemented"; }
action_finalize_invoice() { echo "⚠ action_finalize_invoice: not implemented"; }
action_gd_() { echo "⚠ action_gd_: not implemented"; }
action_gd_actions() { echo "⚠ action_gd_actions: not implemented"; }
action_gd_auto() { echo "⚠ action_gd_auto: not implemented"; }
action_gd_device() { echo "⚠ action_gd_device: not implemented"; }
action_gd_log_verify() { echo "⚠ action_gd_log_verify: not implemented"; }
action_gd_register() { echo "⚠ action_gd_register: not implemented"; }
action_gd_restore_git() { echo "⚠ action_gd_restore_git: not implemented"; }
action_gd_restore_snap() { echo "⚠ action_gd_restore_snap: not implemented"; }
action_gd_show() { echo "⚠ action_gd_show: not implemented"; }
action_gd_snapshot() { echo "⚠ action_gd_snapshot: not implemented"; }
action_gd_state() { echo "⚠ action_gd_state: not implemented"; }
action_gd_verify() { echo "⚠ action_gd_verify: not implemented"; }
action_generate_links() { echo "⚠ action_generate_links: not implemented"; }
action_hardening() { echo "⚠ action_hardening: not implemented"; }
action_hash_eco() { echo "⚠ action_hash_eco: not implemented"; }
action_http() { echo "⚠ action_http: not implemented"; }
action_list_contracts() { echo "⚠ action_list_contracts: not implemented"; }
action_metrics() { echo "⚠ action_metrics: not implemented"; }
action_node() { echo "⚠ action_node: not implemented"; }
action_ownership() { echo "⚠ action_ownership: not implemented"; }
action_parawatch() { echo "⚠ action_parawatch: not implemented"; }
action_preflight() { echo "⚠ action_preflight: not implemented"; }
action_qr() { echo "⚠ action_qr: not implemented"; }
action_refund_status() { echo "⚠ action_refund_status: not implemented"; }
action_scan_full() { echo "⚠ action_scan_full: not implemented"; }
action_scan_ocr() { echo "⚠ action_scan_ocr: not implemented"; }
action_scan_pdf() { echo "⚠ action_scan_pdf: not implemented"; }
action_scan_photo() { echo "⚠ action_scan_photo: not implemented"; }
action_scan_tx() { echo "⚠ action_scan_tx: not implemented"; }
action_schedule() { echo "⚠ action_schedule: not implemented"; }
action_search_contract() { echo "⚠ action_search_contract: not implemented"; }
action_self_heal() { echo "⚠ action_self_heal: not implemented"; }
action_show_invoice() { echo "⚠ action_show_invoice: not implemented"; }
action_show_rates() { echo "⚠ action_show_rates: not implemented"; }
action_show_status() { echo "⚠ action_show_status: not implemented"; }
action_tg_setup() { echo "⚠ action_tg_setup: not implemented"; }
action_tg_test() { echo "⚠ action_tg_test: not implemented"; }
action_update_rate() { echo "⚠ action_update_rate: not implemented"; }
action_verify_pii() { echo "⚠ action_verify_pii: not implemented"; }
action_wh_add() { echo "⚠ action_wh_add: not implemented"; }
action_wh_list() { echo "⚠ action_wh_list: not implemented"; }
