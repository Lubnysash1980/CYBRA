#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# CYBRA LOCAL AI — офлайн рушій без зовнішніх API
# Детермінований, швидкий, безкоштовний
# ============================================================

ROOT="$HOME/CYBRA"
MOD="$CYBRA_MOD19_ROOT"

# --- Кольори ---
if [ -t 1 ]; then
    R=$'\033[31m'; G=$'\033[32m'; Y=$'\033[33m'
    B=$'\033[1m'; C=$'\033[36m'; M=$'\033[35m'; Z=$'\033[0m'
else
    R=""; G=""; Y=""; B=""; C=""; M=""; Z=""
fi

# ============================================================
# 1. CONTRACT REVIEW — детермінований аналіз
# ============================================================

local_ai_review_contract() {
    local cid="$1"
    local f="$MOD/contracts/$cid.env"
    [ ! -f "$f" ] && { echo "ERROR: not found"; return 1; }

    printf '%s%s═══ AI REVIEW: %s ═══%s\n\n' "$B" "$C" "$cid" "$Z"

    # --- Витягуємо поля ---
    local buyer seller amount la lb cf total net token
    buyer="$(grep -m1 '^BUYER=' "$f" | cut -d= -f2-)"
    seller="$(grep -m1 '^SELLER=' "$f" | cut -d= -f2-)"
    amount="$(grep -m1 '^AMOUNT_WEI=' "$f" | cut -d= -f2-)"
    la="$(grep -m1 '^LICENSE_A_WEI=' "$f" | cut -d= -f2-)"
    lb="$(grep -m1 '^LICENSE_B_WEI=' "$f" | cut -d= -f2-)"
    cf="$(grep -m1 '^CREATION_FEE_WEI=' "$f" | cut -d= -f2-)"
    total="$(grep -m1 '^LICENSE_TOTAL_WEI=' "$f" | cut -d= -f2-)"
    net="$(grep -m1 '^NET_WEI=' "$f" | cut -d= -f2-)"
    token="$(grep -m1 '^TOKEN=' "$f" | cut -d= -f2-)"
    local stage="$(grep -m1 '^STAGE=' "$f" | cut -d= -f2-)"
    local decision="$(grep -m1 '^BUYER_FINAL_DECISION=' "$f" | cut -d= -f2-)"
    local refund_st="$(grep -m1 '^REFUND_STATUS=' "$f" | cut -d= -f2-)"

    local criticals=0
    local warns=0

    # --- 1. Сумісність сум ---
    printf '%s[1] ПЕРЕВІРКА СУМ%s\n' "$B" "$Z"
    if [ -n "$amount" ] && [ -n "$total" ] && [ -n "$net" ]; then
        local calc=$(( la + lb + cf ))
        if [ "$calc" = "$total" ]; then
            printf '  %s✓%s LICENSE_TOTAL = LICENSE_A + B + CREATION (%s)\n' "$G" "$Z" "$total"
        else
            printf '  %s✗%s LICENSE_TOTAL не співпадає: calc=%s stored=%s\n' "$R" "$Z" "$calc" "$total"
            criticals=$((criticals+1))
        fi

        local calc_net=$(( amount - total ))
        if [ "$calc_net" = "$net" ]; then
            printf '  %s✓%s NET = AMOUNT - LICENSE_TOTAL (%s)\n' "$G" "$Z" "$net"
        else
            printf '  %s✗%s NET не співпадає: calc=%s stored=%s\n' "$R" "$Z" "$calc_net" "$net"
            criticals=$((criticals+1))
        fi

        # Відсотки
        if [ "$amount" -gt 0 ]; then
            local pct_a=$(( la * 100 / amount ))
            local pct_total=$(( total * 100 / amount ))
            if [ "$pct_total" -eq 3 ]; then
                printf '  %s✓%s Total license = 3%% (A=%s%% B=%s%% creation=%s%%)\n' "$G" "$Z" "$pct_a" "$pct_a" "$pct_a"
            else
                printf '  %s⚠%s Total license = %s%% (очікується 3%%)\n' "$Y" "$Z" "$pct_total"
                warns=$((warns+1))
            fi
        fi
    fi

    # --- 2. Сторони ---
    printf '\n%s[2] СТОРОНИ%s\n' "$B" "$Z"
    if [ "$buyer" = "$seller" ]; then
        printf '  %s✗%s BUYER = SELLER (%s)\n' "$R" "$Z" "$buyer"
        criticals=$((criticals+1))
    elif [ -z "$buyer" ] || [ -z "$seller" ]; then
        printf '  %s✗%s порожній wallet\n' "$R" "$Z"
        criticals=$((criticals+1))
    else
        printf '  %s✓%s BUYER  = %s\n' "$G" "$Z" "${buyer:0:20}..."
        printf '  %s✓%s SELLER = %s\n' "$G" "$Z" "${seller:0:20}..."
    fi

    # --- 3. Token ---
    printf '\n%s[3] TOKEN%s\n' "$B" "$Z"
    if [ -z "$token" ] || [ "$token" = "BNB" ]; then
        printf '  %s⚠%s TOKEN = %s (не контракт BEP-20)\n' "$Y" "$Z" "${token:-EMPTY}"
    else
        if [[ "$token" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
            printf '  %s✓%s TOKEN = %s\n' "$G" "$Z" "$token"
        else
            printf '  %s✗%s TOKEN формат невірний: %s\n' "$R" "$Z" "$token"
            criticals=$((criticals+1))
        fi
    fi

    # --- 4. REFUND ---
    printf '\n%s[4] REFUND%s\n' "$B" "$Z"
    if [ -f "$f" ] && grep -qm1 '^REFUND_ENABLED=' "$f"; then
        printf '  %s✓%s REFUND_ENABLED=TRUE\n' "$G" "$Z"
        printf '  →  deadline: %s\n' "$(grep -m1 '^REFUND_DEADLINE=' "$f" | cut -d= -f2-)"
        printf '  →  decision: %s\n' "$decision"
        printf '  →  status:   %s\n' "$refund_st"
    else
        printf '  %s✗%s REFUND відсутній — критично!\n' "$R" "$Z"
        criticals=$((criticals+1))
    fi

    # --- 5. Ліцензія ---
    printf '\n%s[5] ЛІЦЕНЗІЯ%s\n' "$B" "$Z"
    local recipient_a recipient_b recipient_c
    recipient_a="$(grep -m1 '^LICENSE_A_RECIPIENT=' "$f" | cut -d= -f2-)"
    recipient_b="$(grep -m1 '^LICENSE_B_RECIPIENT=' "$f" | cut -d= -f2-)"
    recipient_c="$(grep -m1 '^CREATION_FEE_RECIPIENT=' "$f" | cut -d= -f2-)"
    local expected="0x66434c5501242ccC71b5a39C765892921624B66c"

    for pair in "A:$recipient_a" "B:$recipient_b" "C:$recipient_c"; do
        local label="${pair%%:*}"
        local addr="${pair#*:}"
        if [ "$addr" = "$expected" ]; then
            printf '  %s✓%s RECIPIENT_%s коректний\n' "$G" "$Z" "$label"
        elif [ -n "$addr" ]; then
            printf '  %s⚠%s RECIPIENT_%s = %s (не стандартний)\n' "$Y" "$Z" "$label" "${addr:0:20}"
            warns=$((warns+1))
        fi
    done

    # --- 6. Stage ---
    printf '\n%s[6] СТАН%s\n' "$B" "$Z"
    case "$stage" in
        DRAFT)       printf '  %s•%s DRAFT — контракт тільки створено\n' "$C" "$Z" ;;
        LINKED)      printf '  %s•%s LINKED — лінки згенеровано\n' "$C" "$Z" ;;
        BUYER_OK)    printf '  %s•%s BUYER_OK — покупець підтвердив\n' "$C" "$Z" ;;
        SELLER_OK)   printf '  %s•%s SELLER_OK — продавець підтвердив\n' "$C" "$Z" ;;
        RECEIPT_OK)  printf '  %s•%s RECEIPT_OK — отримання підтверджено\n' "$C" "$Z" ;;
        COMPLETE)    printf '  %s✓%s COMPLETE — угода завершена\n' "$G" "$Z" ;;
        REFUNDED)    printf '  %s•%s REFUNDED — кошти повернено\n' "$Y" "$Z" ;;
        *)           printf '  %s•%s %s\n' "$C" "$Z" "$stage" ;;
    esac

    # --- ПІДСУМОК ---
    printf '\n%s═══ ВИСНОВОК ═══%s\n' "$B" "$Z"
    if [ "$criticals" -eq 0 ] && [ "$warns" -eq 0 ]; then
        printf '  %s✓ КОНТРАКТ OK%s — всі перевірки пройдено\n' "$G$B" "$Z"
    elif [ "$criticals" -eq 0 ]; then
        printf '  %s⚠ WARN%s — %s попереджень, 0 критичних\n' "$Y$B" "$Z" "$warns"
    else
        printf '  %s✗ CRITICAL%s — %s критичних, %s попереджень\n' "$R$B" "$Z" "$criticals" "$warns"
        printf '\n  %sРекомендації:%s\n' "$B" "$Z"
        [ "$criticals" -gt 0 ] && printf '  → Перевір суми, адреси, REFUND\n'
    fi
    printf '%s═══════════════════%s\n' "$B" "$Z"
}

