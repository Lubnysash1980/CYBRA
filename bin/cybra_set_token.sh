#!/data/data/com.termux/files/usr/bin/bash
# CYBRA Token Setup — інтерактивне налаштування GitHub токена

set -u

CYBRA_ROOT="$HOME/CYBRA"
TOKEN_FILE="$CYBRA_ROOT/.github_token"
GITMOD="$CYBRA_ROOT/git_module"
REPO="Lubnysash1980/cybra-node"

# Кольори
if [ -t 1 ]; then
    R=$'\033[31m'; G=$'\033[32m'; Y=$'\033[33m'
    B=$'\033[1m'; C=$'\033[36m'; Z=$'\033[0m'
else
    R=""; G=""; Y=""; B=""; C=""; Z=""
fi

clear 2>/dev/null || printf '\033[2J\033[H'

printf '%s%s════════════════════════════════════════════════════════════%s\n' "$B" "$C" "$Z"
printf '%s%s            CYBRA — GitHub Token Setup%s\n' "$B" "$C" "$Z"
printf '%s%s════════════════════════════════════════════════════════════%s\n\n' "$B" "$C" "$Z"

# Перевірка існуючого токена
if [ -f "$TOKEN_FILE" ]; then
    OLD="$(cat "$TOKEN_FILE" 2>/dev/null | head -c 12)"
    printf '%s!%s Уже збережено токен: %s...\n' "$Y" "$Z" "$OLD"
    printf 'Замінити? [y/N]: '
    read -r ans
    if [ "$ans" != "y" ] && [ "$ans" != "Y" ]; then
        printf 'Залишено старий токен.\n'
        exit 0
    fi
fi

printf '%sКРОК 1%s — Відкрий посилання у браузері:\n\n' "$B" "$Z"
printf '  %shttps://github.com/settings/tokens/new%s\n\n' "$C" "$Z"

printf '%sКРОК 2%s — Заповни форму:\n' "$B" "$Z"
printf '  Note:         %scybra-node-push%s\n' "$C" "$Z"
printf '  Expiration:   %s90 days%s (або No expiration)\n' "$C" "$Z"
printf '  Scopes:       %sпостав галочку [x] repo%s\n' "$C" "$Z"
printf '                (це все що треба)\n\n'

printf '%sКРОК 3%s — Натисни "Generate token"\n\n' "$B" "$Z"
printf '%sКРОК 4%s — Скопіюй токен (починається з ghp_)\n\n' "$B" "$Z"

printf '%s⚠ ВАЖЛИВО%s: токен показується ЛИШЕ ОДИН РАЗ\n' "$R$B" "$Z"
printf '  Скопіюй зараз або створиш заново\n\n'

printf -- '────────────────────────────────────────────────────────────\n\n'

printf '%sСпробувати відкрити браузер зараз? [y/N]: ' "$B" "$Z"
read -r open_ans

if [ "$open_ans" = "y" ] || [ "$open_ans" = "Y" ]; then
    URL="https://github.com/settings/tokens/new?description=cybra-node-push&scopes=repo"
    printf 'Відкриваю...\n'

    # Спроби відкрити браузер
    if command -v termux-open-url >/dev/null 2>&1; then
        termux-open-url "$URL" 2>/dev/null && printf '  [OK] відкрито через termux-open-url\n'
    elif command -v am >/dev/null 2>&1; then
        am start -a android.intent.action.VIEW -d "$URL" 2>/dev/null && printf '  [OK] відкрито через am\n'
    elif command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$URL" 2>/dev/null && printf '  [OK] відкрито через xdg-open\n'
    else
        printf '  %s[WARN]%s немає термінал-браузера\n' "$Y" "$Z"
        printf '  Відкрий вручну: %s\n' "$URL"
    fi
    printf '\n'
fi

printf 'Натисни Enter коли токен скопійований у буфер...'
read -r _

printf '\n%sВСТАВ ТОКЕН%s (правою кнопкою миші або Ctrl+Shift+V):\n' "$B$C" "$Z"
printf '  > '
read -r TOKEN

# Очищаємо від пробілів
TOKEN="$(printf '%s' "$TOKEN" | tr -d ' \t\r\n')"

