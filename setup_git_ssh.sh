#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail
umask 077

REPO="Lubnysash1980/CYBRA"
BRANCH="main"
GIT_DIR="$HOME/CYBRA"
SSH_DIR="$HOME/.ssh"
KEY="$SSH_DIR/id_ed25519_github"
LOG="$GIT_DIR/out/git_setup"

mkdir -p "$SSH_DIR" "$GIT_DIR" "$LOG"
chmod 700 "$SSH_DIR"

trap 'unset TOKEN 2>/dev/null || true' EXIT

echo
echo "================================================"
echo " CYBRA — GIT + SSH + GITHUB TOKEN SETUP"
echo "================================================"
echo

# 1. Перевірка програм
echo "[1/8] Перевірка Termux..."

if ! command -v git >/dev/null 2>&1; then
    pkg install -y git
fi

if ! command -v ssh >/dev/null 2>&1; then
    pkg install -y openssh
fi

if ! command -v gh >/dev/null 2>&1; then
    echo "Встановлюю GitHub CLI..."
    pkg install -y gh
fi

# 2. Ім'я Git
echo
echo "[2/8] Налаштування Git"

CURRENT_NAME="$(git config --global user.name || true)"
CURRENT_EMAIL="$(git config --global user.email || true)"

read -r -p "GitHub username [$CURRENT_NAME]: " GIT_NAME
GIT_NAME="${GIT_NAME:-${CURRENT_NAME:-Lubnysash1980}}"

read -r -p "Git email [$CURRENT_EMAIL]: " GIT_EMAIL
GIT_EMAIL="${GIT_EMAIL:-$CURRENT_EMAIL}"

if [[ -z "$GIT_EMAIL" ]]; then
    read -r -p "Введи email GitHub: " GIT_EMAIL
fi

git config --global user.name "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"
git config --global init.defaultBranch "$BRANCH"
git config --global core.autocrlf input

# 3. SSH
echo
echo "[3/8] Налаштування SSH"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

if [[ ! -s "$KEY" || ! -s "$KEY.pub" ]]; then
    echo "Створюю окремий SSH-ключ для CYBRA."
    echo "Якщо запропонує passphrase, для автоматичного запуску"
    echo "можна залишити його порожнім."
    ssh-keygen -t ed25519 \
        -C "cybra-github-$GIT_NAME" \
        -f "$KEY"
fi

chmod 600 "$KEY"
chmod 644 "$KEY.pub"

cat > "$SSH_DIR/config" <<EOF
Host github.com
    HostName github.com
    User git
    IdentityFile $KEY
    IdentitiesOnly yes
    AddKeysToAgent no
    ServerAliveInterval 30
EOF

chmod 600 "$SSH_DIR/config"

echo
echo "ТВІЙ ПУБЛІЧНИЙ SSH-КЛЮЧ:"
echo "------------------------------------------------"
cat "$KEY.pub"
echo "------------------------------------------------"
echo
echo "Додай цей ключ у GitHub:"
echo "https://github.com/settings/ssh/new"
echo
read -r -p "Після додавання ключа натисни Enter..."

# 4. GitHub Token
echo
echo "[4/8] Авторизація GitHub Token"
echo "Створи токен:"
echo "https://github.com/settings/personal-access-tokens"
echo
echo "Для приватного репозиторію потрібен доступ до нього"
echo "і дозволи Contents: Read and write."
echo "Не вставляй сюди SSH-приватний ключ."
echo

read -r -s -p "Встав GitHub PAT (ввід прихований): " TOKEN
echo

if [[ -z "$TOKEN" ]]; then
    echo "ПОМИЛКА: токен порожній."
    exit 1
fi

if ! printf '%s' "$TOKEN" |
    gh auth login --hostname github.com --with-token; then
    unset TOKEN
    echo "ПОМИЛКА: GitHub не прийняв токен."
    exit 1
fi

unset TOKEN

# Налаштувати Git через GitHub CLI.
gh auth setup-git

echo
echo "[5/8] Перевірка GitHub CLI"

gh auth status --hostname github.com

# 6. Перевірка доступу до репозиторію
echo
echo "[6/8] Перевірка репозиторію"

REMOTE="git@github.com:$REPO.git"