# ============================================================
# 2. INVOICE PARSER — regex-based
# ============================================================

local_ai_parse_invoice() {
    printf '%sВстав текст рахунку (Ctrl+D для завершення):%s\n' "$C" "$Z"
    local text
    text="$(cat)"

    [ -z "$text" ] && { echo "ERROR: empty"; return 1; }

    printf '\n%s═══ PARSING INVOICE ═══%s\n\n' "$B$C" "$Z"

    # --- Номер рахунку ---
    local inv_no
    inv_no="$(printf '%s' "$text" | grep -oE '[РR][БB][0-9]{4}-[0-9]{5}' | head -1)"
    [ -z "$inv_no" ] && inv_no="$(printf '%s' "$text" | grep -oE '№\s*[A-ZА-Я]{2,4}[0-9-]+' | head -1 | sed 's/№\s*//')"

    # --- Дата ---
    local inv_date
    inv_date="$(printf '%s' "$text" | grep -oE '[0-9]{2}\.[0-9]{2}\.[0-9]{4}' | head -1)"

    # --- ЄДРПОУ продавця (8 цифр) ---
    local seller_edrpou
    seller_edrpou="$(printf '%s' "$text" | grep -oE 'ЄДРПОУ[:\s]+[0-9]{8}' | head -1 | grep -oE '[0-9]{8}')"

    # --- ІПН покупця (10-12 цифр, після ІПН) ---
    local buyer_ipn
    buyer_ipn="$(printf '%s' "$text" | grep -oE 'ІПН[:\s]+[0-9]{10,12}' | head -1 | grep -oE '[0-9]{10,12}')"

    # --- Сума "разом" ---
    local total
    total="$(printf '%s' "$text" | grep -oE 'разом[:\s]+[0-9 ]+[.,][0-9]{2}' | head -1 | grep -oE '[0-9 ]+[.,][0-9]{2}' | tr -d ' ' | tr ',' '.')"

    # --- ПДВ ---
    local vat
    vat="$(printf '%s' "$text" | grep -oE 'ПДВ[:\s]+[0-9 ]+[.,][0-9]{2}' | head -1 | grep -oE '[0-9 ]+[.,][0-9]{2}' | tr -d ' ' | tr ',' '.')"

    # --- Сторони (ПІБ / назва) ---
    local buyer_name seller_name
    buyer_name="$(printf '%s' "$text" | grep -iE 'покупець' -A1 | tail -1 | head -c 60 | xargs)"
    seller_name="$(printf '%s' "$text" | grep -iE 'постачальник' -A1 | tail -1 | head -c 60 | xargs)"

    # --- Вивід JSON ---
    cat <<JSON
{
  "buyer_name": "$buyer_name",
  "buyer_ipn": "$buyer_ipn",
  "seller_name": "$seller_name",
  "seller_edrpou": "$seller_edrpou",
  "invoice_number": "$inv_no",
  "invoice_date": "$inv_date",
  "total": "$total",
  "vat": "$vat",
  "currency": "UAH",
  "source": "local_regex_parser"
}
JSON

    # --- Показати знайдене ---
    printf '\n%sЗнайдено:%s\n' "$B" "$Z"
    printf '  Invoice:  %s\n' "${inv_no:-NOT FOUND}"
    printf '  Date:     %s\n' "${inv_date:-NOT FOUND}"
    printf '  EDRPOU:   %s\n' "${seller_edrpou:-NOT FOUND}"
    printf '  IPN:      %s\n' "${buyer_ipn:-NOT FOUND}"
    printf '  Total:    %s\n' "${total:-NOT FOUND}"
    printf '  VAT:      %s\n' "${vat:-NOT FOUND}"

    printf '\n%sПідказка:%s щоб заповнити контракт — використай ці дані у [11]\n' "$Y" "$Z"
}

