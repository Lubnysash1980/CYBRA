#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_360_mapping"
B=$'\e[36m'; G=$'\e[32m'; N=$'\e[0m'
while :; do
  clear
  echo "${B}═══ Mapping Controller ═══${N}"
  echo
  python3 -c "
import json
d = json.load(open('$D/data/mapping.json'))
B='\033[36m'; G='\033[32m'; D='\033[2m'; N='\033[0m'
print(f\"  Версія:  {d['version']}\")
print(f\"  Побудовано: {d['built']}\")
print(f\"  Пунктів: {d['total']}\")
builtin = sum(1 for it in d['items'].values() if it['builtin'])
print(f\"  Модулів: {d['total'] - builtin}\")
print(f\"  Built-in (вбудованих): {builtin}\")
"
  echo
  echo "  1) Повний список (по пріоритетах)"
  echo "  2) Показати пункт"
  echo "  3) По контролеру"
  echo "  4) Worker звіт"
  echo "  5) Parliament звіт"
  echo "  6) Heal план для пункту"
  echo "  7) Rebuild"
  echo "  0) Назад"
  read -rp "  Вибір: " c
  case "$c" in
    1) python3 "$D/mapping.py" list; read -rp "Enter…" _ ;;
    2) read -rp "  ID: " i; python3 "$D/mapping.py" show "$i"; read -rp "Enter…" _ ;;
    3) read -rp "  Контролер (backend/node_state/signatures/...): " ctrl
       python3 "$D/mapping.py" ctrl "$ctrl"; read -rp "Enter…" _ ;;
    4) python3 "$D/mapping.py" worker | head -40; read -rp "Enter…" _ ;;
    5) python3 "$D/mapping.py" parliament; read -rp "Enter…" _ ;;
    6) read -rp "  ID: " i; python3 "$D/mapping.py" heal "$i"; read -rp "Enter…" _ ;;
    7) python3 "$D/mapping.py" build; read -rp "Enter…" _ ;;
    0) return ;;
  esac
done
