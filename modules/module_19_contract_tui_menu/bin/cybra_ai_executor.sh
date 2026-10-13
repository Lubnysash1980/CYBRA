#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# CYBRA AI EXECUTOR
# Аналізує систему → пропонує еволюцію → застосовує (safe only)
# ============================================================

set -u
export LC_ALL=C

ROOT="$HOME/CYBRA"
MODULES="$ROOT/modules"
BASELINE="$ROOT/baseline"
EVO_DIR="$ROOT/evolution"
AI_DIR="$ROOT/ai"
EVO_SUGGESTIONS="$AI_DIR/evolution/suggestions"
EVO_APPLIED="$AI_DIR/evolution/applied"
EVO_LOG="$AI_DIR/evolution/evolution.log"

mkdir -p "$EVO_SUGGESTIONS" "$EVO_APPLIED" "$AI_DIR/evolution"

# --- Кольори ---
if [ -t 1 ]; then
    R=$'\033[31m'; G=$'\033[32m'; Y=$'\033[33m'
    B=$'\033[1m'; C=$'\033[36m'; M=$'\033[35m'; Z=$'\033[0m'
else
    R=""; G=""; Y=""; B=""; C=""; M=""; Z=""
fi

ai_evo_log() {
    printf '%s | %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >> "$EVO_LOG"
}

# ============================================================
# SYSTEM SCAN
# ============================================================

scan_system() {
    local score=0

    printf '%s═══ SYSTEM SCAN ═══%s\n\n' "$B$C" "$Z"

    # --- Modules ---
    local mod_count=0
    for d in "$MODULES"/*/; do
        [ -d "$d" ] || continue
        m="$(basename "$d")"
        case "$m" in @*|.*|_disabled*|evolution|answer_engine|node_modules) continue ;; esac
        mod_count=$((mod_count+1))
    done
    printf '  Modules:           %s\n' "$mod_count"
    score=$((score + mod_count))

    # --- Contracts ---
    local contract_count=0
    local contracts_dir="$MODULES/module_19_contract_tui_menu/contracts"
    [ -d "$contracts_dir" ] && contract_count="$(find "$contracts_dir" -name '*.env' 2>/dev/null | wc -l | tr -d ' ')"
    printf '  Contracts:         %s\n' "$contract_count"

    # --- Links ---
    local link_count=0
    local links_dir="$MODULES/module_19_contract_tui_menu/links"
    [ -d "$links_dir" ] && link_count="$(find "$links_dir" -name '*.link' 2>/dev/null | wc -l | tr -d ' ')"
    printf '  Links:             %s\n' "$link_count"

    # --- Ledgers ---
    local ledgers=0
    for l in license_ledger license_ledger_b creation_license_ledger refund_ledger; do
        [ -f "$MODULES/module_19_contract_tui_menu/evidence/$l.txt" ] && ledgers=$((ledgers+1))
    done
    printf '  Ledgers:           %s\n' "$ledgers"

    # --- Tests ---
    local tests_found=0
    for d in "$MODULES"/*/; do
        [ -d "$d" ] || continue
        [ -f "$d/tests/run_tests.sh" ] && tests_found=$((tests_found+1))
    done
    printf '  Test runners:      %s\n' "$tests_found"

    # --- AI ---
    local ai_modules=0
    [ -f "$MODULES/module_19_contract_tui_menu/bin/cybra_local_ai.sh" ] && ai_modules=$((ai_modules+1))
    [ -f "$ROOT/CYBRA_AI_TASK_BAR.sh" ] && ai_modules=$((ai_modules+1))
    printf '  AI modules:        %s\n' "$ai_modules"

    # --- Freeze state ---
    local frozen=NO
    [ -f "$EVO_DIR/FROZEN" ] && frozen=YES
    printf '  Frozen:            %s\n' "$frozen"

    # --- Rates ---
    local rates=0
    [ -f "$MODULES/module_19_contract_tui_menu/state/rates.env" ] && rates=1
    printf '  Rates system:      %s\n' "$rates"

    printf '\n'
    printf '  System score: %s\n' "$score"
    printf '  Scan ID:      %s\n' "$(date -u +%Y%m%dT%H%M%SZ)"
    printf '\n'

    # --- Експорт у файл ---
    {
        printf 'MODULES=%s\n' "$mod_count"
        printf 'CONTRACTS=%s\n' "$contract_count"
        printf 'LINKS=%s\n' "$link_count"
        printf 'LEDGERS=%s\n' "$ledgers"
        printf 'TESTS=%s\n' "$tests_found"
        printf 'AI=%s\n' "$ai_modules"
        printf 'FROZEN=%s\n' "$frozen"
        printf 'SCORE=%s\n' "$score"
    } > "$AI_DIR/evolution/last_scan.env"

    return 0
}

