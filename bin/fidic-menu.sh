#!/data/data/com.termux/files/usr/bin/bash
CYBRA="$HOME/CYBRA"
FIDIC_DIR="$CYBRA/data/fidic"

while true; do
    clear
    echo "════════ 160. FIDIC КОНТРАКТИ ════════"
    read -r -p "Введіть ID контракту (або натисніть Enter для створення нового): " CID
    
    if [ -z "$CID" ]; then
        read -r -p "Новий ID (наприклад, FIDIC-001): " NEW_CID
        python3 ~/CYBRA/bin/fidic-engine.py create "$NEW_CID"
        read -r -p "Натисніть Enter..." _
        continue
    fi

    FILE="$FIDIC_DIR/$CID.json"
    if [ ! -f "$FILE" ]; then
        echo "❌ Контракт $CID не знайдено."
        read -r -p "Натисніть Enter..." _
        continue
    fi

    # Читаємо стан контракту через Python (щоб не ламати Bash)
    STATE=$(python3 -c "import json; print(json.load(open('$FILE'))['state'])")

    echo "─── Контракт: $CID (Статус: $STATE) ───"
    
    # ДИНАМІЧНЕ МЕНЮ ЗАЛЕЖНО ВІД СТАНУ
    case "$STATE" in
        "DRAFT")
            echo "1) Заповнити BOQ (Кошторис)"
            echo "2) Перевірити дані"
            ;;
        "BOQ_READY")
            echo "1) Заповнити BOQ"
            echo "2) Перевірити дані (Валідація)"
            echo "3) Відправити на підпис (Multisig)"
            ;;
        "VALIDATED")
            echo "1) Відправити на підпис (Multisig)"
            ;;
        "SIGNED")
            echo "1) Активувати контракт (Початок робіт)"
            ;;
        *)
            echo "1) Перевірити дані"
            ;;
    esac
    echo "0) Назад"
    read -r -p "Вибір: " CMD

    case "$CMD" in
        2) python3 ~/CYBRA/bin/fidic-engine.py validate "$CID" ;;
        0) break ;;
        *) echo "⚠️ Ця функція ще в розробці (мікро-крок)." ;;
    esac
    read -r -p "Натисніть Enter..." _
done
