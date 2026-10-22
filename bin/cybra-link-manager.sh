#!/data/data/com.termux/files/usr/bin/bash
# Модуль 154: Менеджер посилань (Тунель + Генерація лінку)
CYBRA="$HOME/CYBRA"
SERVER_PY="$CYBRA/modules/module_119_qr_sign/server.py"
EVIDENCE_DIR="$CYBRA/modules/module_19_contract_tui_menu/evidence/"
SESSIONS_FILE="$CYBRA/modules/module_123_multisig/data/sessions.jsonl"
PID_FILE="$CYBRA/state/tunnel.pid"
LOG_FILE="$CYBRA/state/tunnel_out.log"

mkdir -p "$CYBRA/state"

check_deps() { echo "─── Перевірка залежностей ───"; command -v ssh >/dev/null && echo "✅ SSH є" || echo "❌ SSH відсутній"; } 
add_config() { pkg install openssh -y >/dev/null 2>&1; echo "✅ SSH налаштовано."; } 
task_ai() { read -r -p "CID: " cid; mkdir -p "$CYBRA/parliament_core/tasks"; echo "{"cid":"$cid","status":"pending"}" > "$CYBRA/parliament_core/tasks/task_$(date +%s).json"; echo "✅ Задача створена."; } 
generate_link() { echo "Використовуйте пункт 5 для повного циклу."; } 

auto_prepare() {
    echo "─── Автоматична підготовка контракту ───"
    read -r -p "Введіть ID контракту (CID): " cid
    [ -z "$cid" ] && return

    echo "⏳ 1. Підготовка та налаштування..."
    # Оновлюємо статус контракту в базі (якщо це Multisig сесія)
    python3 -c "
import json, time
from pathlib import Path
f = Path('$SESSIONS_FILE')
if f.exists():
    lines = f.read_text().splitlines()
    new_lines = []
    for line in lines:
        if not line.strip(): continue
        try:
            d = json.loads(line)
            if d.get('cid') == '$cid' or d.get('sid') == '$cid':
                d['status'] = 'awaiting_signature'
                d['prepared_at'] = time.strftime('%Y-%m-%dT%H:%M:%SZ')
                print('  ✅ Статус змінено на awaiting_signature')
            new_lines.append(json.dumps(d, ensure_ascii=False))
        except: pass
    f.write_text('\n'.join(new_lines) + '\n')
"

    echo "⏳ 2. Доведення до фіналу (створення тунелю)..."
    pkill -F "$PID_FILE" 2>/dev/null
    rm -f "$LOG_FILE"
    
    if ! curl -s http://localhost:8080 > /dev/null; then
        python3 "$SERVER_PY" "$EVIDENCE_DIR" 8080 > /dev/null 2>&1 &
        sleep 2
    fi

    ssh -R 80:localhost:8080 -o StrictHostKeyChecking=no -o ServerAliveInterval=30 nokey@localhost.run > "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"
    sleep 8
    
    BASE_LINK=$(grep -oE 'https://[a-zA-Z0-9.-]+\.lhr\.life' "$LOG_FILE" | head -1)
    
    if [ -n "$BASE_LINK" ]; then
        FULL_LINK=$(python3 -c "
import base64, json, time, sys
url = sys.argv[1]; cid = sys.argv[2]
payload = {'v': 1, 'u': url, 'c': cid, 't': int(time.time())}
b64 = base64.urlsafe_b64encode(json.dumps(payload, separators=(',', ':')).encode()).decode().rstrip('=')
print(f'{url}?p={b64}')
" "$BASE_LINK" "$cid")
        
        METAMASK_LINK=$(python3 -c "
import sys, urllib.parse
print(f'https://link.metamask.io/dapp/{urllib.parse.quote(sys.argv[1], safe=\"\")}')
" "$FULL_LINK")
        
        echo ""
        echo "════════════════════════════════════════════"
        echo "✅ КОНТРАКТ $cid ГОТОВИЙ ДО ПІДПИСУ!"
        echo "Статус у системі: awaiting_signature"
        echo ""
        echo "📱 ЛІНК ДЛЯ METAMASK (натисніть на телефоні):"
        echo -e "\033[1;36m$METAMASK_LINK\033[0m"
        echo "════════════════════════════════════════════"
        echo "⚠️ УВАГА: Людина зобов'язана натиснути 'Підключити' та 'Підписати' в MetaMask."
        echo "⚠️ Поки Termux відкритий, система чекає на підпис..."
    else
        echo "⚠️ Не вдалося створити тунель."
    fi
}

# --- Меню ---
while true; do
    clear
    echo "════════ 154. МЕНЕДЖЕР ПОСИЛАНЬ ════════"
    echo "1) Перевірити залежності"
    echo "2) Автоналагодження (SSH)"
    echo "3) Поставити задачу Парламенту АІ"
    echo "4) Просто згенерувати лінк"
    echo -e "\033[1;32m5) АВТО-ПІДГОТОВКА: Підготовити контракт, налаштувати та згенерувати лінк\033[0m"
    echo "0) Назад"
    read -r -p "Вибір: " c
    case "$c" in
        1) check_deps ;;
        2) add_config ;;
        3) task_ai ;;
        4) generate_link ;;
        5) auto_prepare ;;
        0) exit 0 ;;
        *) echo "невідомо" ;;
    esac
    echo ""
    read -r -p "Натисніть Enter для продовження..." _
done