# ============================================================
# SUGGESTIONS ENGINE — список можливих еволюцій
# ============================================================

suggest_evolutions() {
    printf '%s═══ EVOLUTION SUGGESTIONS ═══%s\n\n' "$B$C" "$Z"

    source "$AI_DIR/evolution/last_scan.env"

    local suggestions_count=0

    # --- 1. Модуль для fiat-payments ---
    if [ ! -d "$MODULES/module_21_fiat_gateway" ]; then
        cat > "$EVO_SUGGESTIONS/module_21_fiat_gateway.txt" <<SUG
NAME: module_21_fiat_gateway
TYPE: FEATURE
PRIORITY: MEDIUM
RISK: LOW
DESC: Шлюз для прийому фіатних платежів (UAH/USD/EUR)
      через сторонніх провайдерів (LiqPay, Fondy, Stripe).
      Покупець платить фіатом, CYBRA конвертує в токени через oracles.
IMPACT: +30% usability для не-крипто користувачів
DEPENDS: module_19 (TUI), module_20 (Evolution Guard)
SAFE: TRUE — не руйнує існуюче, додає новий шар
SUG
        printf '  %s[+%s]%s module_21_fiat_gateway — фіатні платежі%s\n' "$G" "1" "$Z" "$C" "$Z"
        printf '      %sPriority: MEDIUM | Risk: LOW%s\n' "$Y" "$Z"
        suggestions_count=$((suggestions_count+1))
    fi

    # --- 2. Notification system ---
    if [ ! -d "$MODULES/module_22_notifications" ]; then
        cat > "$EVO_SUGGESTIONS/module_22_notifications.txt" <<SUG
NAME: module_22_notifications
TYPE: FEATURE
PRIORITY: HIGH
RISK: LOW
DESC: Система повідомлень через Telegram/Email/SMS.
      Сповіщає покупця/продавця про:
      - створення контракту
      - новий лінк для підтвердження
      - наближення timeout (48h, 24h, 12h, 1h)
      - refund
IMPACT: +50% response rate
DEPENDS: module_19 (TUI), module_18 (license)
SAFE: TRUE — additive
SUG
        printf '  %s[+%s]%s module_22_notifications — сповіщення%s\n' "$G" "2" "$Z" "$C" "$Z"
        printf '      %sPriority: HIGH | Risk: LOW%s\n' "$Y" "$Z"
        suggestions_count=$((suggestions_count+1))
    fi

    # --- 3. Dispute resolver ---
    if [ ! -d "$MODULES/module_23_dispute_resolver" ]; then
        cat > "$EVO_SUGGESTIONS/module_23_dispute_resolver.txt" <<SUG
NAME: module_23_dispute_resolver
TYPE: FEATURE
PRIORITY: HIGH
RISK: MEDIUM
DESC: Механізм вирішення спорів:
      - арбітр (3rd party)
      - multi-sig (2 з 3)
      - голосування сторін
      - time-locked escrow
IMPACT: +80% trust для великих сум
DEPENDS: module_03 (escrow)
SAFE: TRUE — не руйнує існуючий flow
SUG
        printf '  %s[+%s]%s module_23_dispute_resolver — вирішення спорів%s\n' "$G" "3" "$Z" "$C" "$Z"
        printf '      %sPriority: HIGH | Risk: MEDIUM%s\n' "$Y" "$Z"
        suggestions_count=$((suggestions_count+1))
    fi

    # --- 4. Multi-token support ---
    local tokens_supported=0
    grep -rl 'TOKEN=' "$MODULES/module_19_contract_tui_menu/contracts" 2>/dev/null | head -1 >/dev/null && tokens_supported=1
    if [ "$tokens_supported" -eq 1 ] && [ ! -f "$MODULES/module_19_contract_tui_menu/state/tokens.registry" ]; then
        cat > "$EVO_SUGGESTIONS/tokens_registry.txt" <<SUG
NAME: tokens_registry
TYPE: ENHANCEMENT
PRIORITY: MEDIUM
RISK: LOW
DESC: Реєстр підтримуваних токенів з decimals:
      - USDT (BEP-20): 0x55d3..., decimals=18
      - BUSD: 0xe9e7..., decimals=18
      - WBTC: 0x7130..., decimals=8
      - CAKE: 0x0e09..., decimals=18
      Автоматично підставляє decimals у TUI.
IMPACT: усуває ручне введення decimals
DEPENDS: module_19
SAFE: TRUE — additive
SUG
        printf '  %s[+%s]%s tokens_registry — реєстр токенів%s\n' "$G" "4" "$Z" "$C" "$Z"
        printf '      %sPriority: MEDIUM | Risk: LOW%s\n' "$Y" "$Z"
        suggestions_count=$((suggestions_count+1))
    fi

    # --- 5. Auto-backup ---
    if [ ! -f "$ROOT/bin/cybra_auto_backup.sh" ]; then
        cat > "$EVO_SUGGESTIONS/auto_backup.txt" <<SUG
NAME: cybra_auto_backup
TYPE: SAFETY
PRIORITY: HIGH
RISK: LOW
DESC: Автоматичний backup всієї CYBRA системи:
      - daily tar.gz архів
      - 30 днів ротації
      - SHA-256 integrity
      - відновлення однією командою
IMPACT: захист від втрати даних
DEPENDS: none
SAFE: TRUE — additive
SUG
        printf '  %s[+%s]%s cybra_auto_backup — автоматичний backup%s\n' "$G" "5" "$Z" "$C" "$Z"
        printf '      %sPriority: HIGH | Risk: LOW%s\n' "$Y" "$Z"
        suggestions_count=$((suggestions_count+1))
    fi

    # --- 6. Contract templates ---
    if [ ! -d "$MODULES/module_19_contract_tui_menu/templates" ]; then
        cat > "$EVO_SUGGESTIONS/contract_templates.txt" <<SUG
NAME: contract_templates
TYPE: ENHANCEMENT
PRIORITY: MEDIUM
RISK: LOW
DESC: Шаблони контрактів:
      - типовий купівля-продаж
      - оренда
      - послуги
      - підписка
      Користувач обирає шаблон → TUI заповнює поля
IMPACT: -70% часу на створення
DEPENDS: module_19
SAFE: TRUE — additive
SUG
        printf '  %s[+%s]%s contract_templates — шаблони контрактів%s\n' "$G" "6" "$Z" "$C" "$Z"
        printf '      %sPriority: MEDIUM | Risk: LOW%s\n' "$Y" "$Z"
        suggestions_count=$((suggestions_count+1))
    fi

    # --- 7. Analytics dashboard ---
    if [ ! -d "$MODULES/module_24_analytics" ]; then
        cat > "$EVO_SUGGESTIONS/analytics.txt" <<SUG
NAME: module_24_analytics
TYPE: FEATURE
PRIORITY: MEDIUM
RISK: LOW
DESC: Аналітика в реальному часі:
      - кількість контрактів/день
      - оборот/тиждень/місяць
      - топ-контрагенти
      - середня сума
      - conversion rate
      - chart/графіки в терміналі
IMPACT: business intelligence
DEPENDS: module_19
SAFE: TRUE — read-only
SUG
        printf '  %s[+%s]%s module_24_analytics — аналітика%s\n' "$G" "7" "$Z" "$C" "$Z"
        printf '      %sPriority: MEDIUM | Risk: LOW%s\n' "$Y" "$Z"
        suggestions_count=$((suggestions_count+1))
    fi

    # --- 8. Multi-language ---
    if [ ! -f "$MODULES/module_19_contract_tui_menu/state/i18n.env" ]; then
        cat > "$EVO_SUGGESTIONS/i18n.txt" <<SUG
NAME: i18n_support
TYPE: ENHANCEMENT
PRIORITY: LOW
RISK: LOW
DESC: Мульти-мова TUI:
      - UA (default)
      - EN
      - RU
      - PL
      Автоматично обирає за LANG
IMPACT: global reach
DEPENDS: module_19
SAFE: TRUE — additive
SUG
        printf '  %s[+%s]%s i18n_support — мульти-мова%s\n' "$G" "8" "$Z" "$C" "$Z"
        printf '      %sPriority: LOW | Risk: LOW%s\n' "$Y" "$Z"
        suggestions_count=$((suggestions_count+1))
    fi

    # --- 9. QR codes ---
    if [ ! -f "$MODULES/module_19_contract_tui_menu/bin/cybra_qr.sh" ]; then
        cat > "$EVO_SUGGESTIONS/qr_codes.txt" <<SUG
NAME: qr_codes
TYPE: UX
PRIORITY: MEDIUM
RISK: LOW
DESC: Генерація QR-кодів для посилань:
      - BUYER лінк → QR
      - SELLER лінк → QR
      - RECEIPT лінк → QR
      Сканування телефоном → підтвердження
IMPACT: швидше підтвердження
DEPENDS: module_19
SAFE: TRUE — additive
SUG
        printf '  %s[+%s]%s qr_codes — QR-коди для лінків%s\n' "$G" "9" "$Z" "$C" "$Z"
        printf '      %sPriority: MEDIUM | Risk: LOW%s\n' "$Y" "$Z"
        suggestions_count=$((suggestions_count+1))
    fi

    # --- 10. Automated test coverage ---
    local cover=0
    for d in "$MODULES"/*/; do
        [ -d "$d" ] || continue
        [ -f "$d/tests/run_tests.sh" ] && cover=$((cover+1))
    done
    if [ "$cover" -lt 12 ]; then
        cat > "$EVO_SUGGESTIONS/test_coverage.txt" <<SUG
NAME: test_coverage_expansion
TYPE: QUALITY
PRIORITY: HIGH
RISK: LOW
DESC: Розширити test coverage:
      - деякі модулі без self-tests
      - додати edge cases
      - додати integration tests
      - fuzzing для input validation
IMPACT: +stability
DEPENDS: all modules
SAFE: TRUE — additive
SUG
        printf '  %s[+%s]%s test_coverage — більше тестів%s\n' "$G" "10" "$Z" "$C" "$Z"
        printf '      %sPriority: HIGH | Risk: LOW%s\n' "$Y" "$Z"
        suggestions_count=$((suggestions_count+1))
    fi

    printf '\n'
    printf '  Всього suggestions: %s\n' "$suggestions_count"
    printf '  Збережено у: %s\n' "$EVO_SUGGESTIONS"
    printf '\n'

    return 0
}

# ============================================================
# APPLY EVOLUTION — тільки безпечні (SAFE=TRUE)
# ============================================================

apply_safe_evolutions() {
    printf '%s═══ APPLY SAFE EVOLUTIONS ═══%s\n\n' "$B$C" "$Z"

    local applied=0
    local skipped=0

    for s in "$EVO_SUGGESTIONS"/*.txt; do
        [ -f "$s" ] || continue
        local name="$(basename "$s" .txt)"

        # Перевіряємо чи вже applied
        [ -f "$EVO_APPLIED/${name}.applied" ] && { skipped=$((skipped+1)); continue; }

        # Перевіряємо SAFE=TRUE
        if ! grep -q '^SAFE: TRUE' "$s"; then
            printf '  %s[SKIP]%s %s — не safe\n' "$Y" "$Z" "$name"
            skipped=$((skipped+1))
            continue
        fi

        printf '  %s[APPLY]%s %s\n' "$G" "$Z" "$name"

        case "$name" in
            tokens_registry)
                # Створюємо реєстр токенів
                cat > "$MODULES/module_19_contract_tui_menu/state/tokens.registry" <<'TOK'
# CYBRA TOKEN REGISTRY
# формат: SYMBOL|ADDRESS|DECIMALS|CHAIN
USDT|0x55d398326f99059fF775485246999027B3197955|18|BSC
BUSD|0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56|18|BSC
WBNB|0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c|18|BSC
WBTC|0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c|8|BSC
CAKE|0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82|18|BSC
ETH|0x2170Ed0880ac9A755fd29B2688956BD959F933F8|18|BSC
BTCB|0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c|18|BSC
TOK
                printf '    → tokens.registry створено\n'
                ;;
            auto_backup)
                # Створюємо скрипт backup
                cat > "$ROOT/bin/cybra_auto_backup.sh" <<'BK'
#!/data/data/com.termux/files/usr/bin/bash
# CYBRA AUTO BACKUP
ROOT="$HOME/CYBRA"
BK_DIR="$ROOT/backups"
mkdir -p "$BK_DIR"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
ARCHIVE="$BK_DIR/cybra_${STAMP}.tar.gz"
tar -czf "$ARCHIVE" \
    -C "$(dirname "$ROOT")" \
    --exclude='*/node_modules' \
    --exclude='*/backups' \
    --exclude='*/.git' \
    "$(basename "$ROOT")" 2>/dev/null
sha256sum "$ARCHIVE" > "$ARCHIVE.sha256"
# Ротація: залишаємо 30 останніх
ls -t "$BK_DIR"/cybra_*.tar.gz 2>/dev/null | tail -n +31 | xargs -r rm -f
ls -t "$BK_DIR"/cybra_*.tar.gz.sha256 2>/dev/null | tail -n +31 | xargs -r rm -f
printf 'Backup: %s\n' "$ARCHIVE"
printf 'Size:   %s\n' "$(du -h "$ARCHIVE" | cut -f1)"
printf 'Hash:   %s\n' "$(cat "$ARCHIVE.sha256" | awk '{print $1}' | head -c 16)..."
BK
                chmod +x "$ROOT/bin/cybra_auto_backup.sh"
                printf '    → cybra_auto_backup.sh створено\n'
                ;;
            contract_templates)
                # Створюємо папку шаблонів
                TPL="$MODULES/module_19_contract_tui_menu/templates"
                mkdir -p "$TPL"
                cat > "$TPL/purchase.tpl" <<'TP'