if [[ -d "$GIT_DIR/.git" ]]; then
    cd "$GIT_DIR"

    git remote set-url origin "$REMOTE" 2>/dev/null ||
        git remote add origin "$REMOTE"

    echo "Знайдено наявний Git-репозиторій."
else
    echo "Локальний Git-репозиторій не знайдено."
    echo "Клоную GitHub-репозиторій у тимчасову папку..."

    TMP="$(mktemp -d "$HOME/cybra_clone.XXXXXX")"

    if git clone --origin origin --branch "$BRANCH" \
        "$REMOTE" "$TMP/repo"; then

        if [[ -n "$(find "$GIT_DIR" -mindepth 1 -maxdepth 1 \
            ! -name out -print -quit)" ]]; then
            echo "Увага: CYBRA містить локальні файли."
            echo "Не копіюю поверх них автоматично."
            echo "Клон збережено в: $TMP/repo"
            echo "Потрібно вручну об'єднати файли."
            exit 1
        fi

        cp -a "$TMP/repo/." "$GIT_DIR/"
        rm -rf "$TMP"
        cd "$GIT_DIR"
    else
        echo "ПОМИЛКА: клонування не вдалося."
        echo "Перевір існування репозиторію та SSH-доступ."
        exit 1
    fi
fi

# 7. Перевірка SSH і гілки
echo
echo "[7/8] Перевірка SSH"

if ssh -T -o BatchMode=yes \
    -o ConnectTimeout=15 git@github.com; then
    echo "SSH: доступ підтверджено."
else
    echo "SSH ще не підтверджено."
    echo "Перевір, чи додав ключ до правильного GitHub-акаунта."
    echo "Публічний ключ: $KEY.pub"
    exit 1
fi

git fetch origin
git branch --set-upstream-to="origin/$BRANCH" "$BRANCH" \
    2>/dev/null || true

# 8. Команда безпечного push
echo
echo "[8/8] Створення команди cybra_push"

mkdir -p "$HOME/bin"

cat > "$HOME/bin/cybra_push" <<'PUSH'
#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

cd "$HOME/CYBRA"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "FALSE: CYBRA не є Git-репозиторієм."
    exit 1
fi

echo "Перевіряю зміни..."
git status --short

echo
echo "Перевірка файлів, що можуть містити секрети..."

if git ls-files --others --cached --exclude-standard |
    grep -Ei '(^|/)(\.env([^/]*)?|.*\.pem|.*\.key|id_ed25519[^/]*|.*keystore.*|.*secret.*|.*mnemonic.*|.*private.?key.*)$'; then
    echo
    echo "УВАГА: знайдені потенційно чутливі файли."
    echo "Автоматичне додавання скасовано."
    echo "Перевір список вручну."
    exit 1
fi

if [[ -z "$(git status --porcelain)" ]]; then
    echo "Змін немає. Push не потрібен."
    exit 0
fi

echo
echo "Зміни будуть додані до коміту."
echo "Переконайся, що серед них немає секретів!"
read -r -p "Введи PUSH для підтвердження: " CONFIRM

if [[ "$CONFIRM" != "PUSH" ]]; then
    echo "Скасовано."
    exit 1
fi

git add -A

if git diff --cached --quiet; then
    echo "Немає змін для коміту."
    exit 0
fi

read -r -p "Повідомлення коміту: " MSG
MSG="${MSG:-CYBRA update}"

git commit -m "$MSG"
git push origin HEAD:main

echo
echo "PUSH завершено."
git status --short --branch
PUSH

chmod 700 "$HOME/bin/cybra_push"

# Додати ~/bin у PATH для Bash.
touch "$HOME/.bashrc"

if ! grep -Fq 'export PATH="$HOME/bin:$PATH"' "$HOME/.bashrc"; then
    printf '\nexport PATH="$HOME/bin:$PATH"\n' >> "$HOME/.bashrc"
fi

echo
echo "================================================"
echo " НАЛАШТУВАННЯ ЗАВЕРШЕНО"
echo "================================================"
echo
echo "Git:"
git config --global --get user.name
git config --global --get user.email
echo
echo "SSH key: $KEY.pub"
echo "Remote:"
git remote -v
echo
echo "Команда push:"
echo "  source ~/.bashrc"
echo "  cybra_push"
echo
echo "TRUE_100 налаштуванням Git не підтверджується."
echo "Перевірка push буде окремим фактичним результатом."