# ============================================================
# 3. TERMS GENERATOR — шаблони
# ============================================================

local_ai_generate_terms() {
    local cid="$1"
    local f="$MOD/contracts/$cid.env"
    [ ! -f "$f" ] && { echo "ERROR: not found"; return 1; }

    # --- Витягуємо дані ---
    local buyer seller amount la lb cf total
    buyer="$(grep -m1 '^BUYER=' "$f" | cut -d= -f2-)"
    seller="$(grep -m1 '^SELLER=' "$f" | cut -d= -f2-)"
    amount="$(grep -m1 '^AMOUNT_WEI=' "$f" | cut -d= -f2-)"
    la="$(grep -m1 '^LICENSE_A_WEI=' "$f" | cut -d= -f2-)"
    lb="$(grep -m1 '^LICENSE_B_WEI=' "$f" | cut -d= -f2-)"
    cf="$(grep -m1 '^CREATION_FEE_WEI=' "$f" | cut -d= -f2-)"
    total="$(grep -m1 '^LICENSE_TOTAL_WEI=' "$f" | cut -d= -f2-)"

    # --- Вирахуємо суми в основних одиницях (wei / 1e18) ---
    local amount_dec la_dec lb_dec cf_dec total_dec
    amount_dec="$(printf '%.6f' "$(echo "$amount / 1000000000000000000" | bc -l 2>/dev/null || echo 0)")"
    la_dec="$(printf '%.6f' "$(echo "$la / 1000000000000000000" | bc -l 2>/dev/null || echo 0)")"
    lb_dec="$(printf '%.6f' "$(echo "$lb / 1000000000000000000" | bc -l 2>/dev/null || echo 0)")"
    cf_dec="$(printf '%.6f' "$(echo "$cf / 1000000000000000000" | bc -l 2>/dev/null || echo 0)")"
    total_dec="$(printf '%.6f' "$(echo "$total / 1000000000000000000" | bc -l 2>/dev/null || echo 0)")"

    printf '%s═══ AI TERMS: %s ═══%s\n\n' "$B$C" "$cid" "$Z"

    cat <<TERMS
ДОГОВІР ПРО КУПІВЛЮ-ПРОДАЖ

Контракт: $cid
Дата:      $(date -u +%Y-%m-%d)

ПОКУПЕЦЬ:   $buyer
ПРОДАВЕЦЬ:  $seller

═══════════════════════════════════════════════════════════

1. ПРЕДМЕТ УГОДИ

1.1. Продавець продає, а Покупець купує товар, вказаний
     у позиціях до цього контракту.
1.2. Загальна сума угоди: $amount_dec токенів.

2. ПОРЯДОК РОЗРАХУНКІВ

2.1. Покупець перераховує $amount_dec токенів на CYBRA-контракт.
2.2. Розподіл суми:
     - Ліцензія A (1%): $la_dec
     - Ліцензія B (1%): $lb_dec
     - Ліцензія Creation (1%): $cf_dec
     - Загальна ліцензія (3%): $total_dec
     - Отримувач: 0x66434c5501242ccC71b5a39C765892921624B66c

3. ПРАВА І ОБОВ'ЯЗКИ СТОРІН

3.1. Продавець зобов'язується:
     - надати товар у повному обсязі;
     - не змінювати умови після FROZEN.

3.2. Покупець має право:
     - відмовитись від угоди протягом 72 годин;
     - отримати REFUND у разі невиконання умов.

4. ТЕРМІНИ ПОСТАВКИ

4.1. Продавець передає товар після підтвердження BUYER_CONFIRMED.
4.2. Покупець підтверджує отримання через RECEIPT_CONFIRMED.
4.3. Термін: за замовчуванням 72 години з моменту фінального рішення.

5. УМОВИ ПОВЕРНЕННЯ (REFUND)

5.1. REFUND активується:
     - При відмові покупця (REJECTED);
     - При timeout (не відповів протягом 72 годин);
     - При невиконанні умов продавцем.
5.2. Повертається сума NET ($(echo "$amount - $total" | bc -l) wei).
5.3. Ліцензії (3%) не повертаються — це плата за сервіс.

6. ФОРС-МАЖОР

6.1. Сторони звільняються від відповідальності при настанні
     обставин непереборної сили.

7. ВИРІШЕННЯ СПОРІВ

7.1. Спори вирішуються через CYBRA dispute resolver.
7.2. При неможливості — у судовому порядку за місцем позивача.

═══════════════════════════════════════════════════════════

Ліцензія CYBRA: 3% (A 1% + B 1% + Creation 1%)
Chain: BSC (56)

Згенеровано локальним CYBRA AI
TERMS
}

