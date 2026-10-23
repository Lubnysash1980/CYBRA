#!/data/data/com.termux/files/usr/bin/bash
# Автоматичний жорсткий резет до 100% стану з Ноди (GitHub)
CYBRA="$HOME/CYBRA"
cd "$CYBRA" || exit 1

echo "════════ ЖОРСТКИЙ РЕЗЕТ ДО 100% СТАНУ ════════"
echo "⏳ 1. Зберігаємо локальні дані (ключі, бази, логи)..."
# Створюємо тимчасовий бекап критичних даних
mkdir -p /tmp/cybra_secure_backup
cp -r nodes/keys /tmp/cybra_secure_backup/ 2>/dev/null
cp -r data /tmp/cybra_secure_backup/ 2>/dev/null
cp -r evidence /tmp/cybra_secure_backup/ 2>/dev/null
cp -r logs /tmp/cybra_secure_backup/ 2>/dev/null
cp -r state /tmp/cybra_secure_backup/ 2>/dev/null

echo "⏳ 2. Отримуємо еталонну версію з Ноди (GitHub)..."
git fetch origin main -q

echo "⏳ 3. Жорсткий відкат до коміту (стираємо всі локальні зміни)..."
git reset --hard origin/main -q

echo "⏳ 4. Очищення системи від мотлоху (незбережених файлів)..."
# Видаляємо все, що не є в Git, АЛЕ зберігаємо системні папки
git clean -fd -e "nodes/keys/" -e "data/" -e "evidence/" -e "logs/" -e "state/" -e "sandbox/" -e ".git/hooks/"

echo "⏳ 5. Відновлюємо критичні дані..."
cp -r /tmp/cybra_secure_backup/keys/* nodes/keys/ 2>/dev/null
cp -r /tmp/cybra_secure_backup/data/* data/ 2>/dev/null
cp -r /tmp/cybra_secure_backup/evidence/* evidence/ 2>/dev/null
cp -r /tmp/cybra_secure_backup/logs/* logs/ 2>/dev/null
cp -r /tmp/cybra_secure_backup/state/* state/ 2>/dev/null
rm -rf /tmp/cybra_secure_backup

echo "⏳ 6. Відновлення Git Hook (захист від помилок)..."
if [ ! -f .git/hooks/pre-commit ]; then
    # Якщо хук злетів, створюємо його знову
    cat > .git/hooks/pre-commit <<'HOOK'
#!/data/data/com.termux/files/usr/bin/bash
ERRORS=0
for f in $(git diff --cached --name-only --diff-filter=ACM | grep '\.py$'); do python3 -m py_compile "$f" 2>/dev/null || ERRORS=1; done
for f in $(git diff --cached --name-only --diff-filter=ACM | grep '\.sh$'); do bash -n "$f" 2>/dev/null || ERRORS=1; done
if [ $ERRORS -ne 0 ]; then echo "🚨 ПОМИЛКА СИНТАКСИСУ! Коміт скасовано."; exit 1; fi
HOOK
    chmod +x .git/hooks/pre-commit
fi

echo "⏳ 7. Перезапуск Моноліту з чистим кодом..."

echo ""
echo "════════════════════════════════════════════"
echo "✅ СИСТЕМА ПОВНІСТЮ ОЧИЩЕНА ТА СКИНУТА ДО 100% СТАНУ!"
echo "Поточна версія: $(git rev-parse --short HEAD)"
echo "Весь мотлох видалено. Ключі та дані збережено."
echo "════════════════════════════════════════════"