TEMPLATE_NAME=purchase
DESCRIPTION=Типовий купівля-продаж
REQUIRED_FIELDS=BUYER,SELLER,AMOUNT,TOKEN
DEFAULT_VAT=20
DEFAULT_REFUND_HOURS=72
TP
                cat > "$TPL/services.tpl" <<'TP'
TEMPLATE_NAME=services
DESCRIPTION=Надання послуг
REQUIRED_FIELDS=BUYER,SELLER,AMOUNT,TOKEN,SERVICE_DESC
DEFAULT_VAT=20
DEFAULT_REFUND_HOURS=168
TP
                cat > "$TPL/rent.tpl" <<'TP'
TEMPLATE_NAME=rent
DESCRIPTION=Оренда
REQUIRED_FIELDS=BUYER,SELLER,AMOUNT,TOKEN,PERIOD
DEFAULT_VAT=20
DEFAULT_REFUND_HOURS=24
TP
                printf '    → templates/ створено (3 шаблони)\n'
                ;;
            i18n_support)
                # i18n файл
                cat > "$MODULES/module_19_contract_tui_menu/state/i18n.env" <<'I18N'
LANG_DEFAULT=uk
SUPPORTED_LANGS=uk,en,ru,pl
I18N
                printf '    → i18n.env створено\n'
                ;;
            qr_codes)
                # QR-генератор (заглушка)
                cat > "$MODULES/module_19_contract_tui_menu/bin/cybra_qr.sh" <<'QR'