# ============================================================
# 4. ERROR HELPER — pattern matching
# ============================================================

local_ai_help_error() {
    local err="$1"

    printf '%s═══ AI ERROR HELPER ═══%s\n\n' "$B$C" "$Z"
    printf 'Помилка: %s\n\n' "$err"

    # --- Pattern matching ---
    local matched=0

    # unbound variable
    if [[ "$err" == *"unbound variable"* ]]; then
        printf '%s[✓] ДІАГНОЗ:%s Змінна не визначена\n' "$G$B" "$Z"
        printf '%s[→] ФІКС:%s Додай export або fallback:\n' "$G$B" "$Z"
        printf '    : "${VAR_NAME:=default_value}"\n'
        matched=1
    fi

    # command not found
    if [[ "$err" == *"command not found"* ]] || [[ "$err" == *": not found"* ]]; then
        local cmd="$(printf '%s' "$err" | grep -oE '[a-zA-Z_][a-zA-Z0-9_-]*' | head -1)"
        printf '%s[✓] ДІАГНОЗ:%s Команда "%s" не знайдена\n' "$G$B" "$Z" "$cmd"
        printf '%s[→] ФІКС:%s\n' "$G$B" "$Z"
        printf '    which %s            # перевірка\n' "$cmd"
        printf '    pkg install %s      # встановити\n' "$cmd"
        matched=1
    fi

    # Permission denied
    if [[ "$err" == *"Permission denied"* ]]; then
        printf '%s[✓] ДІАГНОЗ:%s Немає прав на файл\n' "$G$B" "$Z"
        printf '%s[→] ФІКС:%s\n' "$G$B" "$Z"
        printf '    chmod +x <file>\n'
        matched=1
    fi

    # syntax error
    if [[ "$err" == *"syntax error"* ]]; then
        printf '%s[✓] ДІАГНОЗ:%s Синтаксична помилка в скрипті\n' "$G$B" "$Z"
        printf '%s[→] ФІКС:%s\n' "$G$B" "$Z"
        printf '    bash -n <file>      # перевірка\n'
        printf '    cybra_self_heal     # автовідновлення\n'
        matched=1
    fi

    # REFUND missing
    if [[ "$err" == *"REFUND"* ]]; then
        printf '%s[✓] ДІАГНОЗ:%s Відсутні REFUND поля\n' "$G$B" "$Z"
        printf '%s[→] ФІКС:%s\n' "$G$B" "$Z"
        printf '    cybra_migrate_contracts.sh\n'
        matched=1
    fi

    # API_KEY
    if [[ "$err" == *"API_KEY"* ]] || [[ "$err" == *"AI_API_KEY"* ]]; then
        printf '%s[✓] ДІАГНОЗ:%s Зовнішній API не налаштовано\n' "$G$B" "$Z"
        printf '%s[→] ФІКС:%s Використовуй ЛОКАЛЬНИЙ AI (без API)\n' "$G$B" "$Z"
        printf '    Всі функції працюють офлайн: [1] [2] [3] [4]\n'
        matched=1
    fi

    # Empty / not found
    if [[ "$err" == *"not found"* ]] && [ "$matched" -eq 0 ]; then
        printf '%s[✓] ДІАГНОЗ:%s Щось не знайдено\n' "$G$B" "$Z"
        printf '%s[→] ФІКС:%s Перевір шлях/назву\n' "$G$B" "$Z"
        matched=1
    fi

    if [ "$matched" -eq 0 ]; then
        printf '%s[!] ДІАГНОЗ:%s Невідома помилка\n' "$Y$B" "$Z"
        printf '\nРекомендації:\n'
        printf '  1. Запусти cybra_preflight — перевірка системи\n'
        printf '  2. Запусти cybra_self_heal — автовідновлення\n'
        printf '  3. Перевір логи: ls -t ~/CYBRA/logs/ | head\n'
    fi

    printf '\n'
}