# Валідація
if [ -z "$TOKEN" ]; then
    printf '%s✗ Порожній токен%s\n' "$R" "$Z"
    exit 1
fi

if ! printf '%s' "$TOKEN" | grep -qE '^ghp_[A-Za-z0-9]{36,}$'; then
    if printf '%s' "$TOKEN" | grep -qE '^github_pat_'; then
        printf '%s⚠ Fine-grained token%s — може не працювати з класичним API\n' "$Y" "$Z"
        printf 'Продовжити? [y/N]: '
        read -r cont
        [ "$cont" != "y" ] && [ "$cont" != "Y" ] && exit 1
    else
        printf '%s✗ Формат токена невірний%s\n' "$R" "$Z"
        printf '  Очікується: %sghp_xxx...%s\n' "$C" "$Z"
        printf '  Отримано:   %s\n' "$(printf '%s' "$TOKEN" | head -c 20)"
        exit 1
    fi
fi

printf '\n%sПеревірка токена через GitHub API...%s\n' "$C" "$Z"

HTTP_CODE="$(curl -sS -o /dev/null -w '%{http_code}' \
    -H "Authorization: token $TOKEN" \
    -H "Accept: application/vnd.github+json" \
    --max-time 15 \
    "https://api.github.com/user" 2>/dev/null)"

if [ "$HTTP_CODE" != "200" ]; then
    printf '%s✗ Токен невалідний (HTTP %s)%s\n' "$R" "$HTTP_CODE" "$Z"
    printf '  Перевір: scope=repo, токен не протермінований\n'
    exit 1
fi

printf '%s✓ Токен валідний%s\n' "$G" "$Z"

# Отримуємо username
USERNAME="$(curl -sS \
    -H "Authorization: token $TOKEN" \
    -H "Accept: application/vnd.github+json" \
    --max-time 10 \
    "https://api.github.com/user" 2>/dev/null \
    | grep -oE '"login"[[:space:]]*:[[:space:]]*"[^"]+"' \
    | head -1 \
    | sed 's/.*"\([^"]*\)"$/\1/')"

if [ -n "$USERNAME" ]; then
    printf '  GitHub user: %s\n' "$USERNAME"
fi

# Зберігаємо токен
printf '%s' "$TOKEN" > "$TOKEN_FILE"
chmod 600 "$TOKEN_FILE"
printf '%s✓ Токен збережено%s → %s (chmod 600)\n' "$G" "$Z" "$TOKEN_FILE"

# Оновлюємо git remote
if [ -d "$GITMOD/.git" ]; then
    cd "$GITMOD" || exit 1

    # Видаляємо старий
    git remote remove origin 2>/dev/null || true

    # Додаємо з токеном
    git remote add origin "https://${TOKEN}@github.com/${REPO}.git"

    printf '%s✓ Git remote оновлено%s\n' "$G" "$Z"

    printf '\n%sТест git push...%s\n' "$C" "$Z"

    if git push --dry-run 2>&1 | tail -3; then
        printf '%s✓ Git push доступний%s\n' "$G" "$Z"
    else
        printf '%s⚠ Перевір вручну: cd %s && git push%s\n' "$Y" "$GITMOD" "$Z"
    fi
else
    printf '%s⚠ git_module не ініціалізовано%s\n' "$Y" "$Z"
fi

printf '\n'
printf '%s%s════════════════════════════════════════════════════════════%s\n' "$B" "$C" "$Z"
printf '%s✓ ГОТОВО%s\n' "$G$B" "$Z"
printf '%s%s════════════════════════════════════════════════════════════%s\n' "$B" "$C" "$Z"
printf '\n'
printf 'Наступного разу просто:\n'
printf '  %scd %s && git push%s\n' "$C" "$GITMOD" "$Z"
printf '\n'
printf 'Токен збережено локально: %s\n' "$TOKEN_FILE"
printf 'НЕ публікуй цей файл у git!\n'
printf '\n'

# Додаємо до .gitignore якщо є
if [ -f "$GITMOD/.gitignore" ]; then
    if ! grep -q "^\.github_token$" "$GITMOD/.gitignore"; then
        printf '.github_token\n' >> "$GITMOD/.gitignore"
        printf '%s✓ .gitignore оновлено%s\n' "$G" "$Z"
    fi
fi

exit 0