#!/data/data/com.termux/files/usr/bin/bash
# QR генератор (для майбутньої реалізації)
cybra_qr_gen() {
    local text="$1"
    # Використовуємо qrencode якщо доступний
    if command -v qrencode >/dev/null 2>&1; then
        printf '%s' "$text" | qrencode -t ANSIUTF8
    else
        printf 'qrencode не встановлено.\n'
        printf 'Встанови: pkg install qrencode\n'
        printf 'Text: %s\n' "$text"
    fi
}
QR
                chmod +x "$MODULES/module_19_contract_tui_menu/bin/cybra_qr.sh"
                printf '    → cybra_qr.sh створено\n'
                ;;
            *)
                printf '    → generic apply\n'
                ;;
        esac

        # Позначаємо як applied
        printf '%s | applied at %s\n' "$name" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            > "$EVO_APPLIED/${name}.applied"
        ai_evo_log "APPLIED: $name"
        applied=$((applied+1))
    done

    printf '\n'
    printf '  Applied: %s\n' "$applied"
    printf '  Skipped: %s\n' "$skipped"
    printf '\n'

    return 0
}

# ============================================================
# EXECUTOR MAIN
# ============================================================

executor_run() {
    local mode="${1:-full}"

    printf '%s%s╔══════════════════════════════════════════════════╗%s\n' "$B" "$C" "$Z"
    printf '%s%s║        CYBRA AI EXECUTOR v1.0                    ║%s\n' "$B" "$C" "$Z"
    printf '%s%s║        Автономний аналіз + еволюція              ║%s\n' "$B" "$C" "$Z"
    printf '%s%s╚══════════════════════════════════════════════════╝%s\n' "$B" "$C" "$Z"
    printf '\n'

    scan_system
    suggest_evolutions

    case "$mode" in
        full|apply)
            apply_safe_evolutions
            ;;
        scan)
            printf '  (режим scan — apply пропущено)\n'
            ;;
    esac

    printf '%s═══ EXECUTOR DONE ═══%s\n' "$B$C" "$Z"
    printf '  Log: %s\n' "$EVO_LOG"
    printf '  Suggestions: %s\n' "$EVO_SUGGESTIONS"
    printf '  Applied: %s\n' "$EVO_APPLIED"
    printf '\n'
}

# ============================================================
# CLI
# ============================================================

case "${1:-full}" in
    scan)    executor_run scan ;;
    full)    executor_run full ;;
    apply)   executor_run apply ;;
    list)
        printf '=== SUGGESTIONS ===\n'
        ls -1 "$EVO_SUGGESTIONS" 2>/dev/null | sed 's/\.txt$//'
        printf '\n=== APPLIED ===\n'
        ls -1 "$EVO_APPLIED" 2>/dev/null | sed 's/\.applied$//'
        ;;
    log)
        cat "$EVO_LOG" 2>/dev/null || echo "(empty)"
        ;;
    *)
        printf 'Usage: cybra_ai_executor {full|scan|apply|list|log}\n'
        ;;
esac