# ============================================================
# 5. FREE QUESTION — keyword matching
# ============================================================

local_ai_answer() {
    local q="$1"
    q="$(printf '%s' "$q" | tr '[:upper:]' '[:lower:]')"

    printf '%s═══ AI ANSWER ═══%s\n\n' "$B$C" "$Z"

    # --- Keyword matching ---
    if [[ "$q" == *"контракт"* ]] || [[ "$q" == *"contract"* ]]; then
        if [[ "$q" == *"створити"* ]] || [[ "$q" == *"create"* ]]; then
            printf 'Щоб створити контракт:\n'
            printf '  1. Запусти: cybra\n'
            printf '  2. Обери [1] Створити контракт (або [11] INVOICE)\n'
            printf '  3. Введи: BUYER, SELLER, AMOUNT, TOKEN\n'
            printf '  4. Перевір: cybra → [3] Статус\n'
            return
        fi
        if [[ "$q" == *"refund"* ]] || [[ "$q" == *"поверн"* ]]; then
            printf 'REFUND механізм:\n'
            printf '  • Активується через 72 години без рішення покупця\n'
            printf '  • Або через прямий REJECTED\n'
            printf '  • Повертається NET (без 3%% ліцензій)\n'
            printf '  • Керування: cybra → [18]-[21]\n'
            return
        fi
        if [[ "$q" == *"ліценз"* ]] || [[ "$q" == *"license"* ]]; then
            printf 'Ліцензія CYBRA = 3%%:\n'
            printf '  • LICENSE_A: 1%%\n'
            printf '  • LICENSE_B: 1%%\n'
            printf '  • CREATION_FEE: 1%%\n'
            printf '  • Отримувач: 0x66434c55...B66c\n'
            printf '  • НЕ повертається при refund\n'
            return
        fi
        printf 'Про контракти:\n'
        printf '  [1]  створити\n'
        printf '  [3]  статус\n'
        printf '  [4]  лінки для сторін\n'
        printf '  [18] фінальне рішення покупця\n'
        return
    fi

    if [[ "$q" == *"курс"* ]] || [[ "$q" == *"валют"* ]] || [[ "$q" == *"usd"* ]] || [[ "$q" == *"uah"* ]]; then
        printf 'Курси валют:\n'
        printf '  cybra → [22] показати\n'
        printf '  cybra → [23] оновити\n'
        printf '  cybra → [24] конвертер\n'
        printf '\nФайл: ~/CYBRA/modules/module_19_contract_tui_menu/state/rates.env\n'
        return
    fi

    if [[ "$q" == *"git"* ]] || [[ "$q" == *"push"* ]] || [[ "$q" == *"github"* ]]; then
        printf 'Git операції:\n'
        printf '  cd ~/CYBRA/git_module\n'
        printf '  git add -A\n'
        printf '  git commit -m "..."\n'
        printf '  git push\n'
        printf '\nАвтоматично: cybra_build / cybra_auto_all\n'
        return
    fi

    if [[ "$q" == *"hardening"* ]] || [[ "$q" == *"перевір"* ]]; then
        printf 'Hardening:\n'
        printf '  cybra_run.sh         — повний прогін\n'
        printf '  cybra_status.sh      — статус модулів\n'
        printf '  cybra → [30]         — preflight\n'
        printf '  cybra → [31]         — self-heal\n'
        return
    fi

    if [[ "$q" == *"модул"* ]] || [[ "$q" == *"module"* ]]; then
        printf 'Модулів у системі: 12\n'
        printf '  01 executor, 02 contract, 03 escrow\n'
        printf '  12 delivery, 13 dual-backend, 14 watchdog\n'
        printf '  15 true100, 16 final-auth, 17-18 license\n'
        printf '  19 contract-tui, 20 evolution-guard\n'
        return
    fi

    if [[ "$q" == *"допомож"* ]] || [[ "$q" == *"help"* ]]; then
        printf 'Доступні дії:\n'
        printf '  [1] аналіз контракту\n'
        printf '  [2] парсинг рахунку\n'
        printf '  [3] генерація умов\n'
        printf '  [4] допомога при помилці\n'
        printf '  [5] вільне питання\n'
        return
    fi

    if [[ "$q" == *"привіт"* ]] || [[ "$q" == *"hi"* ]] || [[ "$q" == *"hello"* ]]; then
        printf 'Привіт! Я локальний AI CYBRA.\n'
        printf 'Працюю офлайн, без API.\n'
        printf 'Можу: аналізувати контракти, парсити рахунки,\n'
        printf 'генерувати умови, допомагати з помилками.\n'
        return
    fi

    # Default
    printf 'Я не маю готової відповіді на це питання.\n\n'
    printf 'Спробуй:\n'
    printf '  • "контракт" — як створити\n'
    printf '  • "refund" — повернення коштів\n'
    printf '  • "ліцензія" — про відсотки\n'
    printf '  • "курс" — валюти\n'
    printf '  • "git" — робота з репо\n'
    printf '\nАбо: [1] аналіз, [2] парсинг, [3] умови, [4] помилки\n'
}
